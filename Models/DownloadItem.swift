import Foundation

enum DownloadStatus: Int, Codable {
    case queued, downloading, paused, error, done
}

enum DownloadCategory: Int, Codable {
    case movies, tvShows, music, images, documents, archives, apps, other

    var label: String {
        switch self {
        case .movies: return "Movies"
        case .tvShows: return "TV Shows"
        case .music: return "Music"
        case .images: return "Images"
        case .documents: return "Documents"
        case .archives: return "Archives"
        case .apps: return "Apps"
        case .other: return "Other"
        }
    }

    static func from(fileName name: String) -> DownloadCategory {
        let ext = (name as NSString).pathExtension.lowercased()
        if ["mp4", "mkv", "avi", "mov", "webm", "wmv", "flv", "m4v"].contains(ext) { return .movies }
        if ["mp3", "flac", "wav", "aac", "ogg", "wma", "m4a"].contains(ext) { return .music }
        if ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic"].contains(ext) { return .images }
        if ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv"].contains(ext) { return .documents }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso"].contains(ext) { return .archives }
        if ["apk", "ipa", "exe", "dmg", "deb", "rpm"].contains(ext) { return .apps }
        if ["mp4", "mkv", "avi", "srt", "vtt", "sub"].contains(ext) { return .tvShows }
        return .other
    }

    static func from(mimeType mime: String?) -> DownloadCategory {
        guard let m = mime?.lowercased() else { return .other }
        if m.hasPrefix("video/") { return .movies }
        if m.hasPrefix("audio/") { return .music }
        if m.hasPrefix("image/") { return .images }
        if m.hasPrefix("text/") || m.hasPrefix("application/pdf") { return .documents }
        if m.contains("zip") || m.contains("rar") || m.contains("tar") || m.contains("7z") { return .archives }
        if m.contains("apk") || m.contains("x-msdownload") { return .apps }
        return .other
    }
}

enum ScheduleType: Int, Codable {
    case immediate, queueOnly, wifiOnly, chargingOnly, scheduled
}

struct DownloadItem: Identifiable, Codable {
    var id: String
    var url: String
    var fileName: String
    var savePath: String
    var batchId: String?
    var batchName: String?
    var status: DownloadStatus
    var totalBytes: Int64
    var downloadedBytes: Int64
    var speedBytesPerSec: Double
    var etaSeconds: Int
    var retryCount: Int
    var maxRetries: Int
    var errorMessage: String?
    var addedAt: Date
    var originalUrl: String?
    var customHeaders: [String: String]
    var mirrorUrls: [String]
    var category: DownloadCategory
    var scheduleType: ScheduleType
    var scheduledAt: Date?
    var expectedMd5: String?
    var expectedSha1: String?
    var expectedSha256: String?
    var calculatedMd5: String?
    var calculatedSha1: String?
    var calculatedSha256: String?
    var redirectCount: Int
    var resolvedUrl: String?

    var progress: Double {
        totalBytes > 0 ? min(max(Double(downloadedBytes) / Double(totalBytes), 0), 1) : 0
    }

    var statusLabel: String {
        switch status {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .error: return "Error"
        case .done: return "Done"
        }
    }

    var categoryLabel: String {
        category.label
    }

    var host: String {
        URL(string: url)?.host ?? "Unknown"
    }

