import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .recent
    @State private var filterStatus: DownloadStatus?
    @State private var showSearch = false

    @ScaledMetric private var emptyIconSize: CGFloat = 48

    enum SortOrder: String, CaseIterable { case recent = "Recent", name = "Name", size = "Size", progress = "Progress" }

    private var filteredTasks: [DownloadTask] {
        var result = manager.tasks
        if !searchText.isEmpty { result = result.filter { $0.fileName.localizedCaseInsensitiveContains(searchText) } }
        if let status = filterStatus { result = result.filter { $0.status == status } }
        switch sortOrder {
        case .recent: result.sort { $0.startDate > $1.startDate }
        case .name: result.sort { $0.fileName < $1.fileName }
        case .size: result.sort { $0.fileSize > $1.fileSize }
        case .progress: result.sort { $0.progress > $1.progress }
        }
        return result
    }

    private var sections: [(String, [DownloadTask])] {
        let active = filteredTasks.filter { $0.status == .downloading || $0.status == .queued }
        let paused = filteredTasks.filter { $0.status == .paused }
        let completed = filteredTasks.filter { $0.status == .completed }
        let failed = filteredTasks.filter { $0.status == .failed }
        var result: [(String, [DownloadTask])] = []
        if !active.isEmpty { result.append(("Active", active)) }
        if !paused.isEmpty { result.append(("Paused", paused)) }
        if !completed.isEmpty { result.append(("Completed", completed)) }
        if !failed.isEmpty { result.append(("Failed", failed)) }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                Group {
                    if manager.tasks.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(sections, id: \.0) { title, tasks in
                                Section {
                                    ForEach(tasks) { task in
                                        NavigationLink(destination: DownloadDetailView(task: task)) {
                                            DownloadRow(task: task)
                                        }
                                        .buttonStyle(.plain)
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .padding(.vertical, 4)
                                    }
                                } header: {
                                    HStack {
                                        Text(title).font(.footnote.weight(.semibold)).textCase(.uppercase)
                                        Spacer(minLength: 8)
                                        Text("\(tasks.count)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        if !manager.tasks.isEmpty {
                            Button { showSearch.toggle() } label: {
                                Image(systemName: showSearch ? "xmark" : "magnifyingglass").font(.body)
                            }
                            Menu {
                                Picker("Sort", selection: $sortOrder) {
                                    ForEach(SortOrder.allCases, id: \.self) { order in
                                        Text(order.rawValue).tag(order)
                                    }
                                }
                                Divider()
                                Button { manager.pauseAll() } label: { Label("Pause All", systemImage: "pause.circle") }
                                Button { manager.resumeAll() } label: { Label("Resume All", systemImage: "play.circle") }
                                Button(role: .destructive) { manager.retryAllFailed() } label: { Label("Retry Failed", systemImage: "arrow.clockwise") }
                            } label: {
                                Image(systemName: "ellipsis.circle").font(.body)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, isPresented: $showSearch, prompt: "Search downloads...")
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: emptyIconSize))
                .foregroundStyle(.tertiary)
            Text("No Downloads Yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Paste a link on the Home tab to start downloading")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
