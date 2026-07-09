import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    var onUrlChange: (String) -> Void
    var onMediaDetected: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/537.36 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/537.36"

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url?.absoluteString != url.absoluteString {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView

        private let mediaExtensions = ["mp4", "mkv", "avi", "mov", "webm", "mp3", "flac", "wav"]
        private let downloadExtensions = ["zip", "rar", "7z", "tar", "gz", "apk", "pdf", "iso", "img"]

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if let currentUrl = webView.url {
                parent.onUrlChange(currentUrl.absoluteString)
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            if let currentUrl = webView.url {
                parent.onUrlChange(currentUrl.absoluteString)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let currentUrl = webView.url {
                parent.onUrlChange(currentUrl.absoluteString)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let urlStr = navigationAction.request.url?.absoluteString else {
                decisionHandler(.allow)
                return
            }

            let ext = urlStr.components(separatedBy: "?").first?.components(separatedBy: ".").last?.lowercased() ?? ""
            let scheme = navigationAction.request.url?.scheme?.lowercased() ?? ""

            if scheme == "mailto" || scheme == "tel" || scheme == "facetime" {
                decisionHandler(.cancel)
                return
            }

            if mediaExtensions.contains(ext) || downloadExtensions.contains(ext) {
                let name = URL(string: urlStr)?.lastPathComponent ?? "file"
                decisionHandler(.cancel)
                parent.onMediaDetected(urlStr, name)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
        }
    }
}