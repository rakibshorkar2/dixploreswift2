import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    func startActivity(for task: DownloadTask) {
        // Double check permissions and if activity is already running
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let taskIdString = task.id.uuidString
        guard !Activity<DownloadActivityAttributes>.activities.contains(where: { $0.attributes.downloadTaskId == taskIdString }) else {
            return
        }

        let attributes = DownloadActivityAttributes(
            fileName: task.fileName,
            downloadTaskId: taskIdString
        )
        
        let state = DownloadActivityAttributes.ContentState(
            progress: task.progress,
            downloadedBytes: task.downloadedBytes,
            fileSize: task.fileSize,
            downloadSpeed: task.downloadSpeed,
            status: formatStatus(task.status),
            formattedTimeRemaining: task.formattedTimeRemaining
        )

        let content = ActivityContent(state: state, staleDate: nil)
        do {
            _ = try Activity.request(attributes: attributes, content: content)
            print("Successfully requested Live Activity for task: \(task.fileName)")
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    func updateActivity(for task: DownloadTask) {
        let taskIdString = task.id.uuidString
        guard let activity = Activity<DownloadActivityAttributes>.activities.first(where: { $0.attributes.downloadTaskId == taskIdString }) else {
            // Fallback: if task is downloading but activity is missing, start it
            if task.status == .downloading {
                startActivity(for: task)
            }
            return
        }

        let state = DownloadActivityAttributes.ContentState(
            progress: task.progress,
            downloadedBytes: task.downloadedBytes,
            fileSize: task.fileSize,
            downloadSpeed: task.downloadSpeed,
            status: formatStatus(task.status),
            formattedTimeRemaining: task.formattedTimeRemaining
        )

        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            await activity.update(content)
        }
    }

    func endActivity(for task: DownloadTask) {
        let taskIdString = task.id.uuidString
        guard let activity = Activity<DownloadActivityAttributes>.activities.first(where: { $0.attributes.downloadTaskId == taskIdString }) else {
            return
        }

        let state = DownloadActivityAttributes.ContentState(
            progress: task.progress,
            downloadedBytes: task.downloadedBytes,
            fileSize: task.fileSize,
            downloadSpeed: task.downloadSpeed,
            status: formatStatus(task.status),
            formattedTimeRemaining: task.formattedTimeRemaining
        )

        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            let policy: ActivityDismissalPolicy
            switch task.status {
            case .completed:
                // Keep the completed status visible on lock screen for 5 seconds
                policy = .after(Date().addingTimeInterval(5))
            default:
                policy = .immediate
            }
            await activity.end(content, dismissalPolicy: policy)
        }
    }

    func endAllActivities() {
        for activity in Activity<DownloadActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func formatStatus(_ status: DownloadStatus) -> String {
        switch status {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}