    init(
        id: String,
        url: String,
        fileName: String,
        savePath: String,
        batchId: String? = nil,
        batchName: String? = nil,
        status: DownloadStatus = .queued,
        totalBytes: Int64 = 0,
        downloadedBytes: Int64 = 0,
        speedBytesPerSec: Double = 0,
        etaSeconds: Int = 0,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        errorMessage: String? = nil,
        addedAt: Date? = nil,
        originalUrl: String? = nil,
        customHeaders: [String: String] = [:],
        mirrorUrls: [String] = [],
        category: DownloadCategory = .other,
        scheduleType: ScheduleType = .immediate,
        scheduledAt: Date? = nil,
        expectedMd5: String? = nil,
        expectedSha1: String? = nil,
        expectedSha256: String? = nil,
        calculatedMd5: String? = nil,
        calculatedSha1: String? = nil,
        calculatedSha256: String? = nil,
        redirectCount: Int = 0,
        resolvedUrl: String? = nil
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.savePath = savePath
        self.batchId = batchId
        self.batchName = batchName
        self.status = status
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.speedBytesPerSec = speedBytesPerSec
        self.etaSeconds = etaSeconds
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.errorMessage = errorMessage
        self.addedAt = addedAt ?? Date()
        self.originalUrl = originalUrl
        self.customHeaders = customHeaders
        self.mirrorUrls = mirrorUrls
        self.category = category
        self.scheduleType = scheduleType
        self.scheduledAt = scheduledAt
        self.expectedMd5 = expectedMd5
        self.expectedSha1 = expectedSha1
        self.expectedSha256 = expectedSha256
        self.calculatedMd5 = calculatedMd5
        self.calculatedSha1 = calculatedSha1
        self.calculatedSha256 = calculatedSha256
        self.redirectCount = redirectCount
        self.resolvedUrl = resolvedUrl
    }

