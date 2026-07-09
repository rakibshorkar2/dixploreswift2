import Foundation
import Combine
import UserNotifications

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var tasks: [DownloadTask] = []
    @Published var activeDownloads: Int = 0
    @Published var completedDownloads: Int = 0
    @Published var totalBytesDownloaded: Int64 = 0

    private var urlSession: URLSession!
    private var backgroundSession: URLSession!
    private var ongoingDownloads: [UUID: URLSessionDownloadTask] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let tasksKey = "saved_download_tasks"

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.dirxplore.background")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 86400

        let foregroundConfig = URLSessionConfiguration.default
        foregroundConfig.waitsForConnectivity = true

        self.urlSession = URLSession(configuration: foregroundConfig, delegate: nil, delegateQueue: nil)
        self.backgroundSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

        loadTasks()
    }

    func setupBackgroundSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.dirxplore.background")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 86400
        self.backgroundSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }

    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: tasksKey),
              let savedTasks = try? decoder.decode([DownloadTask].self, from: data) else { return }
        tasks = savedTasks
        activeDownloads = tasks.filter { $0.status == .downloading || $0.status == .queued }.count
        completedDownloads = tasks.filter { $0.status == .completed }.count
        totalBytesDownloaded = tasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
    }

    private func saveTasks() {
        guard let data = try? encoder.encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: tasksKey)
        updateCounts()
    }

    private func updateCounts() {
        activeDownloads = tasks.filter { $0.status == .downloading || $0.status == .queued }.count
        completedDownloads = tasks.filter { $0.status == .completed }.count
        totalBytesDownloaded = tasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
    }

    func addTask(url: URL, fileName: String? = nil, sourceType: LinkSourceType = .direct) {
        let task = DownloadTask(
            id: UUID(),
            url: url,
            fileName: fileName ?? url.lastPathComponent,
            fileSize: 0,
            downloadedBytes: 0,
            status: .queued,
            progress: 0,
            startDate: Date(),
            sourceType: sourceType
        )
        tasks.insert(task, at: 0)
        saveTasks()
        startDownload(task)
    }

    func startDownload(_ task: DownloadTask) {
        updateTaskStatus(task.id, status: .downloading)
        let request = URLRequest(url: task.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)

        Task {
            do {
                let (localURL, response) = try await urlSession.download(for: request)
                let fileSize = response.expectedContentLength
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsDir.appendingPathComponent(task.fileName)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: localURL, to: destinationURL)

                var updated = task
                updated.fileSize = max(fileSize, 0)
                updated.downloadedBytes = max(fileSize, 0)
                updated.progress = 1.0
                updated.status = .completed
                updated.completionDate = Date()

                await MainActor.run {
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx] = updated
                    }
                    saveTasks()
                }
                await sendNotification(title: "Download Complete", body: "\(task.fileName) downloaded successfully")

            } catch {
                var failed = task
                failed.status = .failed
                failed.errorMessage = error.localizedDescription
                await MainActor.run {
                    if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                        tasks[idx] = failed
                    }
                    saveTasks()
                }
                await sendNotification(title: "Download Failed", body: "\(task.fileName): \(error.localizedDescription)")
            }
        }
    }

    func pauseTask(_ id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }),
              task.status == .downloading else { return }
        ongoingDownloads[id]?.cancel(byProducingResumeData: { data in
            Task { await MainActor.run { self.updateTaskResumeData(id, data: data) } }
        })
        ongoingDownloads[id] = nil
        updateTaskStatus(id, status: .paused)
    }

    func resumeTask(_ id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }),
              task.status == .paused, let resumeData = task.resumeData else {
            if let task = tasks.first(where: { $0.id == id }) {
                startDownload(task)
            }
            return
        }
        updateTaskStatus(id, status: .downloading)
        let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
        ongoingDownloads[id] = downloadTask
        downloadTask.resume()
    }

    func cancelTask(_ id: UUID) {
        ongoingDownloads[id]?.cancel()
        ongoingDownloads[id] = nil
        updateTaskStatus(id, status: .cancelled)
    }

    func removeTask(_ id: UUID) {
        ongoingDownloads[id]?.cancel()
        ongoingDownloads[id] = nil
        tasks.removeAll { $0.id == id }
        saveTasks()
    }

    func retryTask(_ id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        var retryTask = task
        retryTask.status = .queued
        retryTask.progress = 0
        retryTask.downloadedBytes = 0
        retryTask.errorMessage = nil
        retryTask.startDate = Date()
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx] = retryTask
        }
        saveTasks()
        startDownload(retryTask)
    }

    private func updateTaskStatus(_ id: UUID, status: DownloadStatus) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[idx]
            task.status = status
            tasks[idx] = task
        }
        saveTasks()
    }

    private func updateTaskProgress(_ id: UUID, progress: Double) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[idx]
            task.progress = progress
            task.downloadedBytes = Int64(Double(task.fileSize) * progress)
            tasks[idx] = task
        }
        saveTasks()
    }

    private func updateTaskResumeData(_ id: UUID, data: Data?) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            var task = tasks[idx]
            task.resumeData = data
            tasks[idx] = task
        }
        saveTasks()
    }

    func retryFailedTasks() {
        let failedTasks = tasks.filter { $0.status == .failed }
        for task in failedTasks {
            retryTask(task.id)
        }
    }

    func clearCompleted() {
        tasks.removeAll { $0.status == .completed }
        saveTasks()
    }

    private func sendNotification(title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}
