import Foundation

enum FormattingHelpers {
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

    static func formatBytes(_ bytes: Double) -> String {
        formatBytes(Int64(bytes))
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

    static func formatDuration(_ seconds: Int) -> String {
        if seconds <= 0 { return "--" }
        let hrs = seconds / 3600
        let mins = (seconds % 3600) / 60
        let secs = seconds % 60
        if hrs > 0 {
            return String(format: "%d h %d m", hrs, mins)
        }
        if mins > 0 {
            return String(format: "%d m %d s", mins, secs)
        }
        return String(format: "%d s", secs)
    }

    static func formatStorage(bytes: Int64) -> String {
        formatBytes(bytes)
    }

    static func formatPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", min(max(value * 100, 0), 100))
    }

    static func formatFileSize(fromServer serverSize: String) -> String {
        let trimmed = serverSize.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty, trimmed != "-" else { return "Unknown" }
        let numeric = trimmed.replacingOccurrences(of: #"[^0-9.]"#, with: "", options: .regularExpression)
        guard let value = Double(numeric) else { return serverSize }

        var bytes: Double = 0
        if trimmed.hasSuffix("K") || trimmed.hasSuffix("KB") {
            bytes = value * 1024
        } else if trimmed.hasSuffix("M") || trimmed.hasSuffix("MB") {
            bytes = value * 1024 * 1024
        } else if trimmed.hasSuffix("G") || trimmed.hasSuffix("GB") {
            bytes = value * 1024 * 1024 * 1024
        } else if trimmed.hasSuffix("T") || trimmed.hasSuffix("TB") {
            bytes = value * 1024 * 1024 * 1024 * 1024
        } else {
            bytes = value
        }
        return formatBytes(Int64(bytes))
    }
}
