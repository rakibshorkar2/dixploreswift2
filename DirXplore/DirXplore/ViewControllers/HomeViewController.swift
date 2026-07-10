import UIKit

@MainActor
final class HomeViewController: UIViewController {

    private let resolver = LinkResolver.shared
    private var resolvedLink: ResolvedLink?

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.keyboardDismissMode = .interactive
        s.showsVerticalScrollIndicator = false
        return s
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let headerLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "DirXplore Pro"
        l.font = .systemFont(ofSize: 34, weight: .bold)
        l.textColor = .label
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Download anything from anywhere"
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.textColor = .secondaryLabel
        return l
    }()

    private let pasteCard: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 16
        v.layer.cornerCurve = .continuous
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.08
        v.layer.shadowRadius = 12
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        return v
    }()

    private let pasteIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "doc.on.clipboard")
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let pasteTitle: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Paste a Link"
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .label
        return l
    }()

    private let pasteDesc: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Google Drive, Dropbox, MEGA, direct URLs..."
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        return l
    }()

    private let pasteButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Paste & Resolve", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        b.backgroundColor = .systemBlue
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.layer.cornerCurve = .continuous
        return b
    }()

    private let urlField: UITextField = {
        let t = UITextField()
        t.translatesAutoresizingMaskIntoConstraints = false
        t.placeholder = "Or type URL manually..."
        t.font = .systemFont(ofSize: 15)
        t.backgroundColor = .systemGray6
        t.layer.cornerRadius = 12
        t.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        t.leftViewMode = .always
        t.autocorrectionType = .no
        t.autocapitalizationType = .none
        t.keyboardType = .URL
        t.returnKeyType = .go
        t.clearButtonMode = .whileEditing
        return t
    }()

    private let resolveButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Resolve", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        b.backgroundColor = .systemGray5
        b.setTitleColor(.systemBlue, for: .normal)
        b.setTitleColor(.systemGray, for: .disabled)
        b.layer.cornerRadius = 12
        b.isEnabled = false
        return b
    }()

    private let previewCard: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemGray6
        v.layer.cornerRadius = 16
        v.isHidden = true
        return v
    }()

    private let previewIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "doc")
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let previewName: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .label
        l.numberOfLines = 2
        return l
    }()

    private let previewSize: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        return l
    }()

    private let previewSource: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .systemBlue
        return l
    }()

    private let downloadButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Start Download", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        b.backgroundColor = .systemBlue
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.layer.cornerCurve = .continuous
        return b
    }()

    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupLayout()
        setupActions()
        urlField.delegate = self
        observeKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    private final class ObserverToken: @unchecked Sendable {
        let token: NSObjectProtocol
        init(_ token: NSObjectProtocol) { self.token = token }
        deinit { NotificationCenter.default.removeObserver(token) }
    }

    private var keyboardTokens: [ObserverToken] = []

    private func observeKeyboard() {
        let show = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] n in
            let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            Task { @MainActor in
                guard let self, let frame else { return }
                self.scrollView.contentInset.bottom = frame.height - self.view.safeAreaInsets.bottom
                self.scrollView.verticalScrollIndicatorInsets.bottom = frame.height - self.view.safeAreaInsets.bottom
            }
        }
        let hide = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] n in
            Task { @MainActor in
                guard let self else { return }
                self.scrollView.contentInset.bottom = 0
                self.scrollView.verticalScrollIndicatorInsets.bottom = 0
            }
        }
        keyboardTokens = [ObserverToken(show), ObserverToken(hide)]
    }

    deinit {
        keyboardTokens = []
    }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        scrollView.contentInset.bottom = frame.height - view.safeAreaInsets.bottom
        scrollView.verticalScrollIndicatorInsets.bottom = frame.height - view.safeAreaInsets.bottom
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(headerLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(pasteCard)
        pasteCard.addSubview(pasteIcon)
        pasteCard.addSubview(pasteTitle)
        pasteCard.addSubview(pasteDesc)
        pasteCard.addSubview(pasteButton)
        contentView.addSubview(urlField)
        contentView.addSubview(resolveButton)
        contentView.addSubview(previewCard)
        previewCard.addSubview(previewIcon)
        previewCard.addSubview(previewName)
        previewCard.addSubview(previewSize)
        previewCard.addSubview(previewSource)
        previewCard.addSubview(downloadButton)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        pasteButton.addSubview(spinner)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            headerLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            pasteCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            pasteCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            pasteCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            pasteIcon.topAnchor.constraint(equalTo: pasteCard.topAnchor, constant: 20),
            pasteIcon.leadingAnchor.constraint(equalTo: pasteCard.leadingAnchor, constant: 20),
            pasteIcon.widthAnchor.constraint(equalToConstant: 40),
            pasteIcon.heightAnchor.constraint(equalToConstant: 40),

            pasteTitle.topAnchor.constraint(equalTo: pasteCard.topAnchor, constant: 20),
            pasteTitle.leadingAnchor.constraint(equalTo: pasteIcon.trailingAnchor, constant: 14),
            pasteTitle.trailingAnchor.constraint(equalTo: pasteCard.trailingAnchor, constant: -20),

            pasteDesc.topAnchor.constraint(equalTo: pasteTitle.bottomAnchor, constant: 4),
            pasteDesc.leadingAnchor.constraint(equalTo: pasteIcon.trailingAnchor, constant: 14),
            pasteDesc.trailingAnchor.constraint(equalTo: pasteCard.trailingAnchor, constant: -20),

            pasteButton.topAnchor.constraint(equalTo: pasteDesc.bottomAnchor, constant: 16),
            pasteButton.leadingAnchor.constraint(equalTo: pasteCard.leadingAnchor, constant: 20),
            pasteButton.trailingAnchor.constraint(equalTo: pasteCard.trailingAnchor, constant: -20),
            pasteButton.heightAnchor.constraint(equalToConstant: 48),
            pasteButton.bottomAnchor.constraint(equalTo: pasteCard.bottomAnchor, constant: -20),

            spinner.centerXAnchor.constraint(equalTo: pasteButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: pasteButton.centerYAnchor),

            urlField.topAnchor.constraint(equalTo: pasteCard.bottomAnchor, constant: 16),
            urlField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            urlField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            urlField.heightAnchor.constraint(equalToConstant: 48),

            resolveButton.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 12),
            resolveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resolveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resolveButton.heightAnchor.constraint(equalToConstant: 48),

            previewCard.topAnchor.constraint(equalTo: resolveButton.bottomAnchor, constant: 16),
            previewCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            previewCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            previewIcon.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 16),
            previewIcon.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            previewIcon.widthAnchor.constraint(equalToConstant: 48),
            previewIcon.heightAnchor.constraint(equalToConstant: 48),

            previewName.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 16),
            previewName.leadingAnchor.constraint(equalTo: previewIcon.trailingAnchor, constant: 14),
            previewName.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),

            previewSize.topAnchor.constraint(equalTo: previewName.bottomAnchor, constant: 4),
            previewSize.leadingAnchor.constraint(equalTo: previewIcon.trailingAnchor, constant: 14),

            previewSource.topAnchor.constraint(equalTo: previewSize.bottomAnchor, constant: 2),
            previewSource.leadingAnchor.constraint(equalTo: previewIcon.trailingAnchor, constant: 14),

            downloadButton.topAnchor.constraint(equalTo: previewIcon.bottomAnchor, constant: 16),
            downloadButton.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            downloadButton.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),
            downloadButton.heightAnchor.constraint(equalToConstant: 50),
            downloadButton.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -16),

            previewCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
        ])
    }

    private func setupActions() {
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        resolveButton.addTarget(self, action: #selector(resolveTapped), for: .touchUpInside)
        downloadButton.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)
        urlField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
    }

    @objc private func pasteTapped() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            let a = UIAlertController(title: "Nothing to Paste", message: "Copy a link first", preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }
        urlField.text = text
        resolveLink(text)
    }

    @objc private func resolveTapped() {
        guard let text = urlField.text, !text.isEmpty else { return }
        resolveLink(text)
    }

    @objc private func textChanged() {
        resolveButton.isEnabled = !(urlField.text?.isEmpty ?? true)
        resolveButton.backgroundColor = resolveButton.isEnabled ? .systemBlue.withAlphaComponent(0.12) : .systemGray5
        resolveButton.setTitleColor(resolveButton.isEnabled ? .systemBlue : .systemGray, for: .normal)
    }

    private func resolveLink(_ text: String) {
        pasteButton.isHidden = true
        spinner.startAnimating()
        resolveButton.isEnabled = false
        previewCard.isHidden = true

        Task {
            let resolved = await resolver.resolve(text)
            await MainActor.run {
                self.spinner.stopAnimating()
                self.pasteButton.isHidden = false
                self.resolveButton.isEnabled = true
                self.textChanged()

                if let err = resolved.error {
                    let a = UIAlertController(title: "Error", message: err.localizedDescription, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(a, animated: true)
                    return
                }
                self.resolvedLink = resolved
                self.previewName.text = resolved.fileName
                self.previewSize.text = resolved.fileSize > 0 ? ByteCountFormatter.string(fromByteCount: resolved.fileSize, countStyle: .file) : "Size unknown"
                self.previewSource.text = "Source: \(resolved.sourceType.rawValue)"
                self.previewCard.isHidden = false
            }
        }
    }

    @objc private func downloadTapped() {
        guard let r = resolvedLink else { return }
        DownloadManager.shared.addTask(url: r.url, fileName: r.fileName, sourceType: r.sourceType)
        let a = UIAlertController(title: "Download Started", message: "\"\(r.fileName)\" added to downloads", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "View", style: .default) { [weak self] _ in
            self?.tabBarController?.selectedIndex = 2
        })
        a.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(a, animated: true)
        previewCard.isHidden = true
        urlField.text = ""
        resolvedLink = nil
    }
}

extension HomeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.isEmpty else { return false }
        resolveLink(text)
        textField.resignFirstResponder()
        return true
    }
}
