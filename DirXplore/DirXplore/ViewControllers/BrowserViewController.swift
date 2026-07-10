import UIKit
@preconcurrency import WebKit

@MainActor
final class BrowserViewController: UIViewController {

    private var webView: WKWebView!
    private var progressBar: UIProgressView!
    private var addressField: UITextField!
    private var addressBar: UIView!
    private var goButton: UIButton!
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
        setupAddressBar()
        setupProgressBar()
        setupWebView()
        setupToolbar()
        setupNavigationItem()
        observations()
    }

    deinit {
        observation?.invalidate()
    }

    private func setupAddressBar() {
        addressBar = UIView()
        addressBar.translatesAutoresizingMaskIntoConstraints = false
        addressBar.backgroundColor = .systemBackground
        view.addSubview(addressBar)

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
        addressBar.addSubview(addressField)

        goButton = UIButton(type: .system)
        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.setImage(UIImage(systemName: "arrow.up"), for: .normal)
        goButton.tintColor = .white
        goButton.backgroundColor = .systemBlue
        goButton.layer.cornerRadius = 17
        goButton.addTarget(self, action: #selector(goTapped), for: .touchUpInside)
        addressBar.addSubview(goButton)

        NSLayoutConstraint.activate([
            addressBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            addressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            addressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            addressBar.heightAnchor.constraint(equalToConstant: 52),

            addressField.leadingAnchor.constraint(equalTo: addressBar.leadingAnchor, constant: 12),
            addressField.centerYAnchor.constraint(equalTo: addressBar.centerYAnchor),
            addressField.trailingAnchor.constraint(equalTo: goButton.leadingAnchor, constant: -8),
            addressField.heightAnchor.constraint(equalToConstant: 36),

            goButton.trailingAnchor.constraint(equalTo: addressBar.trailingAnchor, constant: -12),
            goButton.centerYAnchor.constraint(equalTo: addressBar.centerYAnchor),
            goButton.widthAnchor.constraint(equalToConstant: 34),
            goButton.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    private func setupProgressBar() {
        progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.trackTintColor = .clear
        progressBar.progressTintColor = .systemBlue
        progressBar.isHidden = true
        view.addSubview(progressBar)
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
            webView.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            progressBar.topAnchor.constraint(equalTo: addressBar.bottomAnchor),
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
        guard let url = Self.formattedURL(from: text) else { return }
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
