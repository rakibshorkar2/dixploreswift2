import SwiftUI

struct HomeView: View {
    @State private var urlText = ""
    @State private var resolvedLink: ResolvedLink?
    @State private var isResolving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var detectedSource: LinkSourceType?

    private let resolver = LinkResolver.shared
    @EnvironmentObject var manager: DownloadManager

    private var activeCount: Int { manager.tasks.filter { $0.status == .downloading || $0.status == .queued }.count }
    private var recentDownloads: [DownloadTask] { Array(manager.tasks.prefix(5)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    quickActionsSection
                    if !urlText.isEmpty || resolvedLink != nil { urlSection }
                    servicesSection
                    if !recentDownloads.isEmpty { recentSection }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("DirXplore Pro").font(.largeTitle.weight(.bold))
                        Text(greeting).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if activeCount > 0 {
                        Button {
                            UIApplication.shared.open(URL(string: "dirxplore://downloads")!)
                        } label: {
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
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "icloud.and.arrow.down")
                .font(.title2)
                .foregroundStyle(.blue)
                .padding(10)
                .background(Circle().fill(Color.blue.opacity(0.1)))
            Spacer()
            storageBadge
        }
    }

    private var storageBadge: some View {
        let total = manager.tasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
        return HStack(spacing: 6) {
            Image(systemName: "externaldrive")
                .font(.caption)
            Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(.systemGray6)))
    }

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            pasteCard
            urlInputRow
            if let link = resolvedLink { previewCard(for: link) }
        }
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
                        .frame(width: 48, height: 48)
                    Image(systemName: "doc.on.clipboard")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paste a Link").font(.headline).foregroundStyle(.primary)
                    Text("Google Drive, Dropbox, MEGA, direct URLs...")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
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
    }

    private var urlInputRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                if let source = detectedSource {
                    Image(systemName: sourceIcon(for: source))
                        .font(.caption)
                        .foregroundStyle(.blue)
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
                .frame(width: 44, height: 44)
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
                        .frame(width: 48, height: 48)
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
                Spacer()
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
            Text("Supported Services").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                ForEach(LinkSourceType.allCases, id: \.self) { svc in
                    VStack(spacing: 6) {
                        Image(systemName: svc.iconName)
                            .font(.title3)
                            .foregroundStyle(.blue)
                            .frame(width: 40, height: 40)
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
                Text("Recent").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                NavigationLink("See All", destination: DownloadsView())
                    .font(.caption.weight(.medium))
            }
            ForEach(recentDownloads) { task in
                NavigationLink(destination: DownloadDetailView(task: task)) {
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
