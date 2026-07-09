import Foundation

enum DownloadStatus: String, Codable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

struct DownloadTask: Codable, Identifiable, Equatable {
    let id: UUID
    var url: URL
    var fileName: String
    var fileSize: Int64
    var downloadedBytes: Int64
    var status: DownloadStatus
    var progress: Double
    var startDate: Date
    var completionDate: Date?
    var errorMessage: String?
    var resumeData: Data?
    var sourceType: LinkSourceType
    var downloadSpeed: Double
    var retryCount: Int
    var priority: Int
    var category: String?

    var progressPercentage: String {
        String(format: "%.1f%%", progress * 100)
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var formattedDownloadedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: downloadedBytes)
    }

    var formattedSpeed: String {
        if downloadSpeed <= 0 { return "N/A" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(downloadSpeed)))/s"
    }

    var estimatedTimeRemaining: TimeInterval? {
        guard status == .downloading, downloadedBytes > 0, downloadSpeed > 0 else { return nil }
        let remaining = max(0, fileSize - downloadedBytes)
        guard remaining > 0 else { return nil }
        return TimeInterval(remaining) / downloadSpeed
    }

    var formattedTimeRemaining: String {
        guard let eta = estimatedTimeRemaining else { return "--" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .brief
        return formatter.string(from: eta) ?? "--"
    }

    var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    var isMediaFile: Bool {
        ["mp4", "mov", "avi", "mkv", "mp3", "wav", "aac", "flac", "m4a"].contains(fileExtension)
    }

    var isDocument: Bool {
        ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "csv", "md"].contains(fileExtension)
    }

    var isArchive: Bool {
        ["zip", "rar", "7z", "tar", "gz", "bz2"].contains(fileExtension)
    }

    var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "svg"].contains(fileExtension)
    }

    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        lhs.id == rhs.id
    }
}

enum LinkSourceType: String, Codable, CaseIterable {
    case direct = "Direct Link"
    case googleDrive = "Google Drive"
    case seedr = "Seedr"
    case mediafire = "MediaFire"
    case mega = "MEGA"
    case dropbox = "Dropbox"
    case onedrive = "OneDrive"
    case unknown = "Other"

    var iconName: String {
        switch self {
        case .direct: return "link"
        case .googleDrive: return "icloud"
        case .seedr: return "leaf"
        case .mediafire: return "flame"
        case .mega: return "square.stack.3d.up"
        case .dropbox: return "cube.box"
        case .onedrive: return "cloud"
        case .unknown: return "questionmark.circle"
        }
    }
}
