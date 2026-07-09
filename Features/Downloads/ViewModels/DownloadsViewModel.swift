import SwiftUI
import Combine
import CryptoKit
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class DownloadsViewModel: ObservableObject {
    @Published var queue: [DownloadItem] = []
    @Published var isSelectionMode: Bool = false
    @Published var selectedIds: Set<String> = []
    @Published var totalStorage: Int64 = 0
    @Published var freeStorage: Int64 = 0
    @Published var expandedBatchIds: Set<String> = []

    var groupedByBatch: [String?: [DownloadItem]] {
        Dictionary(grouping: queue) { $0.batchId }
    }

    var sortedBatchIds: [String?] {
        groupedByBatch.keys.sorted { a, b in
            switch (a, b) {
            case (nil, _): return true
            case (_, nil): return false
            case let (lhs?, rhs?): return lhs < rhs
            }
        }
    }

    var activeDownloadCount: Int {
        queue.filter { $0.status == .downloading }.count
    }

    var onAllDownloadsComplete: (() -> Void)?

    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var resumeDataMap: [String: Data] = [:]
    private var retryWorkItems: [String: DispatchWorkItem] = [:]
    private var speedTracker: [String: (bytes: Int64, time: Date)] = [:]
    private var isProcessingQueue = false
    private var lastNotifyTime = Date()
    private var lastSaveTime = Date()
    private var activeCount = 0
    private let maxConcurrent = 3

    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.dirxplore.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.shouldUseExtendedBackgroundIdleMode = true
        config.timeoutIntervalForResource = 86400
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: SessionDelegate(parent: self), delegateQueue: nil)
    }()

    private lazy var foregroundSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 86400
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    func initManager() {
        Task {
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
    }

    func updateStorageInfo() {
        Task {
            guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: docs.path) {
                totalStorage = (attrs[.systemSize] as? Int64) ?? 0
                freeStorage = (attrs[.systemFreeSize] as? Int64) ?? 0
            }
        }
    }

    func addDownload(
        url: String, fileName: String, saveDir: String,
        batchId: String? = nil, batchName: String? = nil,
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
    ) {
        if let existing = queue.first(where: { $0.url == url }) {
            if existing.status == .paused || existing.status == .error {
                resume(existing.id)
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
        Task { try? await DatabaseService.shared.insertDownload(item) }
        updateStorageInfo()
        processQueue()
    }

    func pause(_ id: String) {
        Task {
            guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }

            if queue[idx].status == .downloading, let task = activeTasks[id] {
                task.cancel { [weak self] resumeData in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if let data = resumeData { self.resumeDataMap[id] = data }
                        self.activeTasks.removeValue(forKey: id)
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
    }

    func resume(_ id: String) {
        Task {
            guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
            queue[idx].status = .queued
            queue[idx].errorMessage = nil
            try? await DatabaseService.shared.updateDownload(queue[idx])
            objectWillChange.send()
            processQueue()
            syncLiveActivityState()
        }
    }

    func stop(_ id: String) {
        Task {
            guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
            if queue[idx].status == .downloading, let task = activeTasks[id] {
                task.cancel()
                activeTasks.removeValue(forKey: id)
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
    }

    func pauseAll() {
        Task {
            for (id, task) in activeTasks {
                task.cancel { [weak self] resumeData in
                    Task { @MainActor [weak self] in
                        if let data = resumeData { self?.resumeDataMap[id] = data }
                    }
                }
            }
            activeTasks.removeAll()
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
    }

    func resumeAll() {
        Task {
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
    }

    func clearDone() {
        queue.removeAll { $0.status == .done || $0.status == .error }
        Task {
            try? await DatabaseService.shared.deleteAllDownloads()
            for item in queue {
                try? await DatabaseService.shared.insertDownload(item)
            }
            await updateStorageInfo()
        }
        objectWillChange.send()
    }

    func clearAll() {
        for (_, task) in activeTasks { task.cancel() }
        activeTasks.removeAll()
        retryWorkItems.values.forEach { $0.cancel() }
        retryWorkItems.removeAll()
        resumeDataMap.removeAll()
        speedTracker.removeAll()
        queue.removeAll()
        activeCount = 0
        isSelectionMode = false
        selectedIds.removeAll()
        Task {
            try? await DatabaseService.shared.deleteAll()
            await updateStorageInfo()
        }
        objectWillChange.send()
    }

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

    func deleteSelected(deleteFiles: Bool) {
        Task {
            for id in selectedIds {
                activeTasks[id]?.cancel()
                activeTasks.removeValue(forKey: id)
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
    }

    func resumeBatch(_ batchId: String) {
        Task {
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
    }

    func pauseBatch(_ batchId: String) {
        Task {
            for i in queue.indices where queue[i].batchId == batchId {
                if queue[i].status == .downloading {
                    activeTasks[queue[i].id]?.cancel()
                    activeTasks.removeValue(forKey: queue[i].id)
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
    }

    func stopBatch(_ batchId: String) {
        Task {
            let ids = queue.filter { $0.batchId == batchId }.map { $0.id }
            for id in ids {
                activeTasks[id]?.cancel()
                activeTasks.removeValue(forKey: id)
                retryWorkItems[id]?.cancel()
                retryWorkItems.removeValue(forKey: id)
                resumeDataMap.removeValue(forKey: id)
                speedTracker.removeValue(forKey: id)
                try? await DatabaseService.shared.deleteDownload(id)
            }
            queue.removeAll { $0.batchId == batchId }
            activeCount = queue.filter { $0.status == .downloading }.count
            updateStorageInfo()
            objectWillChange.send()
            syncLiveActivityState()
        }
    }

    func refreshLink(_ id: String, newUrl: String) async -> Bool {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return false }
        let originalUrl = queue[idx].originalUrl ?? queue[idx].url

        if queue[idx].status == .downloading {
            activeTasks[id]?.cancel()
            activeTasks.removeValue(forKey: id)
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

    func switchToMirror(_ id: String) async -> Bool {
        guard let idx = queue.firstIndex(where: { $0.id == id }), !queue[idx].mirrorUrls.isEmpty else { return false }

        if queue[idx].status == .downloading {
            activeTasks[id]?.cancel()
            activeTasks.removeValue(forKey: id)
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

    func verifyFileHash(_ path: String, _ expected: String) async -> Bool {
        let hash = expected.trimmingCharacters(in: .whitespaces).lowercased()
        guard !hash.isEmpty, FileManager.default.fileExists(atPath: path) else { return false }
        do {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
            let calculated: String
            switch hash.count {
            case 32: calculated = Insecure.MD5.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            case 40: calculated = Insecure.SHA1.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            default: calculated = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
            }
            return calculated == hash
        } catch { return false }
    }

    func computeChecksum(_ path: String, _ algorithm: String) async -> String? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        do {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
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
            queue[idx].calculatedMd5 = await computeChecksum(queue[idx].savePath, "md5")
        }
        if queue[idx].expectedSha1 != nil {
            queue[idx].calculatedSha1 = await computeChecksum(queue[idx].savePath, "sha1")
        }
        if queue[idx].expectedSha256 != nil {
            queue[idx].calculatedSha256 = await computeChecksum(queue[idx].savePath, "sha256")
        }
        try? await DatabaseService.shared.updateDownload(queue[idx])
        objectWillChange.send()
    }

    func exportQueue() {
        Task {
            let dicts = queue.map { $0.toDictionary() }
            guard let data = try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted, .sortedKeys]),
                  let json = String(data: data, encoding: .utf8) else { return }

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("dirxplore_queue_backup.json")
            try? json.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    func importQueue() {
        Task {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(picker, animated: true)
                picker.delegate = ImportQueueDelegate { [weak self] json in
                    Task { @MainActor [weak self] in
                        _ = await self?.importQueueFromJson(json)
                    }
                }
            }
        }
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
            addDownload(url: line, fileName: fileName, saveDir: saveDir)
            valid += 1
        }
        return (valid, invalid)
    }

    func crawlFolder(folderUrl: String) async -> [DirectoryItem] {
        var results: [DirectoryItem] = []
        await crawlRecursive(folderUrl: folderUrl, results: &results)
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

    func revealFile(_ path: String) {
        let url = URL(fileURLWithPath: path)
        #if canImport(UIKit)
        UISceneConfiguration()
        #endif
    }

    func saveToFiles(_ path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
    }

    // MARK: - Private

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

                startDownload(at: nextIdx)
            }
            syncLiveActivityState()
        }
    }

    private func isWifiConnected() async -> Bool {
        true
    }

    private func startDownload(at index: Int) {
        guard index < queue.count else { return }
        activeCount += 1
        queue[index].status = .downloading
        objectWillChange.send()

        Task { try? await DatabaseService.shared.updateDownload(queue[index]) }

        let item = queue[index]
        let dir = (item.savePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        guard let requestUrl = URL(string: item.url) else { return }
        var request = URLRequest(url: requestUrl)
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
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
                task.resume()
                showNotification(title: "Download Started", body: item.fileName)
                return
            }
            if queue[index].downloadedBytes > 0 {
                request.setValue("bytes=\(queue[index].downloadedBytes)-", forHTTPHeaderField: "Range")
            }
        }

        let task = backgroundSession.downloadTask(with: request)
        activeTasks[item.id] = task
        task.resume()
        speedTracker[item.id] = (0, Date())
        showNotification(title: "Download Started", body: item.fileName)
    }

    private func updateProgress(id: String, downloadedBytes: Int64, totalBytes: Int64) async {
        guard let idx = queue.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        let tracker = speedTracker[id] ?? (0, now)
        let elapsed = now.timeIntervalSince(tracker.time)
        if elapsed > 0 {
            let bytesDiff = downloadedBytes - tracker.bytes
            let currentSpeed = Double(bytesDiff) / elapsed
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

    private func handleDownloadError(_ id: String, error: Error) {
        Task {
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
                showNotification(title: "Download Failed", body: queue[idx].fileName)
            } else if queue[idx].retryCount < queue[idx].maxRetries {
                queue[idx].retryCount += 1
                queue[idx].status = .queued
                if !queue[idx].mirrorUrls.isEmpty && queue[idx].retryCount > 1 {
                    let delay = pow(2.0, Double(queue[idx].retryCount - 1))
                    let workItem = DispatchWorkItem { [weak self] in
                        Task { @MainActor [weak self] in
                            _ = await self?.switchToMirror(id)
                        }
                    }
                    retryWorkItems[id] = workItem
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
                }
            } else {
                if !queue[idx].mirrorUrls.isEmpty {
                    _ = await switchToMirror(id)
                    return
                }
                queue[idx].status = .error
                if !(queue[idx].errorMessage?.contains("Retrying") ?? false) {
                    queue[idx].errorMessage = error.localizedDescription
                }
                showNotification(title: "Download Failed", body: queue[idx].fileName)
            }

            try? await DatabaseService.shared.updateDownload(queue[idx])
            objectWillChange.send()
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func syncLiveActivityState() {
        let activeDownloads = queue.filter { $0.status == .downloading }
        if activeDownloads.isEmpty {
            onAllDownloadsComplete?()
        }
    }
}

// MARK: - URLSession Delegate

private final class SessionDelegate: NSObject, URLSessionDownloadDelegate {
    weak var parent: DownloadsViewModel?

    init(parent: DownloadsViewModel) {
        self.parent = parent
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let parent = parent,
              let id = parent.activeTasks.first(where: { $0.value == downloadTask })?.key else { return }
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : totalBytesWritten
        Task { @MainActor in
            await parent.updateProgress(id: id, downloadedBytes: totalBytesWritten, totalBytes: total)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let parent = parent,
              let id = parent.activeTasks.first(where: { $0.value == downloadTask })?.key else { return }
        Task { @MainActor in
            guard let idx = parent.queue.firstIndex(where: { $0.id == id }) else { return }
            let destURL = URL(fileURLWithPath: parent.queue[idx].savePath)
            try? FileManager.default.removeItem(at: destURL)
            do {
                try FileManager.default.moveItem(at: location, to: destURL)
                parent.queue[idx].savePath = destURL.path
            } catch {
                parent.queue[idx].errorMessage = "Failed to move file: \(error.localizedDescription)"
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let parent = parent,
              let downloadTask = task as? URLSessionDownloadTask,
              let id = parent.activeTasks.first(where: { $0.value == downloadTask })?.key else { return }
        Task { @MainActor in
            parent.activeTasks.removeValue(forKey: id)
            parent.speedTracker.removeValue(forKey: id)

            guard let idx = parent.queue.firstIndex(where: { $0.id == id }) else { return }

            if let error = error {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain,
                   let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    parent.resumeDataMap[id] = resumeData
                    parent.queue[idx].status = .paused
                    parent.queue[idx].speedBytesPerSec = 0
                    if parent.activeCount > 0 { parent.activeCount -= 1 }
                    try? await DatabaseService.shared.updateDownload(parent.queue[idx])
                    parent.processQueue()
                    parent.syncLiveActivityState()
                    return
                }
                if nsError.code == NSURLErrorCancelled { return }
                parent.handleDownloadError(id, error: error)
            } else {
                parent.queue[idx].status = .done
                parent.queue[idx].speedBytesPerSec = 0
                parent.queue[idx].etaSeconds = 0
                parent.queue[idx].downloadedBytes = parent.queue[idx].totalBytes
                if parent.queue[idx].category == .other {
                    parent.queue[idx].category = DownloadCategory.from(fileName: parent.queue[idx].fileName)
                }
                if parent.activeCount > 0 { parent.activeCount -= 1 }
                try? await DatabaseService.shared.updateDownload(parent.queue[idx])
                await parent.updateStorageInfo()
                parent.showNotification(title: "Download Complete", body: parent.queue[idx].fileName)
                parent.processQueue()
                parent.syncLiveActivityState()
            }

            parent.resumeDataMap.removeValue(forKey: id)
            parent.retryWorkItems[id]?.cancel()
            parent.retryWorkItems.removeValue(forKey: id)
            parent.objectWillChange.send()
        }
    }
}

private class ImportQueueDelegate: NSObject, UIDocumentPickerDelegate {
    let completion: (String) -> Void

    init(completion: @escaping (String) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first,
              let data = try? Data(contentsOf: url),
              let json = String(data: data, encoding: .utf8) else { return }
        completion(json)
    }
}

