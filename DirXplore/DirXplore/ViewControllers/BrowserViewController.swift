import UIKit
import WebKit

@MainActor
final class BrowserViewController: UIViewController {

    private var webView: WKWebView!
    private var progressBar: UIProgressView!
    private var addressField: UITextField!
    private var backButton: UIBarButtonItem!
    private var forwardButton: UIBarButtonItem!
    private var shareButton: UIBarButtonItem!
    private var refreshButton: UIBarButtonItem!
    private var cancelButton: UIBarButtonItem!
    private var toolbar: UIToolbar!
    private var observation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Browser"
        setupWebView()
        setupToolbar()
        setupAddressBar()
        setupProgressBar()
        setupNavigationItem()
        observations()
    }

    deinit {
        observation?.invalidate()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = [.link, .phoneNumber]
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -44),
        ])
    }

    private func setupAddressBar() {
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.backgroundColor = .systemBackground
        view.addSubview(bar)

        addressField = UITextField()
        addressField.translatesAutoresizingMaskIntoConstraints = false
        addressField.placeholder = "Search or enter URL"
        addressField.font = .preferredFont(forTextStyle: .subheadline)
        addressField.adjustsFontForContentSizeCategory = true
        addressField.keyboardType = .webSearch
        addressField.autocapitalizationType = .none
        addressField.autocorrectionType = .no
        addressField.returnKeyType = .go
        addressField.backgroundColor = .secondarySystemBackground
        addressField.layer.cornerRadius = 10
        addressField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        addressField.leftViewMode = .always
        addressField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        addressField.rightViewMode = .always
        addressField.delegate = self
        bar.addSubview(addressField)

        let goButton = UIButton(type: .system)
        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setImage(UIImage(systemName: "arrow.up"), for: .normal)
        goButton.tintColor = .white
        goButton.backgroundColor = .systemBlue
        goButton.layer.cornerRadius = 17
        goButton.addTarget(self, action: #selector(goTapped), for: .touchUpInside)
        bar.addSubview(goButton)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 52),

            addressField.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            addressField.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            addressField.trailingAnchor.constraint(equalTo: goButton.leadingAnchor, constant: -8),
            addressField.heightAnchor.constraint(equalToConstant: 36),

            goButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            goButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            goButton.widthAnchor.constraint(equalToConstant: 34),
            goButton.heightAnchor.constraint(equalToConstant: 34),
        ])

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: bar.bottomAnchor),
        ])
    }

    private func setupProgressBar() {
        progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.trackTintColor = .clear
        progressBar.progressTintColor = .systemBlue
        progressBar.isHidden = true
        view.addSubview(progressBar)

        NSLayoutConstraint.activate([
            progressBar.topAnchor.constraint(equalTo: webView.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2),
        ])
    }

    private func setupToolbar() {
        toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(goBack))
        forwardButton = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(goForward))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(share))
        cancelButton = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(stopLoading))
        refreshButton = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refresh))
        toolbar.items = [backButton, flex, forwardButton, flex, shareButton, flex, refreshButton]

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        NSLayoutConstraint.activate([
            webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
        ])
    }

    private func setupNavigationItem() {
        navigationItem.rightBarButtonItems = [refreshButton, cancelButton]
        cancelButton.isHidden = true
    }

    private func observations() {
        observation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            guard let self, let progress = change.newValue else { return }
            self.progressBar.progress = Float(progress)
            self.progressBar.isHidden = progress >= 1.0
            self.cancelButton.isHidden = progress >= 1.0
            self.refreshButton.isHidden = progress < 1.0
        }
    }

    @objc private func goTapped() {
        guard let text = addressField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        let url = Self.formattedURL(from: text)
        addressField.text = url.absoluteString
        webView.load(URLRequest(url: url))
        addressField.resignFirstResponder()
        updateNavButtons()
    }

    @objc private func goBack() { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func refresh() { webView.reload() }
    @objc private func stopLoading() { webView.stopLoading() }

    @objc private func share() {
        guard let url = webView.url else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(av, animated: true)
    }

    private func updateNavButtons() {
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
    }

    static func formattedURL(from input: String) -> URL {
        if input.contains("."), !input.hasPrefix("http://"), !input.hasPrefix("https://") {
            return URL(string: "https://" + input) ?? URL(string: "https://www.google.com/search?q=\(input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input)")!
        }
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            return URL(string: input) ?? URL(string: "https://www.google.com/search?q=\(input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input)")!
        }
        return URL(string: "https://www.google.com/search?q=\(input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input)")!
    }
}

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        addressField.text = webView.url?.absoluteString ?? ""
        title = webView.title ?? "Browser"
        updateNavButtons()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateNavButtons()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateNavButtons()
    }
}

extension BrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        goTapped()
        return true
    }
}
