import UIKit
import Combine

final class DownloadsViewController: UIViewController {

    private let manager = DownloadManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var tasks: [DownloadTask] = []

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .insetGrouped)
        t.translatesAutoresizingMaskIntoConstraints = false
        t.register(DownloadCell.self, forCellReuseIdentifier: "DownloadCell")
        t.rowHeight = UITableView.automaticDimension
        t.estimatedRowHeight = 88
        t.separatorStyle = .none
        t.backgroundColor = .clear
        t.showsVerticalScrollIndicator = false
        return t
    }()

    private let emptyStateView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let emptyIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "tray")
        iv.tintColor = .quaternaryLabel
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let emptyTitle: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "No Downloads Yet"
        l.font = .systemFont(ofSize: 20, weight: .semibold)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        return l
    }()

    private let emptySubtitle: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Paste a link on the Home tab to start downloading"
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.textColor = .tertiaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupConstraints()
        setupObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationBar()
        refreshData()
    }

    // MARK: - Setup

    private func setupView() {
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        emptyStateView.addSubview(emptyIcon)
        emptyStateView.addSubview(emptyTitle)
        emptyStateView.addSubview(emptySubtitle)

        tableView.delegate = self
        tableView.dataSource = self
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            emptyIcon.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyIcon.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyIcon.widthAnchor.constraint(equalToConstant: 64),
            emptyIcon.heightAnchor.constraint(equalToConstant: 64),
            emptyTitle.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 16),
            emptyTitle.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyTitle.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyTitle.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptySubtitle.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 8),
            emptySubtitle.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptySubtitle.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptySubtitle.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptySubtitle.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor),
        ])
    }

    private func configureNavigationBar() {
        title = "Downloads"
        navigationController?.navigationBar.prefersLargeTitles = true

        let activeCount = manager.activeDownloads
        if activeCount > 0 {
            let countLabel = UILabel()
            countLabel.text = "\(activeCount) Active"
            countLabel.font = .systemFont(ofSize: 13, weight: .medium)
            countLabel.textColor = .tintColor
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: countLabel)
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func refreshData() {
        Task { @MainActor in
            self.tasks = manager.tasks
            self.tableView.reloadData()
            self.emptyStateView.isHidden = !tasks.isEmpty
            self.configureNavigationBar()
        }
    }

    private func showTaskOptions(_ task: DownloadTask) {
        let alert = UIAlertController(title: task.fileName, message: nil, preferredStyle: .actionSheet)

        switch task.status {
        case .downloading, .queued:
            alert.addAction(UIAlertAction(title: "Pause", style: .default) { [weak self] _ in
                Task { await DownloadManager.shared.pauseTask(task.id) }
                self?.refreshData()
            })
        case .paused:
            alert.addAction(UIAlertAction(title: "Resume", style: .default) { [weak self] _ in
                Task { await DownloadManager.shared.resumeTask(task.id) }
                self?.refreshData()
            })
        case .failed:
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
                Task { await DownloadManager.shared.retryTask(task.id) }
                self?.refreshData()
            })
        case .completed:
            alert.addAction(UIAlertAction(title: "Open File", style: .default) { [weak self] _ in
                self?.openFile(task)
            })
            alert.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
                self?.shareFile(task)
            })
        default:
            break
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive) { [weak self] _ in
            Task { await DownloadManager.shared.cancelTask(task.id) }
            self?.refreshData()
        })

        if task.status == .completed || task.status == .failed {
            alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
                Task { await DownloadManager.shared.removeTask(task.id) }
                self?.refreshData()
            })
        }

        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(alert, animated: true)
    }

    private func openFile(_ task: DownloadTask) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDir.appendingPathComponent(task.fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let vc = UIDocumentInteractionController(url: fileURL)
        vc.delegate = self
        vc.presentPreview(animated: true)
    }

    private func shareFile(_ task: DownloadTask) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDir.appendingPathComponent(task.fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        present(activity, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension DownloadsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        let statuses = tasks.map { $0.status }
        let hasActive = statuses.contains { $0 == .downloading || $0 == .queued || $0 == .paused }
        let hasCompleted = statuses.contains { $0 == .completed }
        let hasFailed = statuses.contains { $0 == .failed }
        return (hasActive ? 1 : 0) + (hasCompleted ? 1 : 0) + (hasFailed ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            let active = tasks.filter { $0.status == .downloading || $0.status == .queued || $0.status == .paused }
            return active.isEmpty ? (tasks.contains { $0.status == .completed } ? tasks.filter { $0.status == .completed }.count : tasks.filter { $0.status == .failed }.count) : active.count
        case 1:
            let completed = tasks.filter { $0.status == .completed }
            let hasActive = tasks.contains { $0.status == .downloading || $0.status == .queued || $0.status == .paused }
            if hasActive {
                return completed.isEmpty ? tasks.filter { $0.status == .failed }.count : completed.count
            } else {
                let failed = tasks.filter { $0.status == .failed }
                return failed.isEmpty ? completed.count : failed.count
            }
        case 2:
            return tasks.filter { $0.status == .failed }.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let active = tasks.filter { $0.status == .downloading || $0.status == .queued || $0.status == .paused }
        let completed = tasks.filter { $0.status == .completed }
        let failed = tasks.filter { $0.status == .failed }

        switch section {
        case 0:
            if !active.isEmpty { return "Active" }
            if !completed.isEmpty { return "Completed" }
            return "Failed"
        case 1:
            if !active.isEmpty && !completed.isEmpty { return "Completed" }
            if !active.isEmpty && !failed.isEmpty { return "Failed" }
            return completed.isEmpty ? "Failed" : "Completed"
        case 2:
            return "Failed"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadCell", for: indexPath) as! DownloadCell
        let task = taskForIndexPath(indexPath)
        cell.configure(with: task)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let task = taskForIndexPath(indexPath)
        showTaskOptions(task)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let task = taskForIndexPath(indexPath)
        var actions: [UIContextualAction] = []

        if task.status == .downloading || task.status == .queued {
            let pause = UIContextualAction(style: .normal, title: "Pause") { [weak self] _, _, completion in
                Task { await DownloadManager.shared.pauseTask(task.id) }
                self?.refreshData()
                completion(true)
            }
            pause.backgroundColor = .systemOrange
            actions.append(pause)
        } else if task.status == .paused || task.status == .failed {
            let resume = UIContextualAction(style: .normal, title: "Resume") { [weak self] _, _, completion in
                Task { await DownloadManager.shared.resumeTask(task.id) }
                self?.refreshData()
                completion(true)
            }
            resume.backgroundColor = .systemGreen
            actions.append(resume)
        }

        if task.status == .completed {
            let share = UIContextualAction(style: .normal, title: "Share") { [weak self] _, _, completion in
                self?.shareFile(task)
                completion(true)
            }
            share.backgroundColor = .tintColor
            actions.append(share)
        }

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            Task { await DownloadManager.shared.removeTask(task.id) }
            self?.refreshData()
            completion(true)
        }
        actions.append(delete)

        return UISwipeActionsConfiguration(actions: actions)
    }

    private func taskForIndexPath(_ indexPath: IndexPath) -> DownloadTask {
        let section = indexPath.section
        let active = tasks.filter { $0.status == .downloading || $0.status == .queued || $0.status == .paused }
        let completed = tasks.filter { $0.status == .completed }
        let failed = tasks.filter { $0.status == .failed }

        switch section {
        case 0:
            if !active.isEmpty {
                return active[indexPath.row]
            }
            if !completed.isEmpty {
                return completed[indexPath.row]
            }
            return failed[indexPath.row]
        case 1:
            if !active.isEmpty && !completed.isEmpty {
                return completed[indexPath.row]
            }
            if !active.isEmpty {
                return failed[indexPath.row]
            }
            return completed.isEmpty ? failed[indexPath.row] : completed[indexPath.row]
        case 2:
            return failed[indexPath.row]
        default:
            return tasks[indexPath.row]
        }
    }
}

// MARK: - UIDocumentInteractionControllerDelegate

extension DownloadsViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        self
    }
}
