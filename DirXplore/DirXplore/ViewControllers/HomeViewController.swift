import UIKit
import Combine

final class HomeViewController: UIViewController {

    private let resolver = LinkResolver.shared
    private let downloadService = DownloadService.shared
    private var cancellables = Set<AnyCancellable>()
    private var resolvedLink: ResolvedLink?

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 24
        s.alignment = .fill
        return s
    }()

    private let logoContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "arrow.down.circle.fill")
        iv.tintColor = .tintColor
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "DirXplore"
        l.font = .systemFont(ofSize: 32, weight: .bold)
        l.textColor = .label
        l.textAlignment = .center
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Download anything from anywhere"
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        return l
    }()

    private let pasteCard: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 16
        v.layer.cornerCurve = .continuous
        return v
    }()

    private let pasteIconContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.tintColor.withAlphaComponent(0.12)
        v.layer.cornerRadius = 22
        return v
    }()

    private let pasteIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "doc.on.clipboard")
        iv.tintColor = .tintColor
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let pasteTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Paste Link to Download"
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        return l
    }()

    private let pasteSubtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Supports Google Drive, Dropbox, direct links & more"
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        return l
    }()

    private let pasteButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Paste & Resolve", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        b.backgroundColor = .tintColor
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.layer.cornerCurve = .continuous
        return b
    }()

    private let urlTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "Or type/paste URL manually..."
        tf.font = .systemFont(ofSize: 15)
        tf.textColor = .label
        tf.backgroundColor = .tertiarySystemBackground
        tf.layer.cornerRadius = 12
        tf.layer.cornerCurve = .continuous
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        tf.rightViewMode = .always
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.keyboardType = .URL
        tf.returnKeyType = .go
        tf.clearButtonMode = .whileEditing
        return tf
    }()

    private let resolveButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Resolve Link", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        b.backgroundColor = .secondarySystemBackground
        b.setTitleColor(.tintColor, for: .normal)
        b.layer.cornerRadius = 12
        b.layer.cornerCurve = .continuous
        b.isEnabled = false
        return b
    }()

    private let previewCard: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 16
        v.layer.cornerCurve = .continuous
        v.isHidden = true
        return v
    }()

    private let previewStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 8
        s.alignment = .fill
        return s
    }()

    private let previewFileNameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .label
        l.numberOfLines = 0
        return l
    }()

    private let previewFileSizeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        return l
    }()

    private let previewSourceLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .tintColor
        return l
    }()

    private let downloadButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Start Download", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        b.backgroundColor = .tintColor
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 14
        b.layer.cornerCurve = .continuous
        return b
    }()

    private let recentLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Supported Sources"
        l.font = .systemFont(ofSize: 20, weight: .bold)
        l.textColor = .label
        return l
    }()

    private let sourcesCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .clear
        cv.register(SourceCell.self, forCellWithReuseIdentifier: "SourceCell")
        return cv
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .medium)
        a.translatesAutoresizingMaskIntoConstraints = false
        a.hidesWhenStopped = true
        return a
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        setupActions()
        setupDelegates()
        checkClipboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        checkClipboard()
    }

    // MARK: - Setup

    private func setupView() {
        view.backgroundColor = .systemBackground

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(logoContainer)
        logoContainer.addSubview(logoImageView)
        logoContainer.addSubview(titleLabel)
        logoContainer.addSubview(subtitleLabel)

        contentStack.addArrangedSubview(pasteCard)
        pasteCard.addSubview(pasteIconContainer)
        pasteIconContainer.addSubview(pasteIcon)
        pasteCard.addSubview(pasteTitleLabel)
        pasteCard.addSubview(pasteSubtitleLabel)
        pasteCard.addSubview(pasteButton)
        pasteCard.addSubview(activityIndicator)

        contentStack.addArrangedSubview(urlTextField)
        contentStack.addArrangedSubview(resolveButton)

        contentStack.addArrangedSubview(previewCard)
        previewCard.addSubview(previewStack)
        previewStack.addArrangedSubview(previewFileNameLabel)
        previewStack.addArrangedSubview(previewFileSizeLabel)
        previewStack.addArrangedSubview(previewSourceLabel)
        previewStack.addArrangedSubview(downloadButton)

        contentStack.addArrangedSubview(recentLabel)
        contentStack.addArrangedSubview(sourcesCollection)
        sourcesCollection.dataSource = self
    }

    private func setupConstraints() {
        let sources = LinkSourceType.allCases
        let cvHeight: CGFloat = 100

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            logoContainer.heightAnchor.constraint(equalToConstant: 160),
            logoImageView.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: logoContainer.topAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 60),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),
            titleLabel.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: logoContainer.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            pasteCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            pasteIconContainer.topAnchor.constraint(equalTo: pasteCard.topAnchor, constant: 20),
            pasteIconContainer.leadingAnchor.constraint(equalTo: pasteCard.leadingAnchor, constant: 20),
            pasteIconContainer.widthAnchor.constraint(equalToConstant: 44),
            pasteIconContainer.heightAnchor.constraint(equalToConstant: 44),
            pasteIcon.centerXAnchor.constraint(equalTo: pasteIconContainer.centerXAnchor),
            pasteIcon.centerYAnchor.constraint(equalTo: pasteIconContainer.centerYAnchor),
            pasteIcon.widthAnchor.constraint(equalToConstant: 22),
            pasteIcon.heightAnchor.constraint(equalToConstant: 22),
            pasteTitleLabel.topAnchor.constraint(equalTo: pasteCard.topAnchor, constant: 20),
            pasteTitleLabel.leadingAnchor.constraint(equalTo: pasteIconContainer.trailingAnchor, constant: 14),
            pasteTitleLabel.trailingAnchor.constraint(equalTo: pasteCard.trailingAnchor, constant: -20),
            pasteSubtitleLabel.topAnchor.constraint(equalTo: pasteTitleLabel.bottomAnchor, constant: 4),
            pasteSubtitleLabel.leadingAnchor.constraint(equalTo: pasteIconContainer.trailingAnchor, constant: 14),
            pasteSubtitleLabel.trailingAnchor.constraint(equalTo: pasteCard.trailingAnchor, constant: -20),
            pasteButton.topAnchor.constraint(equalTo: pasteSubtitleLabel.bottomAnchor, constant: 16),
            pasteButton.leadingAnchor.constraint(equalTo: pasteCard.leadingAnchor, constant: 20),
            pasteButton.trailingAnchor.constraint(equalTo: pasteCard.trailingAnchor, constant: -20),
            pasteButton.heightAnchor.constraint(equalToConstant: 48),
            pasteButton.bottomAnchor.constraint(equalTo: pasteCard.bottomAnchor, constant: -20),
            activityIndicator.centerXAnchor.constraint(equalTo: pasteButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: pasteButton.centerYAnchor),

            urlTextField.heightAnchor.constraint(equalToConstant: 48),
            resolveButton.heightAnchor.constraint(equalToConstant: 48),

            previewCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            previewStack.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 16),
            previewStack.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            previewStack.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),
            previewStack.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -16),

            downloadButton.heightAnchor.constraint(equalToConstant: 50),

            sourcesCollection.heightAnchor.constraint(equalToConstant: cvHeight),
        ])
    }

    private func setupActions() {
        pasteButton.addTarget(self, action: #selector(pasteAndResolveTapped), for: .touchUpInside)
        resolveButton.addTarget(self, action: #selector(resolveTapped), for: .touchUpInside)
        downloadButton.addTarget(self, action: #selector(startDownloadTapped), for: .touchUpInside)
        urlTextField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
    }

    private func setupDelegates() {
        urlTextField.delegate = self
    }

    private func checkClipboard() {
        guard let string = UIPasteboard.general.string, !string.isEmpty else { return }
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            UIView.animate(withDuration: 0.2) {
                self.pasteCard.backgroundColor = UIColor.tintColor.withAlphaComponent(0.08)
            }
        }
    }

    // MARK: - Actions

    @objc private func pasteAndResolveTapped() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            let alert = UIAlertController(title: "Nothing to Paste",
                                          message: "Your clipboard is empty. Copy a link first.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        urlTextField.text = pasted
        resolveLink(pasted)
    }

    @objc private func resolveTapped() {
        guard let text = urlTextField.text, !text.isEmpty else { return }
        resolveLink(text)
    }

    @objc private func textFieldChanged() {
        resolveButton.isEnabled = !(urlTextField.text?.isEmpty ?? true)
    }

    private func resolveLink(_ urlString: String) {
        setLoading(true)

        Task {
            let resolved = await resolver.resolve(urlString)

            await MainActor.run {
                self.setLoading(false)

                if let error = resolved.error {
                    self.showError(error)
                    return
                }

                self.resolvedLink = resolved
                self.showPreview(resolved)
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        pasteButton.isHidden = loading
        resolveButton.isEnabled = !loading && !(urlTextField.text?.isEmpty ?? true)
        if loading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    private func showPreview(_ resolved: ResolvedLink) {
        previewFileNameLabel.text = resolved.fileName
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        previewFileSizeLabel.text = resolved.fileSize > 0 ? formatter.string(fromByteCount: resolved.fileSize) : "Size unknown"
        previewSourceLabel.text = "Source: \(resolved.sourceType.rawValue)"
        previewCard.isHidden = false

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func startDownloadTapped() {
        guard let resolved = resolvedLink else { return }

        Task {
            await DownloadManager.shared.addTask(
                url: resolved.url,
                fileName: resolved.fileName,
                sourceType: resolved.sourceType
            )

            await MainActor.run {
                let alert = UIAlertController(
                    title: "Download Started",
                    message: "\"\(resolved.fileName)\" has been added to your downloads.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "View Downloads", style: .default) { _ in
                    self.tabBarController?.selectedIndex = 1
                })
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                self.present(alert, animated: true)

                self.previewCard.isHidden = true
                self.urlTextField.text = ""
                self.resolvedLink = nil
            }
        }
    }

    private func showError(_ error: ResolvedLink.LinkError) {
        let alert = UIAlertController(title: "Invalid Link",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension HomeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.isEmpty else { return false }
        resolveLink(text)
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UICollectionViewDataSource

extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        LinkSourceType.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SourceCell", for: indexPath) as! SourceCell
        cell.configure(with: LinkSourceType.allCases[indexPath.item])
        return cell
    }
}

// MARK: - SourceCell

final class SourceCell: UICollectionViewCell {
    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .tintColor
        return iv
    }()

    private let label: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous

        contentView.addSubview(iconView)
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
        ])
    }

    func configure(with source: LinkSourceType) {
        switch source {
        case .direct:
            iconView.image = UIImage(systemName: "link")
        case .googleDrive:
            iconView.image = UIImage(systemName: "icloud")
        case .seedr:
            iconView.image = UIImage(systemName: "leaf")
        case .mediafire:
            iconView.image = UIImage(systemName: "flame")
        case .mega:
            iconView.image = UIImage(systemName: "square.stack.3d.up")
        case .dropbox:
            iconView.image = UIImage(systemName: "cube.box")
        case .onedrive:
            iconView.image = UIImage(systemName: "cloud")
        case .unknown:
            iconView.image = UIImage(systemName: "questionmark.circle")
        }
        label.text = source.rawValue
    }
}
