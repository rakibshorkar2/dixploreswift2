import Foundation

enum DirectoryItemType: String, Codable {
    case directory, video, audio, image, archive, document, other
}

struct DirectoryItem: Identifiable {
    var name: String
    var url: String
    var type: DirectoryItemType
    var size: String?
    var isSelected: Bool

    var id: String { url }

    var isDirectory: Bool { type == .directory }

    var typeTag: String {
        switch type {
        case .directory: return "[DIR]"
        case .video: return "[VID]"
        case .audio: return "[AUD]"
        case .image: return "[IMG]"
        case .archive: return "[ZIP]"
        case .document: return "[DOC]"
        case .other: return "[FIL]"
        }
    }

    init(
        name: String,
        url: String,
        type: DirectoryItemType,
        size: String? = nil,
        isSelected: Bool = false
    ) {
        self.name = name
        self.url = url
        self.type = type
        self.size = Self.formatSize(size)
        self.isSelected = isSelected
    }

    static func type(fromExtension name: String) -> DirectoryItemType {
        let ext = (name as NSString).pathExtension.lowercased()
        let videoExt = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "m4v", "webm", "ts", "m2ts"]
        let audioExt = ["mp3", "flac", "aac", "ogg", "wav", "opus", "m4a", "wma"]
        let imageExt = ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "tiff"]
        let archiveExt = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso"]
        let docExt = ["pdf", "doc", "docx", "xls", "xlsx", "txt", "epub", "mobi", "srt", "nfo"]

        if videoExt.contains(ext) { return .video }
        if audioExt.contains(ext) { return .audio }
        if imageExt.contains(ext) { return .image }
        if archiveExt.contains(ext) { return .archive }
        if docExt.contains(ext) { return .document }
        return .other
    }

    static func formatSize(_ s: String?) -> String? {
        guard let s = s, !s.isEmpty, s != "-" else { return nil }
        var str = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var b: Double = 0
        let numeric = str.replacingOccurrences(of: #"[^0-9.]"#, with: "", options: .regularExpression)
        guard let value = Double(numeric) else { return s }

        if str.hasSuffix("K") || str.hasSuffix("KB") {
            b = value * 1024
        } else if str.hasSuffix("M") || str.hasSuffix("MB") {
            b = value * 1024 * 1024
        } else if str.hasSuffix("G") || str.hasSuffix("GB") {
            b = value * 1024 * 1024 * 1024
        } else {
            b = value
        }

        if b >= 1_073_741_824 {
            return String(format: "%.2f GB", b / 1_073_741_824.0)
        } else if b >= 1_048_576 {
            return String(format: "%.2f MB", b / 1_048_576.0)
        } else if b >= 1024 {
            return String(format: "%.1f KB", b / 1024.0)
        }
        return String(format: "%d B", Int(b))
    }
}
