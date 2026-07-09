import UIKit
import MessageUI

@MainActor
final class SettingsViewController: UIViewController {

    private let manager = DownloadManager.shared

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .insetGrouped)
        t.translatesAutoresizingMaskIntoConstraints = false
        t.backgroundColor = .clear
        t.showsVerticalScrollIndicator = false
        return t
    }()

    private struct SettingsSection {
        let title: String
        let items: [SettingsItem]
    }

    private struct SettingsItem {
        let icon: String
        let iconColor: UIColor
        let title: String
        let subtitle: String?
        let type: ItemType
    }

    private enum ItemType {
        case toggle(Bool)
        case disclosure
        case action
        case info(String)
    }

    private var sections: [SettingsSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        buildSections()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Settings"
        buildSections()
        tableView.reloadData()
    }

    private func setupView() {
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func buildSections() {
        let totalSize = getDownloadsSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        sections = [
            SettingsSection(title: "Storage", items: [
                SettingsItem(icon: "externaldrive", iconColor: .systemBlue, title: "Downloads", subtitle: formatter.string(fromByteCount: totalSize), type: .disclosure),
                SettingsItem(icon: "trash", iconColor: .systemRed, title: "Clear Completed Downloads", subtitle: nil, type: .action),
            ]),
            SettingsSection(title: "Downloads", items: [
                SettingsItem(icon: "antenna.radiowaves.left.and.right", iconColor: .systemGreen, title: "Cellular Downloads", subtitle: "Allow downloads over cellular", type: .toggle(UserDefaults.standard.bool(forKey: "cellular_downloads"))),
                SettingsItem(icon: "bell", iconColor: .systemOrange, title: "Notifications", subtitle: "Get notified when downloads complete", type: .toggle(UserDefaults.standard.bool(forKey: "notifications_enabled"))),
                SettingsItem(icon: "wifi", iconColor: .systemBlue, title: "Wi-Fi Only", subtitle: "Only download on Wi-Fi", type: .toggle(UserDefaults.standard.bool(forKey: "wifi_only"))),
            ]),
            SettingsSection(title: "About", items: [
                SettingsItem(icon: "info.circle", iconColor: .tintColor, title: "Version", subtitle: "1.0.0", type: .info("1.0.0")),
                SettingsItem(icon: "envelope", iconColor: .systemPurple, title: "Contact Support", subtitle: nil, type: .action),
                SettingsItem(icon: "star", iconColor: .systemYellow, title: "Rate DirXplore Pro", subtitle: nil, type: .action),
            ]),
        ]
    }

    private func getDownloadsSize() -> Int64 {
        let documentsDir = DownloadManager.shared.documentsDir
        guard let enumerator = FileManager.default.enumerator(at: documentsDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]),
                  let size = attrs.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }

    private func clearCompletedDownloads() {
        let alert = UIAlertController(
            title: "Clear Completed Downloads",
            message: "This will remove all completed download files from your device.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            DownloadManager.shared.clearCompleted()
            self?.clearDownloadedFiles()
            self?.buildSections()
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func clearDownloadedFiles() {
        let documentsDir = DownloadManager.shared.documentsDir
        guard let files = try? FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section].items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        cell.backgroundColor = .secondarySystemGroupedBackground

        var config = cell.defaultContentConfiguration()
        config.image = UIImage(systemName: item.icon)
        config.imageProperties.tintColor = item.iconColor
        config.text = item.title
        config.secondaryText = item.subtitle
        config.imageProperties.maximumSize = CGSize(width: 24, height: 24)
        config.textToSecondaryTextVerticalPadding = 2

        switch item.type {
        case .toggle(let isOn):
            let toggle = UISwitch()
            toggle.isOn = isOn
            toggle.tag = indexPath.section * 100 + indexPath.row
            toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        case .disclosure:
            cell.accessoryType = .disclosureIndicator
        case .action:
            cell.accessoryType = .none
        case .info:
            cell.accessoryType = .none
            config.secondaryText = item.subtitle
        }

        cell.contentConfiguration = config
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section].items[indexPath.row]

        switch item.title {
        case "Clear Completed Downloads":
            clearCompletedDownloads()
        case "Contact Support":
            contactSupport()
        case "Rate DirXplore Pro":
            rateApp()
        case "Downloads":
            showDownloadsStorage()
        default:
            break
        }
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        let item = sections[sender.tag / 100].items[sender.tag % 100]
        switch item.title {
        case "Cellular Downloads":
            UserDefaults.standard.set(sender.isOn, forKey: "cellular_downloads")
        case "Notifications":
            UserDefaults.standard.set(sender.isOn, forKey: "notifications_enabled")
            if sender.isOn {
                Task { await DownloadManager.shared.requestNotificationPermission() }
            }
        case "Wi-Fi Only":
            UserDefaults.standard.set(sender.isOn, forKey: "wifi_only")
        default:
            break
        }
    }

    private func contactSupport() {
        guard MFMailComposeViewController.canSendMail() else {
            let alert = UIAlertController(title: "Cannot Send Mail",
                                          message: "Please configure a Mail account or contact us at support@dirxplore.com",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let composer = MFMailComposeViewController()
        composer.setToRecipients(["support@dirxplore.com"])
        composer.setSubject("DirXplore Pro Support")
        composer.mailComposeDelegate = self
        present(composer, animated: true)
    }

    private func rateApp() {
        let url = "https://apps.apple.com/app/id0000000000"
        guard let writeURL = URL(string: url) else { return }
        UIApplication.shared.open(writeURL)
    }

    private func showDownloadsStorage() {
        let documentsDir = DownloadManager.shared.documentsDir
        let vc = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        vc.allowsMultipleSelection = false
        present(vc, animated: true)
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}
