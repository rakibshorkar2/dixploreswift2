import Foundation
import Combine
import UserNotifications

actor DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @MainActor @Published var tasks: [DownloadTask] = []
    @MainActor @Published var activeDownloads: Int = 0
    @MainActor @Published var completedDownloads: Int = 0
    @MainActor @Published var totalBytesDownloaded: Int64 = 0

    private var urlSession: URLSession!
    private var backgroundSession: URLSession!
    private var ongoingDownloads: [UUID: URLSessionDownloadTask] = [:]
    private var taskProgress: [UUID: Double] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let tasksKey = "saved_download_tasks"
    private let progressPublisher = PassthroughSubject<(UUID, Double), Never>()

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

        super.init()

        self.urlSession = URLSession(configuration: foregroundConfig, delegate: nil, delegateQueue: nil)
        self.backgroundSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

        Task { await loadTasks() }
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

    private func loadTasks() async {
        guard let data = UserDefaults.standard.data(forKey: tasksKey),
              let savedTasks = try? decoder.decode([DownloadTask].self, from: data) else { return }
        await MainActor.run {
            tasks = savedTasks
            activeDownloads = tasks.filter { $0.status == .downloading || $0.status == .queued }.count
            completedDownloads = tasks.filter { $0.status == .completed }.count
            totalBytesDownloaded = tasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
        }
    }

    private func saveTasks() async {
        let currentTasks = await tasks
        guard let data = try? encoder.encode(currentTasks) else { return }
        UserDefaults.standard.set(data, forKey: tasksKey)
        await updateCounts()
    }

    @MainActor
    private func updateCounts() {
        activeDownloads = tasks.filter { $0.status == .downloading || $0.status == .queued }.count
        completedDownloads = tasks.filter { $0.status == .completed }.count
        totalBytesDownloaded = tasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
    }

    func addTask(url: URL, fileName: String? = nil, sourceType: LinkSourceType = .direct) async {
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
        await MainActor.run { tasks.insert(task, at: 0) }
        await saveTasks()
        await startDownload(task)
    }

    func startDownload(_ task: DownloadTask) async {
        await updateTaskStatus(task.id, status: .downloading)
        let request = URLRequest(url: task.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)

        let progressStream = AsyncStream<Double> { continuation in
            let observation = self.progressPublisher.sink { [weak self] id, progress in
                guard id == task.id else { return }
                continuation.yield(progress)
            }
            continuation.onTermination = { _ in observation.cancel() }
        }

        Task {
            var observation: Any?
            observation = progressPublisher.sink { [weak self] id, progress in
                Task { [weak self] in
                    await self?.updateTaskProgress(task.id, progress: progress)
                }
            }
        }

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
            }
            await saveTasks()
            await sendNotification(title: "Download Complete", body: "\(task.fileName) downloaded successfully")

        } catch {
            var failed = task
            failed.status = .failed
            failed.errorMessage = error.localizedDescription
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[idx] = failed
                }
            }
            await saveTasks()
            await sendNotification(title: "Download Failed", body: "\(task.fileName): \(error.localizedDescription)")
        }
    }

    func pauseTask(_ id: UUID) async {
        guard let task = await tasks.first(where: { $0.id == id }),
              task.status == .downloading else { return }
        ongoingDownloads[id]?.cancel(byProducingResumeData: { data in
            Task { await self.updateTaskResumeData(id, data: data) }
        })
        ongoingDownloads[id] = nil
        await updateTaskStatus(id, status: .paused)
    }

    func resumeTask(_ id: UUID) async {
        guard let task = await tasks.first(where: { $0.id == id }),
              task.status == .paused, let resumeData = task.resumeData else {
            if let task = await tasks.first(where: { $0.id == id }) {
                await startDownload(task)
            }
            return
        }
        await updateTaskStatus(id, status: .downloading)
        let downloadTask = urlSession.downloadTask(withResumeData: resumeData)
        ongoingDownloads[id] = downloadTask
        downloadTask.resume()
    }

    func cancelTask(_ id: UUID) async {
        ongoingDownloads[id]?.cancel()
        ongoingDownloads[id] = nil
        await updateTaskStatus(id, status: .cancelled)
    }

    func removeTask(_ id: UUID) async {
        ongoingDownloads[id]?.cancel()
        ongoingDownloads[id] = nil
        await MainActor.run { tasks.removeAll { $0.id == id } }
        await saveTasks()
    }

    func retryTask(_ id: UUID) async {
        guard let task = await tasks.first(where: { $0.id == id }) else { return }
        var retryTask = task
        retryTask.status = .queued
        retryTask.progress = 0
        retryTask.downloadedBytes = 0
        retryTask.errorMessage = nil
        retryTask.startDate = Date()
        await MainActor.run {
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx] = retryTask
            }
        }
        await saveTasks()
        await startDownload(retryTask)
    }

    private func updateTaskStatus(_ id: UUID, status: DownloadStatus) async {
        await MainActor.run {
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                var task = tasks[idx]
                task.status = status
                tasks[idx] = task
            }
        }
        await saveTasks()
    }

    private func updateTaskProgress(_ id: UUID, progress: Double) async {
        await MainActor.run {
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                var task = tasks[idx]
                task.progress = progress
                task.downloadedBytes = Int64(Double(task.fileSize) * progress)
                tasks[idx] = task
            }
        }
        await saveTasks()
    }

    private func updateTaskResumeData(_ id: UUID, data: Data?) async {
        await MainActor.run {
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                var task = tasks[idx]
                task.resumeData = data
                tasks[idx] = task
            }
        }
        await saveTasks()
    }

    func retryFailedTasks() async {
        let failedTasks = await tasks.filter { $0.status == .failed }
        for task in failedTasks {
            await retryTask(task.id)
        }
    }

    func clearCompleted() async {
        await MainActor.run { tasks.removeAll { $0.status == .completed } }
        await saveTasks()
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
