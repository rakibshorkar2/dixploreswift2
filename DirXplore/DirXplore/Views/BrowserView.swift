import SwiftUI
@preconcurrency import WebKit

struct BrowserView: View {
    @State private var urlString = ""
    @State private var showSheet = false
    @StateObject private var model = BrowserViewModel()

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
            .sheet(isPresented: $showSheet) {
                ActivityView(url: model.currentURL)
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
        guard let url = Self.formattedURL(from: input) else { return }
        urlString = url.absoluteString
        model.load(url)
        hideKeyboard()
    }

    static func formattedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("."), !trimmed.hasPrefix("http://"), !trimmed.hasPrefix("https://") {
            return URL(string: "https://" + trimmed)
        }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://www.google.com/search?q=\(encoded)")
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    func load(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func refresh() { webView?.reload() }
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

        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            completionHandler(.performDefaultHandling, nil)
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
