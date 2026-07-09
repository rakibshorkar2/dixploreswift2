import SwiftUI
import WebKit
import UniformTypeIdentifiers
import UIKit

struct BrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()
    @State private var urlText: String = "http://172.16.50.4/"
    @State private var searchText: String = ""
    @State private var showBookmarks = false
    @State private var itemOptionsItem: DirectoryItem? = nil
    @State private var showItemOptions = false
    @State private var showShareSheet = false
    @State private var shareURL: String = ""

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(spacing: 0) {
            urlBar
            searchAndCategoryBar
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            if viewModel.isFallbackMode {
                webViewContent
            } else {
                nativeContent
            }
        }
        .navigationTitle("Directory Browser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    viewModel.toggleFallbackMode()
                } label: {
                    Image(systemName: viewModel.isFallbackMode ? "folder" : "globe")
                        .foregroundColor(viewModel.isFallbackMode ? .orange : .blue)
                }

                Button {
                    viewModel.toggleBookmark()
                } label: {
                    Image(systemName: viewModel.isCurrentBookmarked ? "star.fill" : "star")
                        .foregroundColor(viewModel.isCurrentBookmarked ? .yellow : nil)
                }

                Button {
                    showBookmarks = true
                } label: {
                    Image(systemName: "bookmarks")
                }

                if !viewModel.isFallbackMode {
                    Button {
                        viewModel.toggleViewMode()
                    } label: {
                        Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.3x3")
                    }

                    Button {
                        viewModel.toggleSort()
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
        .onAppear {
            if viewModel.currentUrl.isEmpty {
                viewModel.loadUrl(urlText)
            }
        }
        .sheet(isPresented: $showBookmarks) {
            bookmarksSheet
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: [shareURL])
        }
        .itemOptionsSheet(
            isPresented: $showItemOptions,
            item: safeOptionsItem,
            onPlayInApp: playInApp,
            onPlayWithVLC: playWithVLC,
            onQueueInApp: queueInApp,
            onSaveToFiles: saveToFiles,
            onCopyURL: copyURL,
            onShare: shareItem
        )
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.getSelectedItems().isEmpty {
                floatingSelectedFAB
            }
        }
    }

    private var safeOptionsItem: DirectoryItem {
        itemOptionsItem ?? DirectoryItem(name: "", url: "", type: .other)
    }

    // MARK: - URL Bar

    private var urlBar: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.goBack()
                urlText = viewModel.currentUrl
            } label: {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 14))
            }
            .disabled(!viewModel.canGoBack)

            Button {
                viewModel.goUp()
                urlText = viewModel.currentUrl
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14))
            }

            TextField("URL", text: $urlText)
                .font(.system(size: 13))
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .onSubmit {
                    viewModel.loadUrl(urlText)
                }

            Button {
                viewModel.loadUrl(urlText)
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
            }

            Button {
                viewModel.loadUrl(viewModel.currentUrl)
                urlText = viewModel.currentUrl
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Search & Category

    private var searchAndCategoryBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("Filter", text: $searchText)
                    .font(.system(size: 13))
                    .onChange(of: searchText) { _, newValue in
                        viewModel.setSearchQuery(newValue)
                    }
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(Color(.systemGray6))
            .cornerRadius(6)

            Picker(viewModel.selectedCategory, selection: $viewModel.selectedCategory) {
                ForEach(viewModel.categories, id: \.self) { cat in
                    Text(cat).tag(cat)
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 12))
            .frame(height: 32)
            .padding(.horizontal, 8)
            .background(Color(.systemGray6))
            .cornerRadius(6)
        }
    }

    // MARK: - Native Content

    private var nativeContent: some View {
        VStack(spacing: 0) {
            if !viewModel.breadcrumbs.isEmpty {
                breadcrumbBar
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else if !viewModel.errorMessage.isEmpty {
                Spacer()
                Text(viewModel.errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                if viewModel.isGridView {
                    gridView
                        .refreshable {
                            viewModel.loadUrl(viewModel.currentUrl)
                        }
                } else {
                    listView
                        .refreshable {
                            viewModel.loadUrl(viewModel.currentUrl)
                        }
                }
            }
        }
    }

    // MARK: - Breadcrumbs

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 2)
                    }
                    Button {
                        viewModel.loadBreadcrumb(index)
                        urlText = viewModel.currentUrl
                    } label: {
                        Text(crumb)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 32)
        .background(Color(.systemGray5).opacity(0.5))
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                let filtered = viewModel.filteredItems
                ForEach(filtered) { item in
                    gridItemCell(item: item)
                }
                if !filtered.isEmpty {
                    Color.clear
                        .frame(height: 80)
                }
            }
            .padding(8)
        }
    }

    private func gridItemCell(item: DirectoryItem) -> some View {
        Button {
            if item.isDirectory {
                urlText = item.url
                viewModel.loadUrl(item.url)
            } else {
                showOptionsFor(item)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 4) {
                        if item.isDirectory {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                        } else if let uiImage = thumbnailImage(for: item) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: iconName(for: item))
                                .font(.system(size: 40))
                                .foregroundColor(iconColor(for: item))
                        }
                    }

                    if item.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                            .offset(x: -2, y: 2)
                    }
                }

                if !item.isDirectory && isPlayableMedia(item.name) {
                    HStack(spacing: 8) {
                        Button {
                            itemOptionsItem = item
                            showItemOptions = true
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(item.name)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                if let size = item.size, !size.isEmpty {
                    Text(size)
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(item.isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
            .cornerRadius(8)
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 8))
            .contextMenu {
                contextMenuItems(for: item)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    viewModel.toggleSelection(item)
                }
        )
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(viewModel.filteredItems) { item in
                listItemRow(item: item)
            }
            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
    }

    private func listItemRow(item: DirectoryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isDirectory ? "folder.fill" : iconName(for: item))
                .font(.title3)
                .foregroundColor(item.isDirectory ? .yellow : iconColor(for: item))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13))
                    .lineLimit(2)
                if let size = item.size, !size.isEmpty {
                    Text(size)
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            if !item.isDirectory && isPlayableMedia(item.name) {
                Button {
                    playMediaInApp(item)
                } label: {
                    Image(systemName: "play.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Button {
                    itemOptionsItem = item
                    showItemOptions = true
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }

            Toggle(isOn: Binding(
                get: { item.isSelected },
                set: { _ in viewModel.toggleSelection(item) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .scaleEffect(0.8)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(item.isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            contextMenuItems(for: item)
        }
        .onTapGesture {
            if item.isDirectory {
                urlText = item.url
                viewModel.loadUrl(item.url)
            } else {
                itemOptionsItem = item
                showItemOptions = true
            }
        }
    }

    // MARK: - Context Menu Items

    @ViewBuilder
    private func contextMenuItems(for item: DirectoryItem) -> some View {
        if !item.isDirectory {
            if isPlayableMedia(item.name) {
                Button {
                    playButtonInApp(item)
                } label: {
                    Label("Play in App", systemImage: "play.circle")
                }

                Button {
                    playWithVLC(item)
                } label: {
                    Label("Play with VLC", systemImage: "play.rectangle")
                }
            }

            Button {
                queueInApp(item)
            } label: {
                Label("Queue in App", systemImage: "arrow.down.doc")
            }

            Button {
                saveToFiles(item)
            } label: {
                Label("Save to Files", systemImage: "folder.badge.plus")
            }

            Button {
                copyURL(item)
            } label: {
                Label("Copy URL", systemImage: "doc.on.doc")
            }

            Button {
                shareItem(item)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Divider()
        }

        Button {
            viewModel.toggleSelection(item)
        } label: {
            Label(item.isSelected ? "Deselect" : "Select", systemImage: item.isSelected ? "checkmark.circle.fill" : "circle")
        }
    }

    // MARK: - WebView Content

    private var webViewContent: some View {
        Group {
            if let url = URL(string: viewModel.currentUrl) {
                WebView(
                    url: url,
                    onUrlChange: { newUrl in
                        urlText = newUrl
                        viewModel.currentUrl = newUrl
                    },
                    onMediaDetected: { url, name in
                        let item = DirectoryItem(
                            name: name,
                            url: url,
                            type: DirectoryItem.type(fromExtension: name)
                        )
                        itemOptionsItem = item
                        showItemOptions = true
                    }
                )
            } else {
                WebView(
                    url: URL(string: "http://new.circleftp.net/")!,
                    onUrlChange: { newUrl in
                        urlText = newUrl
                        viewModel.currentUrl = newUrl
                    },
                    onMediaDetected: { url, name in
                        let item = DirectoryItem(
                            name: name,
                            url: url,
                            type: DirectoryItem.type(fromExtension: name)
                        )
                        itemOptionsItem = item
                        showItemOptions = true
                    }
                )
            }
        }
    }

    // MARK: - FAB

    private var floatingSelectedFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    queueSelectedItems()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Queue Selected (\(viewModel.getSelectedItems().count))")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 90)
            }
        }
    }

    // MARK: - Bookmarks Sheet

    private var bookmarksSheet: some View {
        NavigationView {
            Group {
                if viewModel.bookmarks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No bookmarks saved yet.")
                        Text("Tap the star icon to save a folder.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(Array(viewModel.bookmarks.enumerated()), id: \.offset) { index, b in
                            Button {
                                if let url = b["url"] {
                                    viewModel.loadUrl(url)
                                    urlText = url
                                    showBookmarks = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.yellow)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(b["name"] ?? "Unknown")
                                            .font(.body)
                                            .lineLimit(1)
                                            .foregroundColor(.primary)
                                        Text(b["url"] ?? "")
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        if let url = b["url"] {
                                            viewModel.removeBookmark(url)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { showBookmarks = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func showOptionsFor(_ item: DirectoryItem) {
        guard !item.isDirectory else { return }
        itemOptionsItem = item
        showItemOptions = true
    }

    private func playInApp() {
        playButtonInApp(safeOptionsItem)
    }

    private func playMediaInApp(_ item: DirectoryItem) {
        playButtonInApp(item)
    }

    private func playButtonInApp(_ item: DirectoryItem) {
        guard isPlayableMedia(item.name) else { return }
        let tunnelUrl = ProxyTunnelService.shared.tunnelUrl(for: item.url)
        let (mediaFiles, initialIndex) = viewModel.createPlaylist(from: item)
        let playlist: [(String, String)] = mediaFiles.map {
            (ProxyTunnelService.shared.tunnelUrl(for: $0.url), $0.name)
        }

        let playerView = PlayerView(
            url: tunnelUrl,
            title: item.name,
            playlist: playlist,
            initialIndex: initialIndex
        )
        presentInNavigationController(playerView)
    }

    private func playWithVLC(_ item: DirectoryItem) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        let vc = UIActivityViewController(
            activityItems: [item.url],
            applicationActivities: nil
        )
        if let popover = vc.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        root.present(vc, animated: true)
    }

    private func playWithVLC() {
        playWithVLC(safeOptionsItem)
    }

    private func queueInApp() {
        queueInApp(safeOptionsItem)
    }

    private func queueInApp(_ item: DirectoryItem) {
        if let match = viewModel.items.first(where: { $0.url == item.url }) {
            viewModel.toggleSelection(match)
        }
    }

    private func saveToFiles() {
        saveToFiles(safeOptionsItem)
    }

    private func saveToFiles(_ item: DirectoryItem) {
        guard let url = URL(string: ProxyTunnelService.shared.tunnelUrl(for: item.url)) else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let destination = tempDir.appendingPathComponent(item.name)

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: destination)
                await MainActor.run {
                    let picker = UIDocumentPickerViewController(forExporting: [destination])
                    if let scene = UIApplication.shared.firstKeyWindow?.rootViewController {
                        scene.present(picker, animated: true)
                    }
                }
            } catch {}
        }
    }

    private func copyURL() {
        copyURL(safeOptionsItem)
    }

    private func copyURL(_ item: DirectoryItem) {
        UIPasteboard.general.string = item.url
    }

    private func shareItem() {
        shareItem(safeOptionsItem)
    }

    private func shareItem(_ item: DirectoryItem) {
        shareURL = item.url
        showShareSheet = true
    }

    private func queueSelectedItems() {
        let selected = viewModel.getSelectedItems()
        for item in selected {
            if item.isDirectory {
                Task {
                    let downloadMgr = DownloadManager.shared
                    let items = await downloadMgr.crawlFolder(folderUrl: item.url)
                    let batchId = "\(Int64(Date().timeIntervalSince1970 * 1000))"
                    let videoExts = ["mp4", "mkv", "avi", "mov", "webm", "srt", "vtt", "sub"]
                    for subItem in items where videoExts.contains((subItem.name as NSString).pathExtension.lowercased()) {
                        await downloadMgr.addDownload(
                            url: subItem.url,
                            fileName: subItem.name,
                            saveDir: AppSettings.load().defaultSavePath,
                            batchId: batchId,
                            batchName: item.name
                        )
                    }
                }
            } else {
                Task {
                    await DownloadManager.shared.addDownload(
                        url: item.url,
                        fileName: item.name,
                        saveDir: SettingsManager.shared.defaultSavePath
                    )
                }
            }
        }
        viewModel.selectAll(false)
    }

    private func presentInNavigationController(_ view: some View) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let hosting = UIHostingController(rootView: view)
        let nav = UINavigationController(rootViewController: hosting)
        nav.modalPresentationStyle = .fullScreen
        root.present(nav, animated: true)
    }

    // MARK: - Helpers

    private func iconName(for item: DirectoryItem) -> String {
        let ext = (item.name as NSString).pathExtension.lowercased()
        if ["mp4", "mkv", "avi", "mov", "webm", "wmv", "flv", "m4v"].contains(ext) { return "video.fill" }
        if ["mp3", "flac", "wav", "aac", "ogg", "wma", "m4a"].contains(ext) { return "music.note" }
        if ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic"].contains(ext) { return "photo.fill" }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso"].contains(ext) { return "doc.zipper" }
        if ["pdf", "doc", "docx", "xls", "xlsx", "txt", "rtf", "csv"].contains(ext) { return "doc.text.fill" }
        if ["apk", "ipa", "exe", "dmg"].contains(ext) { return "app.fill" }
        if ["srt", "vtt", "sub", "ass", "ssa", "nfo"].contains(ext) { return "text.bubble.fill" }
        return "doc.fill"
    }

    private func iconColor(for item: DirectoryItem) -> Color {
        if item.isDirectory { return .yellow }
        let ext = (item.name as NSString).pathExtension.lowercased()
        if ["mp4", "mkv", "avi", "mov", "webm", "wmv", "flv", "m4v"].contains(ext) { return .purple }
        if ["mp3", "flac", "wav", "aac", "ogg", "wma", "m4a"].contains(ext) { return .orange }
        if ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic"].contains(ext) { return .green }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso"].contains(ext) { return .red }
        if ["pdf", "doc", "docx", "xls", "xlsx", "txt", "rtf", "csv"].contains(ext) { return .blue }
        if ["apk", "ipa"].contains(ext) { return .green }
        return .gray
    }

    private func isPlayableMedia(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["mp4", "mkv", "avi", "mov", "webm"].contains(ext)
    }

    private func thumbnailImage(for item: DirectoryItem) -> UIImage? {
        let ext = (item.name as NSString).pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic"]
        guard imageExts.contains(ext), let url = URL(string: item.url) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension DirectoryItem {
    init() {
        self.init(name: "", url: "", type: .other)
    }
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}