    func copyWith(
        status: DownloadStatus? = nil,
        totalBytes: Int64? = nil,
        downloadedBytes: Int64? = nil,
        speedBytesPerSec: Double? = nil,
        etaSeconds: Int? = nil,
        retryCount: Int? = nil,
        errorMessage: String?? = nil
    ) -> DownloadItem {
        DownloadItem(
            id: id,
            url: url,
            fileName: fileName,
            savePath: savePath,
            batchId: batchId,
            batchName: batchName,
            status: status ?? self.status,
            totalBytes: totalBytes ?? self.totalBytes,
            downloadedBytes: downloadedBytes ?? self.downloadedBytes,
            speedBytesPerSec: speedBytesPerSec ?? self.speedBytesPerSec,
            etaSeconds: etaSeconds ?? self.etaSeconds,
            retryCount: retryCount ?? self.retryCount,
            maxRetries: maxRetries,
            errorMessage: errorMessage ?? self.errorMessage,
            addedAt: addedAt,
            originalUrl: originalUrl,
            customHeaders: customHeaders,
            mirrorUrls: mirrorUrls,
            category: category,
            scheduleType: scheduleType,
            scheduledAt: scheduledAt,
            expectedMd5: expectedMd5,
            expectedSha1: expectedSha1,
            expectedSha256: expectedSha256,
            calculatedMd5: calculatedMd5,
            calculatedSha1: calculatedSha1,
            calculatedSha256: calculatedSha256,
            redirectCount: redirectCount,
            resolvedUrl: resolvedUrl
        )
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "url": url,
            "fileName": fileName,
            "savePath": savePath,
            "status": status.rawValue,
            "totalBytes": totalBytes,
            "downloadedBytes": downloadedBytes,
            "retryCount": retryCount,
            "maxRetries": maxRetries,
            "addedAt": ISO8601DateFormatter().string(from: addedAt),
            "category": category.rawValue,
            "scheduleType": scheduleType.rawValue,
            "redirectCount": redirectCount,
        ]
        if let v = batchId { dict["batchId"] = v }
        if let v = batchName { dict["batchName"] = v }
        if let v = errorMessage { dict["errorMessage"] = v }
        if let v = originalUrl { dict["originalUrl"] = v }
        if !customHeaders.isEmpty {
            if let data = try? JSONSerialization.data(withJSONObject: customHeaders, options: []),
               let str = String(data: data, encoding: .utf8) {
                dict["customHeadersJson"] = str
            }
        }
        if !mirrorUrls.isEmpty {
            if let data = try? JSONSerialization.data(withJSONObject: mirrorUrls, options: []),
               let str = String(data: data, encoding: .utf8) {
                dict["mirrorUrlsJson"] = str
            }
        }
        if let v = scheduledAt { dict["scheduledAt"] = ISO8601DateFormatter().string(from: v) }
        if let v = expectedMd5 { dict["expectedMd5"] = v }
        if let v = expectedSha1 { dict["expectedSha1"] = v }
        if let v = expectedSha256 { dict["expectedSha256"] = v }
        if let v = calculatedMd5 { dict["calculatedMd5"] = v }
        if let v = calculatedSha1 { dict["calculatedSha1"] = v }
        if let v = calculatedSha256 { dict["calculatedSha256"] = v }
        if let v = resolvedUrl { dict["resolvedUrl"] = v }
        return dict
    }

    init(from dictionary: [String: Any]) {
        let formatter = ISO8601DateFormatter()
        let customHeadersJson = dictionary["customHeadersJson"] as? String
        let mirrorUrlsJson = dictionary["mirrorUrlsJson"] as? String
        var headers: [String: String] = [:]
        if let json = customHeadersJson, let data = json.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let dict = obj as? [String: String] {
            headers = dict
        }
        var mirrors: [String] = []
        if let json = mirrorUrlsJson, let data = json.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data, options: []),
           let arr = obj as? [String] {
            mirrors = arr
        }
        self.init(
            id: dictionary["id"] as? String ?? "",
            url: dictionary["url"] as? String ?? "",
            fileName: dictionary["fileName"] as? String ?? "",
            savePath: dictionary["savePath"] as? String ?? "",
            batchId: dictionary["batchId"] as? String,
            batchName: dictionary["batchName"] as? String,
            status: DownloadStatus(rawValue: dictionary["status"] as? Int ?? 0) ?? .queued,
            totalBytes: dictionary["totalBytes"] as? Int64 ?? 0,
            downloadedBytes: dictionary["downloadedBytes"] as? Int64 ?? 0,
            retryCount: dictionary["retryCount"] as? Int ?? 0,
            maxRetries: dictionary["maxRetries"] as? Int ?? 3,
            errorMessage: dictionary["errorMessage"] as? String,
            addedAt: (dictionary["addedAt"] as? String).flatMap { formatter.date(from: $0) },
            originalUrl: dictionary["originalUrl"] as? String,
            customHeaders: headers,
            mirrorUrls: mirrors,
            category: DownloadCategory(rawValue: dictionary["category"] as? Int ?? 6) ?? .other,
            scheduleType: ScheduleType(rawValue: dictionary["scheduleType"] as? Int ?? 0) ?? .immediate,
            scheduledAt: (dictionary["scheduledAt"] as? String).flatMap { formatter.date(from: $0) },
            expectedMd5: dictionary["expectedMd5"] as? String,
            expectedSha1: dictionary["expectedSha1"] as? String,
            expectedSha256: dictionary["expectedSha256"] as? String,
            calculatedMd5: dictionary["calculatedMd5"] as? String,
            calculatedSha1: dictionary["calculatedSha1"] as? String,
            calculatedSha256: dictionary["calculatedSha256"] as? String,
            redirectCount: dictionary["redirectCount"] as? Int ?? 0,
            resolvedUrl: dictionary["resolvedUrl"] as? String
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, url, fileName, savePath, batchId, batchName, status, totalBytes, downloadedBytes,
             speedBytesPerSec, etaSeconds, retryCount, maxRetries, errorMessage, addedAt, originalUrl,
             customHeaders, mirrorUrls, category, scheduleType, scheduledAt,
             expectedMd5, expectedSha1, expectedSha256,
             calculatedMd5, calculatedSha1, calculatedSha256,
             redirectCount, resolvedUrl
    }

    static func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.2f GB", Double(bytes) / 1_073_741_824.0)
        } else if bytes >= 1_048_576 {
            return String(format: "%.2f MB", Double(bytes) / 1_048_576.0)
        } else if bytes >= 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        }
        return "\(bytes) B"
    }

    static func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_073_741.824 {
            return String(format: "%.2f GB/s", bytesPerSec / 1_073_741_824.0)
        } else if bytesPerSec >= 1_048.576 {
            return String(format: "%.2f MB/s", bytesPerSec / 1_048_576.0)
        } else if bytesPerSec >= 1.024 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024.0)
        }
        return String(format: "%.0f B/s", bytesPerSec)
    }

    static func formatEta(_ seconds: Int) -> String {
        if seconds <= 0 { return "--" }
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 { return String(format: "%d:%02d:%02d", hrs, mins, secs) }
        if mins > 0 { return String(format: "%d:%02d", mins, secs) }
        return String(format: "0:%02d", secs)
    }
}
