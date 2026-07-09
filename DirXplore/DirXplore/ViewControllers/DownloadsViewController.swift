import UIKit

@MainActor
final class DownloadsViewController: UIViewController {

    private let manager = DownloadManager.shared
    private var tasks: [DownloadTask] = []

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .insetGrouped)
        t.translatesAutoresizingMaskIntoConstraints = false
        t.register(DownloadCell.self, forCellReuseIdentifier: "DownloadCell")
        t.rowHeight = UITableView.automaticDimension
        t.estimatedRowHeight = 88
        t.separatorStyle = .none
        t.backgroundColor = .clear
        return t
    }()

    private let emptyIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "tray")
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let emptyTitle: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "No Downloads Yet"
        l.font = .systemFont(ofSize: 20, weight: .semibold)
        l.textColor = .secondaryLabel
        return l
    }()

    private let emptyDesc: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Paste a link on the Home tab to start"
        l.font = .systemFont(ofSize: 15, weight: .regular)
        l.textColor = .tertiaryLabel
        l.numberOfLines = 0
        l.textAlignment = .center
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Downloads"
        navigationController?.navigationBar.prefersLargeTitles = true

        view.addSubview(tableView)
        view.addSubview(emptyIcon)
        view.addSubview(emptyTitle)
        view.addSubview(emptyDesc)

        tableView.delegate = self
        tableView.dataSource = self

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyIcon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyIcon.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyIcon.widthAnchor.constraint(equalToConstant: 60),
            emptyIcon.heightAnchor.constraint(equalToConstant: 60),

            emptyTitle.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 16),
            emptyTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            emptyDesc.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 8),
            emptyDesc.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyDesc.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyDesc.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func refresh() {
        tasks = manager.tasks
        tableView.reloadData()
        let hasItems = !tasks.isEmpty
        emptyIcon.isHidden = hasItems
        emptyTitle.isHidden = hasItems
        emptyDesc.isHidden = hasItems
        navigationItem.rightBarButtonItem = manager.activeDownloads > 0
            ? UIBarButtonItem(title: "\(manager.activeDownloads) Active", style: .plain, target: nil, action: nil)
            : nil
    }

    private func showActions(for task: DownloadTask) {
        let a = UIAlertController(title: task.fileName, message: nil, preferredStyle: .actionSheet)
        switch task.status {
        case .downloading, .queued:
            a.addAction(UIAlertAction(title: "Pause", style: .default) { [weak self] _ in
                DownloadManager.shared.pauseTask(task.id)
                self?.refresh()
            })
        case .paused:
            a.addAction(UIAlertAction(title: "Resume", style: .default) { [weak self] _ in
                DownloadManager.shared.resumeTask(task.id)
                self?.refresh()
            })
        case .failed:
            a.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
                DownloadManager.shared.retryTask(task.id)
                self?.refresh()
            })
        case .completed:
            a.addAction(UIAlertAction(title: "Open", style: .default) { [weak self] _ in self?.open(task) })
            a.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in self?.share(task) })
        default: break
        }
        a.addAction(UIAlertAction(title: "Cancel Download", style: .destructive) { [weak self] _ in
            DownloadManager.shared.cancelTask(task.id)
            self?.refresh()
        })
        if task.status == .completed || task.status == .failed || task.status == .cancelled {
            a.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
                DownloadManager.shared.removeTask(task.id)
                self?.refresh()
            })
        }
        a.addAction(UIAlertAction(title: "Dismiss", style: .cancel))
        present(a, animated: true)
    }

    private func open(_ task: DownloadTask) {
        let u = FileManager.default.documentsDirectory.appendingPathComponent(task.fileName)
        guard FileManager.default.fileExists(atPath: u.path) else { return }
        let vc = UIDocumentInteractionController(url: u)
        vc.delegate = self
        vc.presentPreview(animated: true)
    }

    private func share(_ task: DownloadTask) {
        let u = FileManager.default.documentsDirectory.appendingPathComponent(task.fileName)
        guard FileManager.default.fileExists(atPath: u.path) else { return }
        present(UIActivityViewController(activityItems: [u], applicationActivities: nil), animated: true)
    }
}

extension DownloadsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tasks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadCell", for: indexPath) as! DownloadCell
        cell.configure(with: tasks[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showActions(for: tasks[indexPath.row])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let task = tasks[indexPath.row]
        var acts: [UIContextualAction] = []

        if task.status == .downloading || task.status == .queued {
            let p = UIContextualAction(style: .normal, title: "Pause") { [weak self] _, _, c in
                DownloadManager.shared.pauseTask(task.id); self?.refresh(); c(true)
            }
            p.backgroundColor = .systemOrange; acts.append(p)
        } else if task.status == .paused || task.status == .failed {
            let r = UIContextualAction(style: .normal, title: "Resume") { [weak self] _, _, c in
                DownloadManager.shared.resumeTask(task.id); self?.refresh(); c(true)
            }
            r.backgroundColor = .systemGreen; acts.append(r)
        }
        let d = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, c in
            DownloadManager.shared.removeTask(task.id); self?.refresh(); c(true)
        }
        acts.append(d)
        return UISwipeActionsConfiguration(actions: acts)
    }
}

extension DownloadsViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController { self }
}
