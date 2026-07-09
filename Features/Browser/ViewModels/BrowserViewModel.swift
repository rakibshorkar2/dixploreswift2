import SwiftUI
import Combine

@MainActor
class BrowserViewModel: ObservableObject {
    @Published var currentUrl: String = ""
    @Published var items: [DirectoryItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var isFallbackMode: Bool = false
    @Published var isGridView: Bool = false
    @Published var searchQuery: String = ""
    @Published var selectedCategory: String = "All Categories"
    @Published var foldersFirst: Bool = true
    @Published var bookmarks: [[String: String]] = []
    @Published var history: [String] = []

    private let bookmarksKey = "com.dirxplore.browser.bookmarks"
    private let session = URLSession(configuration: .ephemeral)

    var canGoBack: Bool { history.count > 1 }

    var breadcrumbs: [String] {
        guard !currentUrl.isEmpty else { return [] }
        guard let components = URLComponents(string: currentUrl) else { return [] }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let host = components.host ?? ""
        var crumbs = [host]
        if !path.isEmpty {
            let segments = path.components(separatedBy: "/")
            crumbs.append(contentsOf: segments)
        }
        return crumbs
    }

    var isCurrentBookmarked: Bool {
        bookmarks.contains { $0["url"] == currentUrl }
    }

    var categories: [String] {
        ["All Categories", "Movies", "Series/TV", "Games", "Software", "Anime", "Images"]
    }

    var filteredItems: [DirectoryItem] {
        var result = items

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter { $0.name.lowercased().contains(q) }
        }

        if selectedCategory != "All Categories" {
            let catMap: [String: [String]] = [
                "Movies": ["mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm", "ts"],
                "Series/TV": ["mp4", "mkv", "avi", "srt", "vtt", "sub", "nfo"],
                "Games": ["iso", "gcm", "wbfs", "wad", "zip", "rar", "7z"],
                "Software": ["apk", "exe", "dmg", "deb", "rpm", "msi"],
                "Anime": ["mkv", "mp4", "srt", "ass", "ssa"],
                "Images": ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg"],
            ]
            if let exts = catMap[selectedCategory] {
                result = result.filter {
                    $0.isDirectory || exts.contains(($0.name as NSString).pathExtension.lowercased())
                }
            }
        }

        if foldersFirst {
            result.sort { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        } else {
            result.sort { a, b in
                if a.isDirectory != b.isDirectory { return !a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }

        return result
    }

    init() {
        loadBookmarks()
    }

    func createPlaylist(from selectedItem: DirectoryItem) -> (items: [DirectoryItem], initialIndex: Int) {
        let mediaFiles = filteredItems.filter { !$0.isDirectory && isPlayableMedia($0.name) }
        let initialIndex = max(mediaFiles.firstIndex(where: { $0.url == selectedItem.url }) ?? 0, 0)
        return (mediaFiles, initialIndex)
    }

    private func isPlayableMedia(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["mp4", "mkv", "avi", "mov", "webm"].contains(ext)
    }

    func loadUrl(_ url: String) {
        var urlStr = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlStr.isEmpty { return }
        if !urlStr.hasPrefix("http://") && !urlStr.hasPrefix("https://") {
            urlStr = "http://\(urlStr)"
        }
        if let last = history.last, last == urlStr {
        } else {
            history.append(urlStr)
        }
        currentUrl = urlStr
        isLoading = true
        errorMessage = ""

        Task {
            do {
                guard let requestUrl = URL(string: urlStr) else {
                    errorMessage = "Invalid URL"
                    isLoading = false
                    return
                }
                var request = URLRequest(url: requestUrl)
                request.setValue(
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    forHTTPHeaderField: "User-Agent"
                )
                request.timeoutInterval = 30
                let (data, response) = try await session.data(for: request)
                guard let httpResp = response as? HTTPURLResponse else {
                    errorMessage = "Invalid response"
                    isLoading = false
                    return
                }
                guard httpResp.statusCode == 200 else {
                    errorMessage = "HTTP \(httpResp.statusCode)"
                    isLoading = false
                    return
                }
                guard let html = String(data: data, encoding: .utf8) else {
                    errorMessage = "Failed to decode HTML"
                    isLoading = false
                    return
                }
                let parsed = await HTMLParserService.parseApacheDirectoryAsync(html: html, baseUrl: urlStr)
                if parsed.isEmpty {
                    isFallbackMode = true
                    items = []
                } else {
                    isFallbackMode = false
                    items = parsed
                }
                errorMessage = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func goBack() {
        guard history.count >= 2 else { return }
        history.removeLast()
        if let previous = history.last {
            loadUrl(previous)
        }
    }

    func goUp() {
        guard !currentUrl.isEmpty else { return }
        var urlStr = currentUrl
        if urlStr.hasSuffix("/") { urlStr = String(urlStr.dropLast()) }
        guard let url = URL(string: urlStr) else { return }
        let parent = url.deletingLastPathComponent().absoluteString
        loadUrl(parent)
    }

    func loadBreadcrumb(_ index: Int) {
        let crumbs = breadcrumbs
        guard index < crumbs.count else { return }
        let target = crumbs[index]
        guard let originalUrl = URL(string: currentUrl) else { return }

        var reconstructed: String
        if index == 0 {
            reconstructed = "\(originalUrl.scheme ?? "http")://\(target)"
        } else {
            let pathSegments = crumbs.dropFirst().prefix(index).map { $0 }
            let path = "/" + pathSegments.joined(separator: "/") + "/"
            reconstructed = "\(originalUrl.scheme ?? "http")://\(originalUrl.host ?? "")\(path)"
        }
        loadUrl(reconstructed)
    }

    func toggleBookmark() {
        if isCurrentBookmarked {
            bookmarks.removeAll { $0["url"] == currentUrl }
        } else {
            let name = breadcrumbs.last ?? currentUrl
            bookmarks.append(["name": name, "url": currentUrl])
        }
        saveBookmarks()
    }

    func removeBookmark(_ url: String) {
        bookmarks.removeAll { $0["url"] == url }
        saveBookmarks()
    }

    func toggleViewMode() {
        isGridView.toggle()
    }

    func toggleFallbackMode() {
        isFallbackMode.toggle()
        if !isFallbackMode && currentUrl.isEmpty {
            loadUrl("http://new.circleftp.net/")
        } else if !isFallbackMode && !currentUrl.isEmpty {
            loadUrl(currentUrl)
        }
    }

    func setCategory(_ cat: String) {
        selectedCategory = cat
    }

    func setSearchQuery(_ q: String) {
        searchQuery = q
    }

    func toggleSort() {
        foldersFirst.toggle()
    }

    func selectAll(_ select: Bool) {
        for i in items.indices {
            items[i].isSelected = select
        }
    }

    func toggleSelection(_ item: DirectoryItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isSelected.toggle()
    }

    func getSelectedItems() -> [DirectoryItem] {
        items.filter { $0.isSelected }
    }

    private func saveBookmarks() {
        if let data = try? JSONSerialization.data(withJSONObject: bookmarks, options: []) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return }
        bookmarks = list
    }
}