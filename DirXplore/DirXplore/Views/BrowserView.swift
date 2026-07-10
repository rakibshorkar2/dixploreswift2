import SwiftUI
@preconcurrency import WebKit

struct BrowserView: View {
    @State private var urlString = ""
    @State private var showSheet = false
    @StateObject private var model = BrowserViewModel()

    // Bookmarks and Search Engine states
    @AppStorage("browser_bookmarks") private var bookmarksJSON = "[]"
    @AppStorage("search_engine") private var searchEngine = "Google"
    @State private var showBookmarksSheet = false

    private var bookmarks: [Bookmark] {
        get {
            guard let data = bookmarksJSON.data(using: .utf8),
                  let list = try? JSONDecoder().decode([Bookmark].self, from: data) else { return [] }
            return list
        }
        nonmutating set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                bookmarksJSON = str
            }
        }
    }

    private var isCurrentPageBookmarked: Bool {
        guard let currentURL = model.currentURL else { return false }
        return bookmarks.contains { $0.urlString == currentURL.absoluteString }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                addressBar
                Divider()
                webView
                navBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Button {
                            showBookmarksSheet = true
                        } label: {
                            Image(systemName: "star.fill")
                                .font(.body)
                        }

                        Menu {
                            Picker("Search Engine", selection: $searchEngine) {
                                Text("Google").tag("Google")
                                Text("DuckDuckGo").tag("DuckDuckGo")
                                Text("Bing").tag("Bing")
                                Text("Yahoo").tag("Yahoo")
                            }
                        } label: {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.body)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleBookmark()
                    } label: {
                        Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.body)
                    }
                    .disabled(model.currentURL == nil)
                }
            }
            .sheet(isPresented: $showSheet) {
                ActivityView(url: model.currentURL)
            }
            .sheet(isPresented: $showBookmarksSheet) {
                BookmarksSheet(bookmarksJSON: $bookmarksJSON) { url in
                    urlString = url.absoluteString
                    model.load(url)
                }
            }
            .alert("Download Detected", isPresented: $model.showDownloadConfirmation) {
                TextField("File Name", text: $model.interceptedFileName)
                Button("Download") {
                    model.confirmDownload()
                }
                Button("Cancel", role: .cancel) {
                    model.cancelDownload()
                }
            } message: {
                Text("Would you like to download this file?\n\n\(model.downloadableURLToConfirm?.absoluteString ?? "")")
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if model.isLoading {
            ProgressView(value: model.progress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(.blue)
                .animation(.easeInOut(duration: 0.2), value: model.progress)
        }
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let url = model.currentURL, let scheme = url.scheme {
                    Image(systemName: scheme == "https" ? "lock.fill" : "lock.open")
                        .font(.caption2)
                        .foregroundStyle(scheme == "https" ? .green : .secondary)
                }
                TextField("Search or enter URL", text: $urlString)
                    .font(.subheadline)
                    .keyboardType(.webSearch)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onSubmit(go)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))

            if !model.isLoading {
                Button(action: go) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(!urlString.isEmpty ? Color.blue : Color(.systemGray4)))
                }
                .disabled(urlString.isEmpty)
            } else {
                Button(action: { model.webView?.stopLoading() }) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.red))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var webView: some View {
        WebView(model: model)
            .background(Color(.systemBackground))
    }

    private var navBar: some View {
        HStack(spacing: 0) {
            navButton(systemName: "chevron.left", action: model.goBack, disabled: !model.canGoBack)
            navButton(systemName: "chevron.right", action: model.goForward, disabled: !model.canGoForward)
            Spacer()
            navButton(systemName: "square.and.arrow.up", action: { showSheet = true }, disabled: model.currentURL == nil)
            Spacer()
            navButton(systemName: "arrow.clockwise", action: model.refresh, disabled: false)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }

    private func navButton(systemName: String, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body)
                .foregroundStyle(disabled ? Color(.systemGray4) : .blue)
                .frame(width: 44, height: 44)
        }
        .disabled(disabled)
    }

    private func go() {
        let input = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        guard let url = Self.formattedURL(from: input, engine: searchEngine) else { return }
        urlString = url.absoluteString
        model.load(url)
        hideKeyboard()
    }

    static func formattedURL(from input: String, engine: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("."), !trimmed.hasPrefix("http://"), !trimmed.hasPrefix("https://") {
            return URL(string: "https://" + trimmed)
        }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        
        let searchBase: String
        switch engine {
        case "DuckDuckGo": searchBase = "https://duckduckgo.com/?q="
        case "Bing": searchBase = "https://www.bing.com/search?q="
        case "Yahoo": searchBase = "https://search.yahoo.com/search?p="
        default: searchBase = "https://www.google.com/search?q="
        }
        
        return URL(string: searchBase + encoded)
    }

    private func toggleBookmark() {
        guard let currentURL = model.currentURL else { return }
        var list = bookmarks
        let urlStr = currentURL.absoluteString

        if let idx = list.firstIndex(where: { $0.urlString == urlStr }) {
            list.remove(at: idx)
        } else {
            let title = model.webView?.title ?? currentURL.host ?? "Website"
            let newBookmark = Bookmark(id: UUID(), title: title, urlString: urlStr)
            list.append(newBookmark)
        }
        bookmarks = list
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct Bookmark: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let urlString: String
}

