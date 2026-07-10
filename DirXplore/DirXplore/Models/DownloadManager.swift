import Foundation
import Combine
@preconcurrency import UserNotifications

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    var documentsDir: URL {
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            let fallback = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DirXplore Pro", isDirectory: true)
            try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        }
        let appFolder = docsDir.appendingPathComponent("DirXplore Pro", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder
    }

    @Published var tasks: [DownloadTask] = []
    @Published var activeDownloads: Int = 0
    @Published var completedDownloads: Int = 0
    @Published var totalBytesDownloaded: Int64 = 0
    @Published var totalDownloadSpeed: Double = 0
    @Published var isDownloading: Bool = false

    var backgroundCompletionHandler: (() -> Void)?

    private var foregroundSession: URLSession!
    private var backgroundSession: URLSession?
    private var ongoingDownloads: [UUID: URLSessionDownloadTask] = [:]
    private var progressTimers: [UUID: Date] = [:]
    private var lastBytes: [UUID: Int64] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let tasksKey = "saved_download_tasks"
    private let maxConcurrentDownloads = 3
    private var speedUpdateTimer: Timer?

    private override init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 86400
        config.httpMaximumConnectionsPerHost = maxConcurrentDownloads
        super.init()
        self.foregroundSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        loadTasks()
    }

    deinit {
        speedUpdateTimer?.invalidate()
    }

    func setupBackgroundSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.dirxplore.background")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 86400
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    private func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: tasksKey),
              let savedTasks = try? decoder.decode([DownloadTask].self, from: data) else { return }
        tasks = savedTasks
        refreshCounts()
    }

    private func saveTasks() {
        guard let data = try? encoder.encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: tasksKey)
        refreshCounts()
    }

    private func refreshCounts() {
        let active = tasks.filter { $0.status == .downloading || $0.status == .queued }
        activeDownloads = tasks.filter { $0.status == .downloading }.count
        completedDownloads = tasks.filter { $0.status == .completed }.count
        totalBytesDownloaded = tasks.filter { $0.status == .completed }.reduce(0) { $0 + max(0, $1.fileSize) }
        isDownloading = active.contains { $0.status == .downloading }
    }

    func addTask(url: URL, fileName: String? = nil, sourceType: LinkSourceType = .direct, priority: Int = 0, category: String? = nil) {
        let task = DownloadTask(
            id: UUID(),
            url: url,
            fileName: fileName ?? url.lastPathComponent,
            fileSize: 0,
            downloadedBytes: 0,
            status: .queued,
            progress: 0,
            startDate: Date(),
            sourceType: sourceType,
            downloadSpeed: 0,
            retryCount: 0,
            priority: priority,
            category: category
        )
        tasks.insert(task, at: 0)
        saveTasks()
        processQueue()
    }

    func addBatch(urls: [URL], sourceType: LinkSourceType = .direct) {
        for url in urls {
            let task = DownloadTask(
                id: UUID(),
                url: url,
                fileName: url.lastPathComponent,
                fileSize: 0,
                downloadedBytes: 0,
                status: .queued,
                progress: 0,
                startDate: Date(),
                sourceType: sourceType,
                downloadSpeed: 0,
                retryCount: 0,
                priority: 0,
                category: "Batch"
            )
            tasks.insert(task, at: 0)
        }
        saveTasks()
        processQueue()
    }

    private func processQueue() {
        let activeCount = tasks.filter { $0.status == .downloading }.count
        let maxToStart = max(0, maxConcurrentDownloads - activeCount)
        let queued = tasks
            .filter { $0.status == .queued }
            .sorted { $0.priority > $1.priority }
            .prefix(maxToStart)

        for task in queued {
            startDownload(task)
        }
    }

    private func startDownload(_ task: DownloadTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].status = .downloading
        tasks[idx].startDate = Date()
        saveTasks()

        let request = URLRequest(url: task.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        progressTimers[task.id] = Date()
        lastBytes[task.id] = 0

        let downloadTask = foregroundSession.downloadTask(with: request)
        downloadTask.taskDescription = task.id.uuidString
        ongoingDownloads[task.id] = downloadTask
        downloadTask.resume()

        startSpeedMonitor()
    }

    private func startSpeedMonitor() {
        speedUpdateTimer?.invalidate()
        speedUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAllSpeeds()
            }
        }
    }

    private func updateAllSpeeds() {
        var totalSpeed: Double = 0
        for (id, _) in ongoingDownloads {
            guard let idx = tasks.firstIndex(where: { $0.id == id }) else { continue }
            let now = Date()
            let elapsed = now.timeIntervalSince(progressTimers[id] ?? now)
            if elapsed >= 1.0 {
                let currentBytes = tasks[idx].downloadedBytes
                let last = lastBytes[id] ?? 0
                let speed = Double(currentBytes - last) / elapsed
                tasks[idx].downloadSpeed = max(0, speed)
                totalSpeed += tasks[idx].downloadSpeed
                progressTimers[id] = now
                lastBytes[id] = currentBytes
            }
        }
        totalDownloadSpeed = totalSpeed
    }

    func pauseTask(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }),
              tasks[idx].status == .downloading else { return }

        ongoingDownloads[id]?.cancel(byProducingResumeData: { data in
            Task { @MainActor in
                self.updateTaskResumeData(id, data: data)
            }
        })
        ongoingDownloads[id] = nil
        progressTimers[id] = nil
        lastBytes[id] = nil

        tasks[idx].status = .paused
        saveTasks()
    }

    func resumeTask(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = tasks[idx]

        if task.status == .paused, let resumeData = task.resumeData {
            tasks[idx].status = .downloading
            tasks[idx].startDate = Date()
            saveTasks()

            progressTimers[id] = Date()
            lastBytes[id] = task.downloadedBytes
            let downloadTask = foregroundSession.downloadTask(withResumeData: resumeData)
            ongoingDownloads[id] = downloadTask
            downloadTask.resume()
            startSpeedMonitor()
        } else {
            startDownload(task)
        }
    }

    func cancelTask(_ id: UUID) {
        ongoingDownloads[id]?.cancel()
        cleanupTask(id)
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].status = .cancelled
            saveTasks()
        }
    }

    func removeTask(_ id: UUID) {
        ongoingDownloads[id]?.cancel()
        cleanupTask(id)
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            let fileURL = documentsDir.appendingPathComponent(tasks[idx].fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        tasks.removeAll { $0.id == id }
        saveTasks()
    }

    func retryTask(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].status = .queued
        tasks[idx].progress = 0
        tasks[idx].downloadedBytes = 0
        tasks[idx].downloadSpeed = 0
        tasks[idx].errorMessage = nil
        tasks[idx].startDate = Date()
        tasks[idx].retryCount += 1
        saveTasks()
        processQueue()
    }

    func retryAllFailed() {
        let failedIds = tasks.filter { $0.status == .failed }.map { $0.id }
        for id in failedIds { retryTask(id) }
    }

    func clearCompleted() {
        let completed = tasks.filter { $0.status == .completed }
        for task in completed {
            let fileURL = documentsDir.appendingPathComponent(task.fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        tasks.removeAll { $0.status == .completed }
        saveTasks()
    }

    func pauseAll() {
        let downloadingIds = tasks.filter { $0.status == .downloading }.map { $0.id }
        for id in downloadingIds { pauseTask(id) }
    }

    func resumeAll() {
        let pausedIds = tasks.filter { $0.status == .paused || $0.status == .queued }.map { $0.id }
        for id in pausedIds { resumeTask(id) }
    }

    private func cleanupTask(_ id: UUID) {
        ongoingDownloads[id] = nil
        progressTimers[id] = nil
        lastBytes[id] = nil
    }

    private func updateTaskStatus(_ id: UUID, status: DownloadStatus) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].status = status
        }
        saveTasks()
    }

    private func updateTaskProgress(_ id: UUID, bytes: Int64) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].downloadedBytes = bytes
            if tasks[idx].fileSize > 0 {
                tasks[idx].progress = min(1.0, Double(bytes) / Double(tasks[idx].fileSize))
            }
        }
        saveTasks()
    }

    private func updateTaskResumeData(_ id: UUID, data: Data?) {
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].resumeData = data
        }
        saveTasks()
    }

    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
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
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let idString = downloadTask.taskDescription,
              let id = UUID(uuidString: idString) else { return }

        var fileName = downloadTask.response?.suggestedFilename ?? "downloaded_file"

        Task { @MainActor in
            if let task = tasks.first(where: { $0.id == id }) {
                fileName = task.fileName
            }

            let destinationURL = documentsDir.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: location, to: destinationURL)

                let actualSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path))?[.size] as? Int64 ?? 0

                if let idx = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[idx].status = .completed
                    tasks[idx].progress = 1.0
                    tasks[idx].downloadedBytes = actualSize
                    tasks[idx].fileSize = actualSize
                    tasks[idx].downloadSpeed = 0
                    tasks[idx].completionDate = Date()
                }
                cleanupTask(id)
                saveTasks()
                processQueue()
                await sendNotification(title: "Download Complete", body: "Finished downloading \(fileName)")
            } catch {
                if let idx = tasks.firstIndex(where: { $0.id == id }) {
                    tasks[idx].status = .failed
                    tasks[idx].errorMessage = error.localizedDescription
                }
                cleanupTask(id)
                saveTasks()
                processQueue()
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let idString = downloadTask.taskDescription,
              let id = UUID(uuidString: idString) else { return }

        Task { @MainActor in
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx].downloadedBytes = totalBytesWritten
                if totalBytesExpectedToWrite > 0 {
                    tasks[idx].fileSize = totalBytesExpectedToWrite
                    tasks[idx].progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                }
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error,
              let idString = task.taskDescription,
              let id = UUID(uuidString: idString) else { return }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        Task { @MainActor in
            if let idx = tasks.firstIndex(where: { $0.id == id }) {
                tasks[idx].status = .failed
                tasks[idx].errorMessage = error.localizedDescription
            }
            cleanupTask(id)
            saveTasks()
            processQueue()
        }
    }
}
