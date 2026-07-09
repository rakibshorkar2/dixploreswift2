import UIKit

final class DownloadCell: UITableViewCell {

    private let containerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemGroupedBackground
        v.layer.cornerRadius = 14
        v.layer.cornerCurve = .continuous
        return v
    }()

    private let fileIconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .tintColor
        return iv
    }()

    private let fileNameLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .label
        l.numberOfLines = 1
        l.lineBreakMode = .byTruncatingMiddle
        return l
    }()

    private let statusLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = .secondaryLabel
        return l
    }()

    private let speedLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 11, weight: .regular)
        l.textColor = .tertiaryLabel
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
    }()

    private let progressContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .tertiarySystemBackground
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        v.isHidden = true
        return v
    }()

    private let progressFill: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .tintColor
        v.layer.cornerRadius = 4
        return v
    }()

    private var currentProgress: Double = 0
    private var progressFillTrailing: NSLayoutConstraint!

    private let statusImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .secondaryLabel
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(fileIconView)
        containerView.addSubview(fileNameLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(speedLabel)
        containerView.addSubview(progressContainer)
        progressContainer.addSubview(progressFill)
        containerView.addSubview(statusImageView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 0),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            fileIconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            fileIconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            fileIconView.widthAnchor.constraint(equalToConstant: 36),
            fileIconView.heightAnchor.constraint(equalToConstant: 36),

            fileNameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            fileNameLabel.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: 12),
            fileNameLabel.trailingAnchor.constraint(equalTo: statusImageView.leadingAnchor, constant: -8),

            statusLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 2),
            statusLabel.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: 12),

            speedLabel.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            speedLabel.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8),
            speedLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusImageView.leadingAnchor, constant: -8),

            progressContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            progressContainer.leadingAnchor.constraint(equalTo: fileIconView.trailingAnchor, constant: 12),
            progressContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            progressContainer.heightAnchor.constraint(equalToConstant: 8),
            progressContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            progressFill.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),

            statusImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            statusImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            statusImageView.widthAnchor.constraint(equalToConstant: 24),
            statusImageView.heightAnchor.constraint(equalToConstant: 24),
        ])

        let trailing = progressFill.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor, constant: 0)
        trailing.isActive = true
        progressFillTrailing = trailing
    }

    func configure(with task: DownloadTask) {
        fileNameLabel.text = task.fileName
        fileIconView.image = iconForFile(task.fileName)

        switch task.status {
        case .queued:
            statusLabel.text = "Waiting..."
            speedLabel.text = nil
            statusImageView.image = UIImage(systemName: "clock")
            statusImageView.tintColor = .systemOrange
            progressContainer.isHidden = true
        case .downloading:
            let pct = task.progressPercentage
            let downloaded = task.formattedDownloadedSize
            let total = task.formattedFileSize
            statusLabel.text = "\(pct) - \(downloaded) / \(total)"
            speedLabel.text = task.downloadSpeed > 0 ? task.formattedSpeed : nil
            statusImageView.image = UIImage(systemName: "arrow.down.circle")
            statusImageView.tintColor = .tintColor
            progressContainer.isHidden = false
            currentProgress = task.progress
            let cw = progressContainer.bounds.width
            progressFillTrailing.constant = cw > 0 ? -cw * (1 - CGFloat(task.progress)) : 0
            progressFill.backgroundColor = .tintColor
        case .paused:
            statusLabel.text = "Paused - \(task.progressPercentage)"
            speedLabel.text = nil
            statusImageView.image = UIImage(systemName: "pause.circle")
            statusImageView.tintColor = .systemOrange
            progressContainer.isHidden = false
            currentProgress = task.progress
            let cw = progressContainer.bounds.width
            progressFillTrailing.constant = cw > 0 ? -cw * (1 - CGFloat(task.progress)) : 0
            progressFill.backgroundColor = .systemOrange
        case .completed:
            statusLabel.text = "Completed - \(task.formattedFileSize)"
            speedLabel.text = nil
            statusImageView.image = UIImage(systemName: "checkmark.circle.fill")
            statusImageView.tintColor = .systemGreen
            progressContainer.isHidden = true
        case .failed:
            statusLabel.text = task.errorMessage ?? "Failed"
            speedLabel.text = nil
            statusImageView.image = UIImage(systemName: "exclamationmark.circle")
            statusImageView.tintColor = .systemRed
            progressContainer.isHidden = true
        case .cancelled:
            statusLabel.text = "Cancelled"
            speedLabel.text = nil
            statusImageView.image = UIImage(systemName: "xmark.circle")
            statusImageView.tintColor = .systemGray
            progressContainer.isHidden = true
        }

        layoutIfNeeded()
    }

    private func iconForFile(_ fileName: String) -> UIImage? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "avi", "mkv", "wmv", "flv":
            return UIImage(systemName: "video.fill")
        case "mp3", "wav", "aac", "flac", "ogg", "m4a":
            return UIImage(systemName: "music.note")
        case "jpg", "jpeg", "png", "gif", "bmp", "webp", "heic":
            return UIImage(systemName: "photo.fill")
        case "pdf":
            return UIImage(systemName: "doc.text.fill")
        case "zip", "rar", "7z", "tar", "gz":
            return UIImage(systemName: "doc.zipper")
        case "dmg", "pkg", "exe", "msi", "apk":
            return UIImage(systemName: "app.fill")
        case "doc", "docx":
            return UIImage(systemName: "doc.richtext.fill")
        case "xls", "xlsx":
            return UIImage(systemName: "tablecells.fill")
        case "ppt", "pptx":
            return UIImage(systemName: "presentation.fill")
        case "txt", "md", "csv":
            return UIImage(systemName: "doc.plaintext.fill")
        default:
            return UIImage(systemName: "doc.fill")
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentProgress = 0
        progressFillTrailing.constant = 0
        progressContainer.isHidden = true
        speedLabel.text = nil
    }
}
