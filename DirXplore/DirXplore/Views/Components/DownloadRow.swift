import SwiftUI

struct DownloadRow: View {
    let task: DownloadTask
    @EnvironmentObject var manager: DownloadManager

    var body: some View {
        HStack(spacing: 14) {
            fileIcon
            VStack(alignment: .leading, spacing: 3) {
                Text(task.fileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusRow
            }
            Spacer(minLength: 8)
            ProgressRing(progress: task.progress, color: statusColor)
                .frame(width: 36, height: 36)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 14))
        .contextMenu { contextMenu }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { trailingSwipe }
        .swipeActions(edge: .leading) { leadingSwipe }
    }

    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(statusColor.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: statusIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(statusColor)
        }
    }

    private var statusIcon: String {
        switch task.status {
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        case .cancelled: return "xmark.circle"
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

    @ViewBuilder
    private var statusRow: some View {
        switch task.status {
        case .downloading:
            HStack(spacing: 4) {
                Text(task.progressPercentage).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text("•").foregroundStyle(.tertiary)
                Text(task.formattedSpeed).font(.caption).foregroundStyle(.tertiary)
                Text("•").foregroundStyle(.tertiary)
                Text(task.formattedTimeRemaining).font(.caption).foregroundStyle(.tertiary)
            }
        case .queued:
            Label("Waiting", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
        case .paused:
            Label("Paused – \(task.progressPercentage)", systemImage: "pause.circle").font(.caption).foregroundStyle(.orange)
        case .completed:
            HStack(spacing: 4) {
                Text("Downloaded").font(.caption.weight(.medium)).foregroundStyle(.green)
                Text("•").foregroundStyle(.tertiary)
                Text(task.formattedFileSize).font(.caption).foregroundStyle(.secondary)
            }
        case .failed:
            Label(task.errorMessage ?? "Failed", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red).lineLimit(1)
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        switch task.status {
        case .downloading, .queued:
            Button { manager.pauseTask(task.id) } label: { Label("Pause", systemImage: "pause.circle") }
        case .paused:
            Button { manager.resumeTask(task.id) } label: { Label("Resume", systemImage: "play.circle") }
        case .failed:
            Button { manager.retryTask(task.id) } label: { Label("Retry", systemImage: "arrow.clockwise") }
        case .completed:
            Button { openFile() } label: { Label("Open", systemImage: "doc.viewfinder") }
            Button { shareFile() } label: { Label("Share", systemImage: "square.and.arrow.up") }
        default: EmptyView()
        }
        Divider()
        if task.status != .cancelled {
            Button(role: .destructive) { manager.cancelTask(task.id) } label: { Label("Cancel", systemImage: "xmark.circle") }
        }
        Button(role: .destructive) { manager.removeTask(task.id) } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private var trailingSwipe: some View {
        if task.status == .downloading || task.status == .queued {
            Button { manager.pauseTask(task.id) } label: { Label("Pause", systemImage: "pause.circle") }.tint(.orange)
        } else if task.status == .paused || task.status == .failed {
            Button { manager.resumeTask(task.id) } label: { Label("Resume", systemImage: "play.circle") }.tint(.green)
        }
        Button(role: .destructive) { manager.removeTask(task.id) } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private var leadingSwipe: some View {
        if task.status == .completed {
            Button { openFile() } label: { Label("Open", systemImage: "doc.viewfinder") }.tint(.blue)
        }
    }

    private func openFile() {
        let url = manager.documentsDir.appendingPathComponent(task.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let vc = UIDocumentInteractionController(url: url)
        vc.delegate = DocumentInteractionDelegate.shared
        vc.presentPreview(animated: true)
    }

    private func shareFile() {
        let url = manager.documentsDir.appendingPathComponent(task.fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(av)
    }

    private func present(_ vc: UIViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}

private final class DocumentInteractionDelegate: NSObject, UIDocumentInteractionControllerDelegate {
    static let shared = DocumentInteractionDelegate()
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            return root
        }
        return UIViewController()
    }
}
