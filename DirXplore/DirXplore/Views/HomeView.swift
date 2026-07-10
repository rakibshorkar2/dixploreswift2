import SwiftUI

struct HomeView: View {
    @State private var urlText = ""
    @State private var resolvedLink: ResolvedLink?
    @State private var isResolving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var detectedSource: LinkSourceType?
    
    // Clipboard & Batch state
    @State private var clipboardLink: String?
    @State private var showBatchSheet = false

    @ScaledMetric private var iconSize: CGFloat = 48
    @ScaledMetric private var buttonSize: CGFloat = 44
    @ScaledMetric private var gridMinWidth: CGFloat = 80

    private let resolver = LinkResolver.shared
    @EnvironmentObject var manager: DownloadManager

    private var activeCount: Int { manager.tasks.filter { $0.status == .downloading || $0.status == .queued }.count }
    private var recentDownloads: [DownloadTask] { Array(manager.tasks.prefix(5)) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        if let clipLink = clipboardLink {
                            clipboardBanner(for: clipLink)
                        }
                        
                        pasteCard
                        urlInputRow
                        if let link = resolvedLink { previewCard(for: link) }
                        servicesSection
                        if !recentDownloads.isEmpty { recentSection }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("DirXplore Pro")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            showBatchSheet = true
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.body)
                        }

                        storageBadge
                        if activeCount > 0 {
                            HStack(spacing: 4) {
                                ProgressView().scaleEffect(0.7)
                                Text("\(activeCount)").font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(.systemGray6)))
                        }
                    }
                }
            }
            .sheet(isPresented: $showBatchSheet) {
                BatchDownloadSheet()
                    .environmentObject(manager)
            }
            .onAppear {
                checkClipboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                checkClipboard()
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
    }

    private var storageBadge: some View {
        let total = manager.tasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
        return HStack(spacing: 6) {
            Image(systemName: "externaldrive").font(.caption)
            Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color(.systemGray6)))
    }

    private var pasteCard: some View {
        Button {
            if let text = UIPasteboard.general.string {
                urlText = text
                resolveLink(text)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: iconSize, height: iconSize)
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paste a Link").font(.headline).foregroundStyle(.primary)
                    Text("Google Drive, Dropbox, MEGA, direct URLs...")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Paste a link from clipboard")
    }

    private var urlInputRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                if let source = detectedSource {
                    Image(systemName: sourceIcon(for: source))
                        .font(.caption).foregroundStyle(.blue)
                }
                TextField("Paste or type a URL...", text: $urlText)
                    .font(.subheadline)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: urlText) { _, new in detectSource(new) }
                    .onSubmit { if !urlText.isEmpty { resolveLink(urlText) } }
                if !urlText.isEmpty {
                    Button { urlText = ""; resolvedLink = nil; detectedSource = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary).font(.caption)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.separator), lineWidth: 0.5))

            Button {
                resolveLink(urlText)
            } label: {
                ZStack {
                    if isResolving {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: buttonSize, height: buttonSize)
                .background(Circle().fill(urlText.isEmpty ? Color(.systemGray4) : Color.blue))
            }
            .disabled(urlText.isEmpty || isResolving)
            .animation(.spring(response: 0.3), value: urlText.isEmpty)
        }
    }

    private func previewCard(for link: ResolvedLink) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: iconSize, height: iconSize)
                    Image(systemName: sourceIcon(for: link.sourceType))
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(link.fileName).font(.headline).lineLimit(2)
                    HStack(spacing: 4) {
                        Text(link.sourceType.rawValue).font(.caption).foregroundStyle(.blue)
                        if link.fileSize > 0 {
                            Text("•").foregroundStyle(.tertiary)
                            Text(ByteCountFormatter.string(fromByteCount: link.fileSize, countStyle: .file))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 8)
            }
            Button {
                manager.addTask(url: link.url, fileName: link.fileName, sourceType: link.sourceType)
                withAnimation { resolvedLink = nil; urlText = "" }
            } label: {
                Label("Start Download", systemImage: "arrow.down.circle")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supported Services")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: gridMinWidth))], spacing: 12) {
                ForEach(LinkSourceType.allCases, id: \.self) { svc in
                    VStack(spacing: 6) {
                        Image(systemName: svc.iconName)
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: iconSize * 0.85, height: iconSize * 0.85)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(svc.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer(minLength: 8)
                NavigationLink("See All", destination: DownloadsView())
                    .font(.caption.weight(.medium))
            }
            ForEach(recentDownloads) { task in
                NavigationLink(destination: DownloadDetailView(taskID: task.id)) {
                    DownloadRow(task: task)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func resolveLink(_ text: String) {
        guard !text.isEmpty else { return }
        isResolving = true
        Task {
            let result = await resolver.resolve(text)
            await MainActor.run {
                isResolving = false
                if let err = result.error {
                    errorMessage = err.localizedDescription
                    showError = true
                    resolvedLink = nil
                } else {
                    withAnimation(.spring(response: 0.4)) { resolvedLink = result }
                }
            }
        }
    }

    private func detectSource(_ text: String) {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else { detectedSource = nil; return }
        detectedSource = LinkSourceType.from(host: url.host ?? "", url: url)
    }

    private func sourceIcon(for type: LinkSourceType) -> String {
        switch type {
        case .direct: return "link"
        case .googleDrive: return "icloud"
        case .seedr: return "leaf"
        case .mediafire: return "flame"
        case .mega: return "square.stack.3d.up"
        case .dropbox: return "cube.box"
        case .onedrive: return "cloud"
        case .unknown: return "questionmark.circle"
        }
    }

    private func clipboardBanner(for link: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard.fill")
                .foregroundColor(.blue)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Link in Clipboard").font(.subheadline.bold())
                Text(link)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button("Paste") {
                urlText = link
                resolveLink(link)
                clipboardLink = nil
            }
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(Capsule())
            
            Button {
                clipboardLink = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
    }

    private func checkClipboard() {
        guard let clipboardString = UIPasteboard.general.string,
              let url = URL(string: clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.isValidDownloadURL else {
            clipboardLink = nil
            return
        }
        if clipboardString != urlText {
            withAnimation(.spring()) {
                clipboardLink = clipboardString
            }
        }
    }
}

extension LinkSourceType {
    static func from(host: String, url: URL) -> LinkSourceType {
        let s = url.absoluteString.lowercased()
        if host.contains("drive.google.com") || host.contains("googleusercontent.com") { return .googleDrive }
        if host.contains("seedr") { return .seedr }
        if host.contains("mediafire") { return .mediafire }
        if host.contains("mega") { return .mega }
        if host.contains("dropbox") { return .dropbox }
        if host.contains("onedrive") || host.contains("1drv") { return .onedrive }
        if host.contains("cloudflarestorage.com") || s.hasSuffix(".zip") || s.hasSuffix(".mp4") || s.hasSuffix(".pdf") { return .direct }
        return .unknown
    }
}

struct BatchDownloadSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var manager: DownloadManager
    @State private var batchText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste multiple download URLs below (one URL per line):")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                TextEditor(text: $batchText)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
                    .padding(.horizontal)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                
                Button(action: startBatchDownload) {
                    Text("Add to Downloads")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(batchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                }
                .disabled(batchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Batch Download")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Batch Added", isPresented: $showingAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func startBatchDownload() {
        let lines = batchText.components(separatedBy: .newlines)
        var urls: [URL] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty,
               let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: encoded),
               url.isValidDownloadURL {
                urls.append(url)
            }
        }

        if urls.isEmpty {
            alertMessage = "No valid download URLs found. Please check your links."
            showingAlert = true
        } else {
            manager.addBatch(urls: urls)
            alertMessage = "Successfully added \(urls.count) URLs to the queue!"
            showingAlert = true
        }
    }
}
