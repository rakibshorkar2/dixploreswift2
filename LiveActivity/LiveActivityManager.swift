import ActivityKit
import Foundation
import UIKit

@available(iOS 16.2, *)
actor LiveActivityManager {
    static let shared = LiveActivityManager()

    private var liveActivities: [String: Activity<DownloadActivityAttributes>] = [:]
    private var lastUpdateTime: [String: Date] = [:]
    private var lastReportedProgress: [String: Int] = [:]
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private let updateThrottleInterval: TimeInterval = 0.5

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "liveActivityEnabled")
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "liveActivityEnabled")
        if !enabled {
            endAll()
        }
    }

    func shouldThrottle(downloadId: String, progressPercent: Int) -> Bool {
        if let last = lastReportedProgress[downloadId], last == progressPercent {
            return true
        }
        if let lastUpdate = lastUpdateTime[downloadId],
           Date().timeIntervalSince(lastUpdate) < updateThrottleInterval {
            return true
        }
        return false
    }

    func create(downloadId: String, fileName: String) {
        guard isEnabled, liveActivities[downloadId] == nil else { return }
        let attributes = DownloadActivityAttributes(downloadId: downloadId)
        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            progress: 0,
            speed: "",
            eta: "--",
            downloadedSize: "",
            totalSize: "",
            status: "Queued",
            isCompleted: false
        )
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            liveActivities[downloadId] = activity
            lastReportedProgress[downloadId] = 0
            lastUpdateTime[downloadId] = Date()
            startBackgroundTask()
        } catch {
            debugPrint("Failed to start Live Activity: \(error)")
        }
    }

    func updateProgress(
        downloadId: String,
        fileName: String,
        progress: Double,
        speed: String,
        eta: String,
        downloadedSize: String,
        totalSize: String
    ) {
        guard isEnabled else { return }
        let progressPercent = Int(progress * 100)
        guard !shouldThrottle(downloadId: downloadId, progressPercent: progressPercent) else { return }
        guard let activity = liveActivities[downloadId] else { return }

        lastReportedProgress[downloadId] = progressPercent
        lastUpdateTime[downloadId] = Date()

        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            progress: progress,
            speed: speed,
            eta: eta,
            downloadedSize: downloadedSize,
            totalSize: totalSize,
            status: "Downloading",
            isCompleted: false
        )
        Task {
            await activity.update(using: state)
        }
    }

    func updateStatus(
        downloadId: String,
        fileName: String,
        progress: Double,
        status: String,
        isCompleted: Bool
    ) {
        guard isEnabled else { return }
        guard let activity = liveActivities[downloadId] else { return }

        let state = DownloadActivityAttributes.ContentState(
            fileName: fileName,
            progress: progress,
            speed: "",
            eta: "--",
            downloadedSize: "",
            totalSize: "",
            status: status,
            isCompleted: isCompleted
        )
        Task {
            await activity.update(using: state)
        }
    }

    func end(downloadId: String, finalProgress: Double, status: String, isCompleted: Bool) {
        guard isEnabled else { return }
        guard let activity = liveActivities.removeValue(forKey: downloadId) else { return }
        lastReportedProgress.removeValue(forKey: downloadId)
        lastUpdateTime.removeValue(forKey: downloadId)

        let state = DownloadActivityAttributes.ContentState(
            fileName: "",
            progress: finalProgress,
            speed: "",
            eta: "--",
            downloadedSize: "",
            totalSize: "",
            status: status,
            isCompleted: isCompleted
        )
        Task {
            if isCompleted {
                await activity.update(using: state)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await activity.end(dismissalPolicy: .default)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
            if liveActivities.isEmpty {
                self.endBackgroundTask()
            }
        }
    }

    func endAll() {
        for (downloadId, activity) in liveActivities {
            Task {
                await activity.end(dismissalPolicy: .immediate)
            }
            lastReportedProgress.removeValue(forKey: downloadId)
            lastUpdateTime.removeValue(forKey: downloadId)
        }
        liveActivities.removeAll()
        endBackgroundTask()
    }

    nonisolated func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        if bytes < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(bytes) / (1024 * 1024)) }
        return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
    }

    nonisolated func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_073_741.824 {
            return String(format: "%.2f GB/s", bytesPerSec / 1_073_741_824.0)
        } else if bytesPerSec >= 1_048.576 {
            return String(format: "%.2f MB/s", bytesPerSec / 1_048_576.0)
        } else if bytesPerSec >= 1.024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024.0)
        }
        return String(format: "%.0f B/s", bytesPerSec)
    }

    nonisolated func formatEta(_ seconds: Int) -> String {
        if seconds <= 0 { return "--" }
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 { return String(format: "%d:%02d:%02d", hrs, mins, secs) }
        if mins > 0 { return String(format: "%d:%02d", mins, secs) }
        return String(format: "0:%02d", secs)
    }

    private func startBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "LiveActivityUpdates") {
            Task { await self.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}