struct BookmarksSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var bookmarksJSON: String
    var onSelect: (URL) -> Void

    private var bookmarks: [Bookmark] {
        get {
            guard let data = bookmarksJSON.data(using: .utf8),
                  let list = try? JSONDecoder().decode([Bookmark].self, from: data) else { return [] }
            return list
        }
        nonmutating set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                bookmarksJSON = str
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if bookmarks.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "star")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Bookmarks Yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Tap the bookmark icon when browsing a website to save it here.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(bookmarks) { bookmark in
                        Button {
                            if let url = URL(string: bookmark.urlString) {
                                onSelect(url)
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookmark.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text(bookmark.urlString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .onDelete(perform: deleteBookmark)
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func deleteBookmark(at offsets: IndexSet) {
        var list = bookmarks
        list.remove(atOffsets: offsets)
        bookmarks = list
    }
}

@MainActor
final class BrowserViewModel: ObservableObject {
    @Published var currentURL: URL?
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    fileprivate weak var webView: WKWebView?

    // Download confirmation state
    @Published var downloadableURLToConfirm: URL?
    @Published var showDownloadConfirmation = false
    @Published var interceptedFileName = ""

    func load(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func refresh() { webView?.reload() }

    func promptDownload(url: URL) {
        self.downloadableURLToConfirm = url
        self.interceptedFileName = url.lastPathComponent.isEmpty ? "downloaded_file" : url.lastPathComponent
        self.showDownloadConfirmation = true
    }

    func confirmDownload() {
        guard let url = downloadableURLToConfirm else { return }
        DownloadManager.shared.addTask(url: url, fileName: interceptedFileName)
        self.showDownloadConfirmation = false
        self.downloadableURLToConfirm = nil
    }

    func cancelDownload() {
        self.showDownloadConfirmation = false
        self.downloadableURLToConfirm = nil
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var model: BrowserViewModel

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = [.link, .phoneNumber]
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.backgroundColor = .systemBackground
        model.webView = wv
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: BrowserViewModel

        init(model: BrowserViewModel) {
            self.model = model
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.isLoading = true
            model.progress = 0
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.isLoading = false
            model.progress = 1
            model.currentURL = webView.url
            model.canGoBack = webView.canGoBack
            model.canGoForward = webView.canGoForward
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false
            model.progress = 0
            model.currentURL = webView.url
            model.canGoBack = webView.canGoBack
            model.canGoForward = webView.canGoForward
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            model.currentURL = webView.url
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false
            model.progress = 0
        }

        nonisolated func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            completionHandler(.performDefaultHandling, nil)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let ext = url.pathExtension.lowercased()
            let downloadExtensions = ["zip", "rar", "7z", "tar", "gz", "mp4", "mkv", "avi", "mp3", "m4a", "wav", "dmg", "pkg", "ipa", "apk", "epub", "pdf"]
            if downloadExtensions.contains(ext) {
                Task { @MainActor in
                    model.promptDownload(url: url)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if !navigationResponse.canShowMIMEType, let url = navigationResponse.response.url {
                Task { @MainActor in
                    model.promptDownload(url: url)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let url: URL?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url as Any], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
