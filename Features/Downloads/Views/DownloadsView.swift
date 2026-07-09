import SwiftUI
import UniformTypeIdentifiers

struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var showNewDownload = false
    @State private var showImportPicker = false
    @State private var showDeleteSelectedConfirm = false
    @State private var deleteSelectedFiles = false
    @State private var importJsonString: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                storageAnalyzerBar
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                if viewModel.queue.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "Download Queue is Empty",
                        systemImage: "tray",
                        description: Text("Tap + to add a download")
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.sortedBatchIds, id: \.self) { batchId in
                            let items = viewModel.groupedByBatch[batchId] ?? []
                            if batchId == nil {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    downloadCardRow(item: item, index: index + 1)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                        .listRowSeparator(.hidden)
                                }
                            } else if let unwrappedBatchId = batchId {
                                batchSection(batchId: unwrappedBatchId, items: items)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(viewModel.isSelectionMode ? "\(viewModel.selectedIds.count) Selected" : "Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.isSelectionMode {
                        Button { viewModel.selectAll() } label: {
                            Image(systemName: "checklist")
                        }
                        Button(role: .destructive) { showDeleteSelectedConfirm = true } label: {
                            Image(systemName: "trash")
                        }
                        Button { viewModel.toggleSelectionMode() } label: {
                            Text("Done").bold()
                        }
                    } else {
                        Button { showNewDownload = true } label: {
                            Image(systemName: "plus")
                        }
                        Button { viewModel.toggleSelectionMode() } label: {
                            Image(systemName: "checklist")
                        }
                        Button { viewModel.pauseAll() } label: {
                            Image(systemName: "pause.circle")
                        }
                        Button { viewModel.resumeAll() } label: {
                            Image(systemName: "play.circle")
                        }
                        Button { viewModel.clearDone() } label: {
                            Image(systemName: "clear")
                        }
                        Menu {
                            Button { exportQueue() } label: {
                                Label("Export Queue", systemImage: "square.and.arrow.up")
                            }
                            Button { showImportPicker = true } label: {
                                Label("Import Queue", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewDownload) {
                NewDownloadSheet(viewModel: viewModel)
            }
            .alert("Delete Selected?", isPresented: $showDeleteSelectedConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteSelected(deleteFiles: deleteSelectedFiles)
                }
            } message: {
                VStack {
                    Text("Delete \(viewModel.selectedIds.count) items?")
                    Toggle("Delete files from storage", isOn: $deleteSelectedFiles)
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if let data = try? Data(contentsOf: url),
                       let json = String(data: data, encoding: .utf8) {
                        Task {
                            let count = await viewModel.importQueueFromJson(json)
                            print("Imported \(count) items")
                        }
                    }
                case .failure(let error):
                    print("Import error: \(error)")
                }
            }
            .onAppear {
                viewModel.initManager()
            }
        }
    }

    // MARK: - Storage Analyzer

    private var storageAnalyzerBar: some View {
        let total = viewModel.totalStorage
        let free = viewModel.freeStorage
        if total <= 0 { return AnyView(EmptyView()) }
        let used = total - free
        let progress = total > 0 ? Double(used) / Double(total) : 0.0

        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Device Storage")
                        .font(.caption.bold())
                    Spacer()
                    Text("Free: \(formatGB(free)) / \(formatGB(total))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .tint(progress > 0.9 ? .red : .blue)
            }
        )
    }

    // MARK: - Batch Section

    private func batchSection(batchId: String, items: [DownloadItem]) -> some View {
        let batchName = items.first?.batchName ?? "Folder Download"
        let totalItems = items.count
        let doneItems = items.filter { $0.status == .done }.count
        let avgProgress = items.reduce(0.0) { $0 + $1.progress } / Double(totalItems)
        let isExpanded = viewModel.expandedBatchIds.contains(batchId)

        return Section {
            DisclosureGroup(isExpanded: Binding(
                get: { isExpanded },
                set: { expanded in
                    if expanded {
                        viewModel.expandedBatchIds.insert(batchId)
                    } else {
                        viewModel.expandedBatchIds.remove(batchId)
                    }
                }
            )) {
                ForEach(Array(items.enumerated()), id: \.element) { index, item in
                    downloadCardRow(item: item, index: index + 1)
                        .padding(.leading, 8)
                }
            } label: {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(batchName)
                            .font(.subheadline.bold())
                        Text("\(doneItems) / \(totalItems) files complete (\(Int(avgProgress * 100))%)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ProgressView(value: avgProgress)
                            .tint(.blue)
                    }
                    Spacer()
                    Menu {
                        Button { viewModel.resumeBatch(batchId) } label: {
                            Label("Resume All in Batch", systemImage: "play.circle")
                        }
                        Button { viewModel.pauseBatch(batchId) } label: {
                            Label("Pause All in Batch", systemImage: "pause.circle")
                        }
                        Divider()
                        Button(role: .destructive) { viewModel.stopBatch(batchId) } label: {
                            Label("Remove Batch", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Download Card Row

    private func downloadCardRow(item: DownloadItem, index: Int, isNested: Bool = false) -> some View {
        let isSelected = viewModel.selectedIds.contains(item.id)
        let isSelection = viewModel.isSelectionMode

        return HStack(spacing: 0) {
            if isSelection {
                Button {
                    viewModel.toggleSelection(item.id)
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .font(.title3)
                        .padding(.trailing, 8)
                }
            }

            DownloadCardView(
                item: item,
                index: index,
                isNested: isNested,
                onPause: { viewModel.pause(item.id) },
                onResume: { viewModel.resume(item.id) },
                onStop: { viewModel.stop(item.id) },
                onRefreshLink: { newUrl in
                    Task { _ = await viewModel.refreshLink(item.id, newUrl: newUrl) }
                },
                onRetry: { viewModel.resume(item.id) },
                onReveal: { viewModel.revealFile(item.savePath) },
                onSaveToFiles: { viewModel.saveToFiles(item.savePath) },
                onShare: { exportFile(item) },
                onVerifyHash: { algo, hash in
                    Task { _ = await viewModel.verifyFileHash(item.savePath, hash) }
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelection { viewModel.toggleSelection(item.id) }
            }
            .gesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                if !isSelection { viewModel.toggleSelection(item.id) }
            })
        }
        .padding(.vertical, 2)
    }

    // MARK: - Export

    private func exportQueue() {
        guard let json = try? JSONSerialization.data(
            withJSONObject: viewModel.queue.map { $0.toDictionary() },
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("dirxplore_queue_backup.json")
        try? json.write(to: temp)
        #if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: [temp], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
        #endif
    }

    private func exportFile(_ item: DownloadItem) {
        let url = URL(fileURLWithPath: item.savePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        #if canImport(UIKit)
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(activity, animated: true)
        }
        #endif
    }

    private func formatGB(_ bytes: Int64) -> String {
        let decimalGB = Double(bytes) * 1024.0 * 1024.0 / (1000.0 * 1000.0 * 1000.0)
        return String(format: "%.1f GB", decimalGB)
    }
}

extension DownloadsViewModel {
    var isEmpty: Bool { queue.isEmpty }
}

private func JSONSerializationString(with object: Any) throws -> Data {
    return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
}