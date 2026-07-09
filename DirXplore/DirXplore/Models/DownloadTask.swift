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

    var estimatedTimeRemaining: TimeInterval? {
        guard status == .downloading, downloadedBytes > 0 else { return nil }
        let remaining = fileSize - downloadedBytes
        let speed = downloadedBytes / Int64(max(1, Date().timeIntervalSince(startDate)))
        guard speed > 0 else { return nil }
        return TimeInterval(remaining) / TimeInterval(speed)
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
        case .seedr: return "seedling"
        case .mediafire: return "flame"
        case .mega: return "square.stack.3d.up"
        case .dropbox: return "cube.box"
        case .onedrive: return "cloud"
        case .unknown: return "questionmark.circle"
        }
    }
}
