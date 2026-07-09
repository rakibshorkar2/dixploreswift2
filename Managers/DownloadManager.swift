import Foundation
import CryptoKit
import UIKit
import UserNotifications
import Network
import BackgroundTasks

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var queue: [DownloadItem] = []
    @Published private(set) var activeCount: Int = 0
    @Published private(set) var totalStorage: Int64 = 0
    @Published private(set) var freeStorage: Int64 = 0
    @Published private(set) var isSelectionMode: Bool = false
    @Published private(set) var selectedIds: Set<String> = []

    var onAllDownloadsComplete: (() -> Void)?
    var backgroundCompletionHandler: (() -> Void)?

    private var maxConcurrent: Int = 3
    private var isProcessingQueue: Bool = false
    private var lastNotifyTime: Date = .init()
    private var lastSaveTime: Date = .init()
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var taskIdMap: [Int: String] = [:]
    private var resumeDataMap: [String: Data] = [:]
    private var retryWorkItems: [String: DispatchWorkItem] = [:]
    private var speedTracker: [String: (bytes: Int64, time: Date)] = [:]
    private var speedLimiter: [String: Date] = [:]
    private var isBatteryMonitoringEnabled: Bool = false
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid

    private static let backgroundSessionIdentifier = "com.dirxplore.downloads"

    private static func makeBackgroundSessionConfiguration(proxy: ProxyModel? = nil) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.timeoutIntervalForResource = 86400
        config.waitsForConnectivity = true
        if let proxy = proxy {
            var proxyDict: [AnyHashable: Any] = [:]
            switch proxy.protocolType {
            case .http:
                proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesHTTPPort as String] = proxy.port
            case .https:
                proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPSProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesHTTPSPort as String] = proxy.port
            case .socsk5, .socks4:
                proxyDict[kCFNetworkProxiesSOCKSEnable as String] = 1
                proxyDict[kCFNetworkProxiesSOCKSProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesSOCKSPort as String] = proxy.port
            }
            if let user = proxy.username, !user.isEmpty {
                proxyDict[kCFProxyUsernameKey as String] = user
                proxyDict[kCFProxyPasswordKey as String] = proxy.password ?? ""
            }
            config.connectionProxyDictionary = proxyDict
        }
        return config
    }

    private lazy var backgroundSession: URLSession = {
        let config = Self.makeBackgroundSessionConfiguration(proxy: ProxyManager.shared.activeProxy)
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private lazy var foregroundSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 86400
        config.waitsForConnectivity = true
        if let proxy = ProxyManager.shared.activeProxy {
            var proxyDict: [AnyHashable: Any] = [:]
            switch proxy.protocolType {
            case .http:
                proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesHTTPPort as String] = proxy.port
            case .https:
                proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPSProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesHTTPSPort as String] = proxy.port
            case .socsk5, .socks4:
                proxyDict[kCFNetworkProxiesSOCKSEnable as String] = 1
                proxyDict[kCFNetworkProxiesSOCKSProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesSOCKSPort as String] = proxy.port
            }
            if let user = proxy.username, !user.isEmpty {
                proxyDict[kCFProxyUsernameKey as String] = user
                proxyDict[kCFProxyPasswordKey as String] = proxy.password ?? ""
            }
            config.connectionProxyDictionary = proxyDict
        }
        return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }()

    private let wifiMonitor = NWPathMonitor()
    private var isWiFi: Bool = true
    private var hasCellular: Bool = false

    private override init() {
        super.init()
        startWifiMonitoring()
    }

    func refreshSessionsForProxyChange() {
        backgroundSession.invalidateAndCancel()
        let config = Self.makeBackgroundSessionConfiguration(proxy: ProxyManager.shared.activeProxy)
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        let fgConfig = URLSessionConfiguration.default
        fgConfig.timeoutIntervalForResource = 86400
        fgConfig.waitsForConnectivity = true
        if let proxy = ProxyManager.shared.activeProxy {
            var proxyDict: [AnyHashable: Any] = [:]
            switch proxy.protocolType {
            case .http:
                proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesHTTPPort as String] = proxy.port
            case .https:
                proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
                proxyDict[kCFNetworkProxiesHTTPSProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesHTTPSPort as String] = proxy.port
            case .socsk5, .socks4:
                proxyDict[kCFNetworkProxiesSOCKSEnable as String] = 1
                proxyDict[kCFNetworkProxiesSOCKSProxy as String] = proxy.host
                proxyDict[kCFNetworkProxiesSOCKSPort as String] = proxy.port
            }
            if let user = proxy.username, !user.isEmpty {
                proxyDict[kCFProxyUsernameKey as String] = user
                proxyDict[kCFProxyPasswordKey as String] = proxy.password ?? ""
            }
            fgConfig.connectionProxyDictionary = proxyDict
        }
        foregroundSession = URLSession(configuration: fgConfig, delegate: nil, delegateQueue: nil)
    }

    private func isCharging() async -> Bool {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
    }

    func updateScreenAwake() {
        let settings = SettingsManager.shared
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake && queue.contains { $0.status == .downloading }
    }

    private func startWifiMonitoring() {
        wifiMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isWiFi = path.usesInterfaceType(.wifi)
                self.hasCellular = path.usesInterfaceType(.cellular)
                if !self.isWiFi {
                    let settings = SettingsManager.shared
                    if settings.downloadOnWifiOnly {
                        for i in self.queue.indices where self.queue[i].status == .downloading || self.queue[i].status == .queued {
                            if self.queue[i].scheduleType == .wifiOnly || settings.downloadOnWifiOnly {
                                if self.queue[i].status == .downloading {
                                    let id = self.queue[i].id
                                    self.activeTasks[id]?.cancel { resumeData in
                                        if let data = resumeData { self.resumeDataMap[id] = data }
                                    }
                                    self.activeTasks.removeValue(forKey: id)
                                }
                                self.queue[i].status = .paused
                                self.queue[i].errorMessage = "Paused: Waiting for Wi-Fi"
                                self.queue[i].speedBytesPerSec = 0
                                Task { try? await DatabaseService.shared.updateDownload(self.queue[i]) }
                            }
                        }
                        self.activeCount = self.queue.filter { $0.status == .downloading }.count
                        self.syncLiveActivityState()
                        self.objectWillChange.send()
                    }
                } else {
                    self.processQueue()
                }
            }
        }
        wifiMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    private func isWifiConnected() async -> Bool {
        isWiFi
    }

    func load() async {
        if let saved = try? await DatabaseService.shared.getDownloads() {
            queue = saved
            activeCount = 0
            for i in queue.indices {
                if queue[i].status == .downloading {
                    queue[i].status = .queued
                    try? await DatabaseService.shared.updateDownload(queue[i])
                }
            }
        }
        await updateStorageInfo()
        processQueue()
    }

    func updateStorageInfo() async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: docs.path) {
            totalStorage = (attrs[.systemSize] as? Int64) ?? 0
            freeStorage = (attrs[.systemFreeSize] as? Int64) ?? 0
        }
    }

    func setMaxConcurrent(_ max: Int) {
        maxConcurrent = max
        processQueue()
    }

    func addDownload(
        url: String,
        fileName: String,
        saveDir: String,
        batchId: String? = nil,
        batchName: String? = nil,
        originalUrl: String? = nil,
        customHeaders: [String: String] = [:],
        mirrorUrls: [String] = [],
        category: DownloadCategory? = nil,
        scheduleType: ScheduleType = .immediate,
        scheduledAt: Date? = nil,
        maxRetries: Int? = nil,
        expectedMd5: String? = nil,
        expectedSha1: String? = nil,
        expectedSha256: String? = nil,
        redirectCount: Int = 0,
        resolvedUrl: String? = nil
    ) async {
        if let existing = queue.first(where: { $0.url == url }) {
            if existing.status == .paused || existing.status == .error {
                await resume(existing.id)
            }
            return
        }

        let id = "\(Int64(Date().timeIntervalSince1970 * 1000))_\(abs(url.hashValue))"
        let settings = SettingsManager.shared
        let autoCat = settings.autoCategorizeEnabled
        let smartRouting = settings.smartFolderRouting
        let cat = category ?? (autoCat ? DownloadCategory.from(fileName: fileName) : .other)

        var finalSaveDir = saveDir
        if smartRouting {
            let subDir: String
            switch cat {
            case .movies: subDir = "Movies"
            case .tvShows: subDir = "TV Shows"
            case .music: subDir = "Music"
            case .images: subDir = "Images"
            case .documents: subDir = "Documents"
            case .archives: subDir = "Archives"
            case .apps: subDir = "Apps"
            case .other: subDir = "Others"
            }
            finalSaveDir = (finalSaveDir as NSString).appendingPathComponent(subDir)
        }
        if let batch = batchName, !batch.trimmingCharacters(in: .whitespaces).isEmpty {
            finalSaveDir = (finalSaveDir as NSString).appendingPathComponent(batch.trimmingCharacters(in: .whitespaces))
        }

        let savePath = (finalSaveDir as NSString).appendingPathComponent(fileName)
        let itemMaxRetries = maxRetries ?? settings.retryCount

        let item = DownloadItem(
            id: id, url: url, fileName: fileName, savePath: savePath,
            batchId: batchId, batchName: batchName, status: .queued,
            maxRetries: itemMaxRetries, originalUrl: originalUrl,
            customHeaders: customHeaders, mirrorUrls: mirrorUrls,
            category: cat, scheduleType: scheduleType, scheduledAt: scheduledAt,
            expectedMd5: expectedMd5, expectedSha1: expectedSha1,
            expectedSha256: expectedSha256, redirectCount: redirectCount,
            resolvedUrl: resolvedUrl
        )

        queue.append(item)
        try? await DatabaseService.shared.insertDownload(item)
        await updateStorageInfo()
        processQueue()
    }

    // MARK: - Process Queue

    private func processQueue() {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true

        Task {
            defer { isProcessingQueue = false }
            let settings = SettingsManager.shared

            while activeCount < maxConcurrent {
                let now = Date()
                guard let nextIdx = queue.firstIndex(where: { item in
                    item.status == .queued &&
                    (item.scheduleType != .scheduled || (item.scheduledAt.map { $0 < now } ?? false))
                }) else { break }

                if settings.downloadOnWifiOnly || queue[nextIdx].scheduleType == .wifiOnly {
                    guard await isWifiConnected() else {
                        queue[nextIdx].status = .paused
                        queue[nextIdx].errorMessage = "Paused: Waiting for Wi-Fi"
                        try? await DatabaseService.shared.updateDownload(queue[nextIdx])
                        continue
                    }
                }

                if settings.pauseLowBattery {
                    let level = await getBatteryLevel()
                    if level < 0.15 {
                        queue[nextIdx].status = .paused
                        queue[nextIdx].errorMessage = "Paused: Low battery (\(Int(level * 100))%)"
                        try? await DatabaseService.shared.updateDownload(queue[nextIdx])
                        continue
                    }
                }

                if queue[nextIdx].scheduleType == .chargingOnly || settings.schedulerChargingOnly {
                    if !(await isCharging()) {
                        queue[nextIdx].status = .paused
                        queue[nextIdx].errorMessage = "Paused: Waiting for charger"
                        try? await DatabaseService.shared.updateDownload(queue[nextIdx])
                        continue
                    }
                }

                startDownload(at: nextIdx)
            }
            syncLiveActivityState()
        }
    }

    private func getBatteryLevel() async -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? level : 1.0
    }

    // MARK: - Start Download

    private func startDownload(at index: Int) {
        guard index < queue.count else { return }
        activeCount += 1
        queue[index].status = .downloading
        updateScreenAwake()
        objectWillChange.send()

        Task { try? await DatabaseService.shared.updateDownload(queue[index]) }

        let item = queue[index]
        let dir = (item.savePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        guard let url = URL(string: item.url) else {
            queue[index].status = .error
            queue[index].errorMessage = "Invalid URL"
            activeCount -= 1
            objectWillChange.send()
            return
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        for (key, value) in item.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if item.downloadedBytes > 0 {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: item.savePath)[.size] as? Int64) ?? 0
            if fileSize > 0 {
                queue[index].downloadedBytes = fileSize
            }
            if let resumeData = resumeDataMap[item.id] {
                let task = backgroundSession.downloadTask(withResumeData: resumeData)
                activeTasks[item.id] = task
                taskIdMap[task.taskIdentifier] = item.id
                task.resume()
                showDownloadNotification(title: "Download Started", body: item.fileName)
                return
            }
            if queue[index].downloadedBytes > 0 {
                request.setValue("bytes=\(queue[index].downloadedBytes)-", forHTTPHeaderField: "Range")
            }
        }

        let task = backgroundSession.downloadTask(with: request)
        activeTasks[item.id] = task
        taskIdMap[task.taskIdentifier] = item.id
        task.resume()
        speedTracker[item.id] = (0, Date())
        showDownloadNotification(title: "Download Started", body: item.fileName)
    }

    // MARK: - Pause / Resume / Stop

    func pause(_ id: String) async {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }

        if queue[idx].status == .downloading, let task = activeTasks[id] {
            task.cancel { [weak self] resumeData in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if let data = resumeData { self.resumeDataMap[id] = data }
                    let taskId = task.taskIdentifier
                    self.activeTasks.removeValue(forKey: id)
                    self.taskIdMap.removeValue(forKey: taskId)
                    self.queue[idx].status = .paused
                    self.queue[idx].speedBytesPerSec = 0
                    if self.activeCount > 0 { self.activeCount -= 1 }
                    try? await DatabaseService.shared.updateDownload(self.queue[idx])
                    self.processQueue()
                    self.syncLiveActivityState()
                    self.objectWillChange.send()
                }
            }
        } else {
            queue[idx].status = .paused
            queue[idx].speedBytesPerSec = 0
            try? await DatabaseService.shared.updateDownload(queue[idx])
            objectWillChange.send()
        }
    }

    func resume(_ id: String) async {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[idx].status = .queued
        queue[idx].errorMessage = nil
        try? await DatabaseService.shared.updateDownload(queue[idx])
        objectWillChange.send()
        processQueue()
        syncLiveActivityState()
    }

    func stop(_ id: String) async {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        if queue[idx].status == .downloading, let task = activeTasks[id] {
            let taskId = task.taskIdentifier
            task.cancel()
            activeTasks.removeValue(forKey: id)
            taskIdMap.removeValue(forKey: taskId)
        }
        retryWorkItems[id]?.cancel()
        retryWorkItems.removeValue(forKey: id)
        resumeDataMap.removeValue(forKey: id)
        speedTracker.removeValue(forKey: id)
        queue.remove(at: idx)
        try? await DatabaseService.shared.deleteDownload(id)
        if activeCount > 0 { activeCount -= 1 }
        objectWillChange.send()
        syncLiveActivityState()
    }

    // MARK: - Batch Operations

    func pauseBatch(_ batchId: String) async {
        for i in queue.indices where queue[i].batchId == batchId {
            if queue[i].status == .downloading {
                if let task = activeTasks[queue[i].id] {
                    let taskId = task.taskIdentifier
                    task.cancel()
                    activeTasks.removeValue(forKey: queue[i].id)
                    taskIdMap.removeValue(forKey: taskId)
                }
                queue[i].status = .paused
                queue[i].speedBytesPerSec = 0
            } else if queue[i].status == .queued {
                queue[i].status = .paused
            }
            try? await DatabaseService.shared.updateDownload(queue[i])
        }
        objectWillChange.send()
        syncLiveActivityState()
    }

    func resumeBatch(_ batchId: String) async {
        var hasResumed = false
        for i in queue.indices where queue[i].batchId == batchId {
            if queue[i].status == .paused || queue[i].status == .error {
                queue[i].status = .queued
                queue[i].errorMessage = nil
                try? await DatabaseService.shared.updateDownload(queue[i])
                hasResumed = true
            }
        }
        if hasResumed {
            objectWillChange.send()
            processQueue()
            syncLiveActivityState()
        }
    }

    func stopBatch(_ batchId: String) async {
        let ids = queue.filter { $0.batchId == batchId }.map { $0.id }
        for id in ids {
            if let task = activeTasks[id] {
                let taskId = task.taskIdentifier
                task.cancel()
                activeTasks.removeValue(forKey: id)
                taskIdMap.removeValue(forKey: taskId)
            }
            retryWorkItems[id]?.cancel()
            retryWorkItems.removeValue(forKey: id)
            resumeDataMap.removeValue(forKey: id)
            speedTracker.removeValue(forKey: id)
            try? await DatabaseService.shared.deleteDownload(id)
        }
        queue.removeAll { $0.batchId == batchId }
        activeCount = queue.filter { $0.status == .downloading }.count
        objectWillChange.send()
        syncLiveActivityState()
    }

    func pauseAll() async {
        for (id, task) in activeTasks {
            let taskId = task.taskIdentifier
            task.cancel { [weak self] resumeData in
                Task { @MainActor [weak self] in
                    if let data = resumeData { self?.resumeDataMap[id] = data }
                }
            }
            activeTasks.removeValue(forKey: id)
            taskIdMap.removeValue(forKey: taskId)
        }
        for i in queue.indices {
            if queue[i].status == .queued || queue[i].status == .downloading {
                queue[i].status = .paused
                queue[i].speedBytesPerSec = 0
                try? await DatabaseService.shared.updateDownload(queue[i])
            }
        }
        activeCount = 0
        objectWillChange.send()
        syncLiveActivityState()
    }

    func resumeAll() async {
        for i in queue.indices {
            if queue[i].status == .paused || queue[i].status == .error {
                queue[i].status = .queued
                queue[i].errorMessage = nil
                try? await DatabaseService.shared.updateDownload(queue[i])
            }
        }
        objectWillChange.send()
        processQueue()
    }

    func clearDone() async {
        let doneIds = queue.filter { $0.status == .done || $0.status == .error }.map { $0.id }
        guard !doneIds.isEmpty else { return }
        for id in doneIds {
            try? await DatabaseService.shared.deleteDownload(id)
        }
        queue.removeAll { $0.status == .done || $0.status == .error }
        await updateStorageInfo()
        objectWillChange.send()
    }

    func clearAll() async {
        for (_, task) in activeTasks {
            let taskId = task.taskIdentifier
            task.cancel()
            taskIdMap.removeValue(forKey: taskId)
        }
        activeTasks.removeAll()
        retryWorkItems.values.forEach { $0.cancel() }
        retryWorkItems.removeAll()
        resumeDataMap.removeAll()
        speedTracker.removeAll()
        queue.removeAll()
        activeCount = 0
        isSelectionMode = false
        selectedIds.removeAll()
        try? await DatabaseService.shared.deleteAll()
        await updateStorageInfo()
        objectWillChange.send()
    }

    // MARK: - Link Refresh

    func refreshLink(_ id: String, newUrl: String) async -> Bool {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return false }
        let originalUrl = queue[idx].originalUrl ?? queue[idx].url

        if queue[idx].status == .downloading {
            if let task = activeTasks[id] {
                let taskId = task.taskIdentifier
                task.cancel()
                activeTasks.removeValue(forKey: id)
                taskIdMap.removeValue(forKey: taskId)
            }
        }

        guard let resolved = URL(string: newUrl) else {
            queue[idx].errorMessage = "Invalid URL"
            queue[idx].status = .error
            try? await DatabaseService.shared.updateDownload(queue[idx])
            return false
        }

        var headReq = URLRequest(url: resolved)
        headReq.httpMethod = "HEAD"
        headReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await foregroundSession.data(for: headReq)
            guard let httpResp = response as? HTTPURLResponse else {
                queue[idx].errorMessage = "Invalid response"
                queue[idx].status = .error
                try? await DatabaseService.shared.updateDownload(queue[idx])
                return false
            }

            let total = httpResp.expectedContentLength
            let acceptRanges = (httpResp.allHeaderFields["Accept-Ranges"] as? String ?? "").lowercased()
            let resumeSupported = acceptRanges == "bytes"

            queue[idx].url = resolved.absoluteString
            queue[idx].originalUrl = originalUrl
            queue[idx].totalBytes = max(total, 0)
            queue[idx].retryCount = 0

            if resumeSupported && queue[idx].downloadedBytes > 0 && total > 0 && queue[idx].downloadedBytes < total {
                queue[idx].errorMessage = nil
                queue[idx].status = .queued
            } else if queue[idx].downloadedBytes > 0 {
                queue[idx].downloadedBytes = 0
                queue[idx].errorMessage = "Server does not support resume. Download will restart."
                queue[idx].status = .queued
            } else {
                queue[idx].errorMessage = nil
                queue[idx].status = .queued
            }
            try? await DatabaseService.shared.updateDownload(queue[idx])
            processQueue()
            return true
        } catch {
            queue[idx].errorMessage = "Invalid or expired link: \(error.localizedDescription)"
            queue[idx].status = .error
            try? await DatabaseService.shared.updateDownload(queue[idx])
            return false
        }
    }

    // MARK: - Mirror URL Switch

    func switchToMirror(_ id: String) async -> Bool {
        guard let idx = queue.firstIndex(where: { $0.id == id }), !queue[idx].mirrorUrls.isEmpty else { return false }

        if queue[idx].status == .downloading {
            if let task = activeTasks[id] {
                let taskId = task.taskIdentifier
                task.cancel()
                activeTasks.removeValue(forKey: id)
                taskIdMap.removeValue(forKey: taskId)
            }
        }

        for mirrorUrl in queue[idx].mirrorUrls where mirrorUrl != queue[idx].url {
            guard URL(string: mirrorUrl) != nil else { continue }
            queue[idx].url = mirrorUrl
            queue[idx].retryCount = 0
            queue[idx].errorMessage = nil
            queue[idx].status = .queued
            try? await DatabaseService.shared.updateDownload(queue[idx])
            processQueue()
            return true
        }

        queue[idx].errorMessage = "All mirrors failed"
        queue[idx].status = .error
        try? await DatabaseService.shared.updateDownload(queue[idx])
        return false
    }

    // MARK: - Retry Logic

    private func handleDownloadError(_ id: String, error: Error) {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }

        let nsError = error as NSError
        var permanent = false
        var message: String?

        switch nsError.code {
        case NSURLErrorUserAuthenticationRequired:
            message = "Authentication required. The link may need valid credentials."
            permanent = true
        case 404, NSURLErrorFileDoesNotExist:
            message = "File not found. The link may have expired."
            permanent = true
        case 410:
            message = "This download link has expired."
            permanent = true
        case 403:
            message = "Access denied. The link may have expired."
            permanent = true
        case NSURLErrorTimedOut:
            message = "Connection timed out. Retrying..."
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            message = "Connection lost. Retrying..."
        case 429:
            message = "Too many requests. Retrying..."
        case 500:
            message = "Server error. Retrying..."
        case 503:
            message = "Server unavailable. Retrying..."
        default:
            message = nsError.localizedDescription
        }

        queue[idx].errorMessage = message

        if permanent {
            queue[idx].status = .error
            queue[idx].speedBytesPerSec = 0
            showDownloadNotification(title: "Download Failed", body: queue[idx].fileName)
        } else if queue[idx].retryCount < queue[idx].maxRetries {
            queue[idx].retryCount += 1
            queue[idx].status = .queued
            let delay = SettingsManager.shared.retryDelaySeconds
            let actualDelay = max(TimeInterval(delay), pow(2.0, Double(queue[idx].retryCount - 1)))
            let workItem = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if !self.queue[idx].mirrorUrls.isEmpty && self.queue[idx].retryCount > 1 {
                        _ = await self.switchToMirror(id)
                    }
                    self.processQueue()
                }
            }
            retryWorkItems[id] = workItem
            DispatchQueue.global().asyncAfter(deadline: .now() + actualDelay, execute: workItem)
        } else {
            if !queue[idx].mirrorUrls.isEmpty {
                Task { _ = await switchToMirror(id) }
                return
            }
            queue[idx].status = .error
            if !(queue[idx].errorMessage?.contains("Retrying") ?? false) {
                queue[idx].errorMessage = error.localizedDescription
            }
            showDownloadNotification(title: "Download Failed", body: queue[idx].fileName)
        }

        try? await DatabaseService.shared.updateDownload(queue[idx])
        objectWillChange.send()
    }

    // MARK: - File Hash Verification using CryptoKit

    func verifyFileHash(filePath: String, expectedHash: String) async -> Bool {
        let hash = expectedHash.trimmingCharacters(in: .whitespaces).lowercased()
        guard !hash.isEmpty, FileManager.default.fileExists(atPath: filePath) else { return false }
        do {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let calculated: String
            switch hash.count {
            case 32: calculated = Insecure.MD5.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            case 40: calculated = Insecure.SHA1.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            default: calculated = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            }
            return calculated == hash
        } catch { return false }
    }

    func computeChecksum(filePath: String, algorithm: String) async -> String? {
        guard FileManager.default.fileExists(atPath: filePath) else { return nil }
        do {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            switch algorithm.lowercased() {
            case "md5": return Insecure.MD5.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            case "sha1": return Insecure.SHA1.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            case "sha256": return SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            default: return nil
            }
        } catch { return nil }
    }

    func verifyDownloadChecksums(_ id: String) async {
        guard let idx = queue.firstIndex(where: { $0.id == id }),
              FileManager.default.fileExists(atPath: queue[idx].savePath) else { return }
        if queue[idx].expectedMd5 != nil {
            queue[idx].calculatedMd5 = await computeChecksum(filePath: queue[idx].savePath, algorithm: "md5")
        }
        if queue[idx].expectedSha1 != nil {
            queue[idx].calculatedSha1 = await computeChecksum(filePath: queue[idx].savePath, algorithm: "sha1")
        }
        if queue[idx].expectedSha256 != nil {
            queue[idx].calculatedSha256 = await computeChecksum(filePath: queue[idx].savePath, algorithm: "sha256")
        }
        try? await DatabaseService.shared.updateDownload(queue[idx])
        objectWillChange.send()
    }

    // MARK: - Export / Import Queue

    func exportQueueJson() -> String? {
        let dicts = queue.map { $0.toDictionary() }
        return (try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    func importQueueFromJson(_ json: String) async -> Int {
        guard let data = json.data(using: .utf8),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return 0 }
        var count = 0
        for dict in list {
            let item = DownloadItem(from: dict)
            guard !queue.contains(where: { $0.url == item.url }) else { continue }
            var imported = item
            if imported.status == .downloading || imported.status == .queued {
                imported.status = .paused
                imported.speedBytesPerSec = 0
            }
            queue.append(imported)
            try? await DatabaseService.shared.insertDownload(imported)
            count += 1
        }
        if count > 0 {
            objectWillChange.send()
            processQueue()
        }
        return count
    }

    // MARK: - Batch URL Import

    func batchAddDownloads(urlsText: String, saveDir: String) async -> (valid: Int, invalid: Int) {
        let lines = urlsText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var valid = 0, invalid = 0
        for line in lines {
            guard let url = URL(string: line),
                  url.scheme != nil, url.host != nil,
                  url.scheme == "http" || url.scheme == "https" else {
                invalid += 1; continue
            }
            let fileName = line.components(separatedBy: "/").last?
                .components(separatedBy: "?").first
                ?? "download_\(Int64(Date().timeIntervalSince1970 * 1000))"
            await addDownload(url: line, fileName: fileName, saveDir: saveDir)
            valid += 1
        }
        return (valid, invalid)
    }

    // MARK: - Crawl Folder

    private var crawlCache: [String: [DirectoryItem]] = [:]

    func crawlFolder(folderUrl: String) async -> [DirectoryItem] {
        if let cached = crawlCache[folderUrl] { return cached }
        var results: [DirectoryItem] = []
        await crawlRecursive(folderUrl: folderUrl, results: &results)
        crawlCache[folderUrl] = results
        return results
    }

    private func crawlRecursive(folderUrl: String, results: inout [DirectoryItem]) async {
        guard let url = URL(string: folderUrl) else { return }
        do {
            let (data, _) = try await foregroundSession.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return }
            let items = await HTMLParserService.parseApacheDirectoryAsync(html: html, baseUrl: folderUrl)
            for item in items {
                if item.isDirectory {
                    await crawlRecursive(folderUrl: item.url, results: &results)
                } else {
                    results.append(item)
                }
            }
        } catch {}
    }

    func addRecursiveDownload(folderUrl: String, folderName: String, baseSaveDir: String) async {
        let items = await crawlFolder(folderUrl: folderUrl)
        let batchId = "\(Int64(Date().timeIntervalSince1970 * 1000))"
        let videoExts = ["mp4", "mkv", "avi", "mov", "webm", "srt", "vtt", "sub"]
        for item in items where videoExts.contains((item.name as NSString).pathExtension.lowercased()) {
            await addDownload(url: item.url, fileName: item.name, saveDir: baseSaveDir, batchId: batchId, batchName: folderName)
        }
    }

    // MARK: - Selection

    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode { selectedIds.removeAll() }
        objectWillChange.send()
    }

    func toggleSelection(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
            if selectedIds.isEmpty { isSelectionMode = false }
        } else {
            selectedIds.insert(id)
            isSelectionMode = true
        }
        objectWillChange.send()
    }

    func selectAll() {
        selectedIds = Set(queue.map { $0.id })
        isSelectionMode = true
        objectWillChange.send()
    }

    func clearSelection() {
        selectedIds.removeAll()
        isSelectionMode = false
        objectWillChange.send()
    }

    func deleteSelected(deleteFiles: Bool = false) async {
        for id in selectedIds {
            if let task = activeTasks[id] {
                let taskId = task.taskIdentifier
                task.cancel()
                activeTasks.removeValue(forKey: id)
                taskIdMap.removeValue(forKey: taskId)
            }
            retryWorkItems[id]?.cancel()
            retryWorkItems.removeValue(forKey: id)
            resumeDataMap.removeValue(forKey: id)
            speedTracker.removeValue(forKey: id)
            if deleteFiles, let item = queue.first(where: { $0.id == id }) {
                try? FileManager.default.removeItem(atPath: item.savePath)
            }
            try? await DatabaseService.shared.deleteDownload(id)
        }
        queue.removeAll { selectedIds.contains($0.id) }
        activeCount = queue.filter { $0.status == .downloading }.count
        selectedIds.removeAll()
        isSelectionMode = false
        await updateStorageInfo()
        processQueue()
        objectWillChange.send()
    }

    // MARK: - Auto-categorize

    func autoCategorizeItem(_ id: String) {
        guard let idx = queue.firstIndex(where: { $0.id == id }), queue[idx].category == .other else { return }
        queue[idx].category = DownloadCategory.from(fileName: queue[idx].fileName)
    }

    // MARK: - Progress

    private func updateProgress(id: String, downloadedBytes: Int64, totalBytes: Int64) async {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        let tracker = speedTracker[id] ?? (0, now)
        let elapsed = now.timeIntervalSince(tracker.time)
        if elapsed > 0 {
            let bytesDiff = downloadedBytes - tracker.bytes
            var currentSpeed = Double(bytesDiff) / elapsed
            let speedCap = SettingsManager.shared.speedLimitCap
            if speedCap > 0 {
                let capBytes = Double(speedCap) * 1024.0 * 1024.0 / 8.0
                if currentSpeed > capBytes {
                    let sleepTime = (currentSpeed - capBytes) / currentSpeed * elapsed
                    if sleepTime > 0.001 {
                        try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                    }
                    currentSpeed = capBytes
                }
            }
            if queue[idx].speedBytesPerSec == 0 {
                queue[idx].speedBytesPerSec = currentSpeed
            } else {
                queue[idx].speedBytesPerSec = (queue[idx].speedBytesPerSec * 0.7) + (currentSpeed * 0.3)
            }
        }
        speedTracker[id] = (downloadedBytes, now)
        queue[idx].downloadedBytes = downloadedBytes
        queue[idx].totalBytes = totalBytes

        if queue[idx].speedBytesPerSec > 0 && totalBytes > 0 {
            queue[idx].etaSeconds = Int(Double(totalBytes - downloadedBytes) / queue[idx].speedBytesPerSec)
        }

        if now.timeIntervalSince(lastNotifyTime) > 0.25 {
            lastNotifyTime = now
            objectWillChange.send()
        }
        if now.timeIntervalSince(lastSaveTime) > 5 {
            lastSaveTime = now
            try? await DatabaseService.shared.updateDownload(queue[idx])
        }
    }

    private func showDownloadNotification(title: String, body: String) {
        guard SettingsManager.shared.showDownloadNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "DOWNLOAD_ACTION"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    static func registerNotificationCategories() {
        let pauseAction = UNNotificationAction(identifier: "PAUSE", title: "Pause", options: [])
        let resumeAction = UNNotificationAction(identifier: "RESUME", title: "Resume", options: [])
        let cancelAction = UNNotificationAction(identifier: "CANCEL", title: "Cancel", options: [.destructive])
        let category = UNNotificationCategory(
            identifier: "DOWNLOAD_ACTION",
            actions: [pauseAction, resumeAction, cancelAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private func syncLiveActivityState() {
        let activeDownloads = queue.filter { $0.status == .downloading }
        if activeDownloads.isEmpty {
            onAllDownloadsComplete?()
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskId = downloadTask.taskIdentifier
        guard let id = taskIdMap[taskId] else { return }
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : totalBytesWritten
        Task { @MainActor in
            updateProgress(id: id, downloadedBytes: totalBytesWritten, totalBytes: total)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskId = downloadTask.taskIdentifier
        guard let id = taskIdMap[taskId] else { return }
        Task { @MainActor [weak self] in
            guard let self = self, let idx = self.queue.firstIndex(where: { $0.id == id }) else { return }
            let destURL = URL(fileURLWithPath: self.queue[idx].savePath)
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.moveItem(at: location, to: destURL)
                self.queue[idx].savePath = destURL.path
            } catch {
                self.queue[idx].errorMessage = "Failed to move file: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let taskId = task.taskIdentifier
        guard let id = taskIdMap[taskId] else { return }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.activeTasks.removeValue(forKey: id)
            self.taskIdMap.removeValue(forKey: taskId)
            self.speedTracker.removeValue(forKey: id)

            guard let idx = self.queue.firstIndex(where: { $0.id == id }) else { return }

            if let error = error {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain,
                   let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    self.resumeDataMap[id] = resumeData
                    self.queue[idx].status = .paused
                    self.queue[idx].speedBytesPerSec = 0
                    if self.activeCount > 0 { self.activeCount -= 1 }
                    try? await DatabaseService.shared.updateDownload(self.queue[idx])
                    self.processQueue()
                    self.syncLiveActivityState()
                    return
                }
                if nsError.code == NSURLErrorCancelled { return }
                self.handleDownloadError(id, error: error)
            } else {
                self.queue[idx].status = .done
                self.queue[idx].speedBytesPerSec = 0
                self.queue[idx].etaSeconds = 0
                self.queue[idx].downloadedBytes = self.queue[idx].totalBytes
                self.autoCategorizeItem(id)
                if self.activeCount > 0 { self.activeCount -= 1 }
                try? await DatabaseService.shared.updateDownload(self.queue[idx])
                await self.updateStorageInfo()
                self.updateScreenAwake()
                self.showDownloadNotification(title: "Download Complete", body: self.queue[idx].fileName)
                self.processQueue()
                self.syncLiveActivityState()
            }

            self.resumeDataMap.removeValue(forKey: id)
            self.retryWorkItems[id]?.cancel()
            self.retryWorkItems.removeValue(forKey: id)
            self.objectWillChange.send()
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - BGTaskScheduler Registration

extension DownloadManager {
    static let bgTaskIdentifier = "com.dirxplore.downloads.autoResume"

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.bgTaskIdentifier, using: nil) { [weak self] task in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.handleBackgroundTask(task as! BGProcessingTask)
            }
        }
    }

    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: Self.bgTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.shared.error("Failed to schedule background task: \(error.localizedDescription)")
        }
    }

    private func handleBackgroundTask(_ task: BGProcessingTask) {
        scheduleBackgroundTask()

        let settings = SettingsManager.shared
        if settings.enableScheduler {
            for i in queue.indices {
                if queue[i].status == .paused || queue[i].status == .error {
                    queue[i].status = .queued
                    queue[i].errorMessage = nil
                    Task { try? await DatabaseService.shared.updateDownload(queue[i]) }
                }
            }
            processQueue()
        }

        task.setTaskCompleted(success: true)
    }
}
