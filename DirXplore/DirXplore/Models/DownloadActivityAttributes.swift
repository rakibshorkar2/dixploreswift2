import ActivityKit
import Foundation

public struct DownloadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double             // 0.0 to 1.0
        public var downloadedBytes: Int64
        public var fileSize: Int64
        public var downloadSpeed: Double        // in bytes/second
        public var status: String               // e.g., "Downloading", "Paused", "Completed", "Failed", "Cancelled"
        public var formattedTimeRemaining: String // e.g., "5m 23s"

        public init(
            progress: Double,
            downloadedBytes: Int64,
            fileSize: Int64,
            downloadSpeed: Double,
            status: String,
            formattedTimeRemaining: String
        ) {
            self.progress = progress
            self.downloadedBytes = downloadedBytes
            self.fileSize = fileSize
            self.downloadSpeed = downloadSpeed
            self.status = status
            self.formattedTimeRemaining = formattedTimeRemaining
        }
    }

    public var fileName: String
    public var downloadTaskId: String

    public init(fileName: String, downloadTaskId: String) {
        self.fileName = fileName
        self.downloadTaskId = downloadTaskId
    }
}
