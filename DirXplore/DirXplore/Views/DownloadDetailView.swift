import SwiftUI

struct DownloadDetailView: View {
    let task: DownloadTask
    @EnvironmentObject var manager: DownloadManager

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    ProgressRing(progress: task.progress, lineWidth: 8, color: statusColor)
                        .frame(width: 80, height: 80)
                        .overlay {
                            if task.status == .downloading {
                                Text(task.progressPercentage)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                    VStack(spacing: 4) {
                        Text(task.fileName)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text(task.sourceType.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }

                    if task.status == .downloading {
                        HStack(spacing: 16) {
                            detailItem("Speed", task.formattedSpeed)
                            detailItem("ETA", task.formattedTimeRemaining)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            Section("Information") {
                infoRow("Status", statusText, icon: statusIcon)
                infoRow("Size", task.formattedFileSize, icon: "externaldrive")
                if task.downloadedBytes > 0 {
                    infoRow("Downloaded", task.formattedDownloadedSize, icon: "arrow.down.circle")
                }
                infoRow("Source", task.sourceType.rawValue, icon: "link")
                infoRow("Added", task.startDate.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
                if let completed = task.completionDate {
                    infoRow("Completed", completed.formatted(date: .abbreviated, time: .shortened), icon: "checkmark.circle")
                }
            }

            Section("Actions") {
                actionRow("Open File", icon: "doc.viewfinder", color: .blue) { openFile() }
                actionRow("Share", icon: "square.and.arrow.up", color: .blue) { shareFile() }
                actionRow("Delete", icon: "trash", color: .red, role: .destructive) { manager.removeTask(task.id) }
                if task.status == .downloading || task.status == .queued {
                    actionRow("Pause", icon: "pause.circle", color: .orange) { manager.pauseTask(task.id) }
                }
                if task.status == .paused || task.status == .failed {
                    actionRow("Resume", icon: "play.circle", color: .green) { manager.resumeTask(task.id) }
                }
                if task.status == .failed {
                    actionRow("Retry", icon: "arrow.clockwise", color: .green) { manager.retryTask(task.id) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusText: String {
        switch task.status {
        case .queued: return "Waiting"
        case .downloading: return "Downloading – \(task.progressPercentage)"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return task.errorMessage ?? "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .downloading, .queued: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }

    private var statusIcon: String {
        switch task.status {
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }

    private func detailItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func infoRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).font(.body).foregroundStyle(.secondary).frame(width: 24)
            Text(label).foregroundStyle(.primary)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func actionRow(_ title: String, icon: String, color: Color, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon).foregroundStyle(color)
        }
    }

    private func openFile() {
        let url = manager.documentsDir.appendingPathComponent(task.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let vc = UIDocumentInteractionController(url: url)
        vc.delegate = DocumentPreviewDelegate.shared
        vc.presentPreview(animated: true)
    }

    private func shareFile() {
        let url = manager.documentsDir.appendingPathComponent(task.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

private final class DocumentPreviewDelegate: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = DocumentPreviewDelegate()
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            return root
        }
        return UIViewController()
    }
}
