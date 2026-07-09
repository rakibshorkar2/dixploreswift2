import Foundation

enum ClipboardContentType: Int, Codable {
    case text, url, image, richText, phone, email, json, code, color, filePath
}

struct ClipboardItem: Identifiable, Codable {
    let id: String
    let type: ClipboardContentType
    let preview: String
    let content: String
    let createdAt: Date
    var isFavorite: Bool
    var isPinned: Bool
    var tags: [String]
    var characterCount: Int
    var wordCount: Int
    var lineCount: Int
    var domain: String?
    var fileExtension: String?
    var language: String?
    var imagePath: String?

    init(
        id: String,
        type: ClipboardContentType,
        preview: String,
        content: String,
        createdAt: Date,
        isFavorite: Bool = false,
        isPinned: Bool = false,
        tags: [String] = [],
        characterCount: Int? = nil,
        wordCount: Int? = nil,
        lineCount: Int? = nil,
        domain: String? = nil,
        fileExtension: String? = nil,
        language: String? = nil,
        imagePath: String? = nil
    ) {
        self.id = id
        self.type = type
        self.preview = preview
        self.content = content
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.tags = tags
        self.characterCount = characterCount ?? content.count
        self.wordCount = wordCount ?? content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        self.lineCount = lineCount ?? content.components(separatedBy: "\n").count
        self.domain = domain
        self.fileExtension = fileExtension
        self.language = language
        self.imagePath = imagePath
    }

    init(from dict: [String: Any]) {
        let formatter = ISO8601DateFormatter()
        let tagsStr = dict["tags"] as? String
        let tags: [String] = tagsStr.flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? []
        self.init(
            id: dict["id"] as? String ?? UUID().uuidString,
            type: ClipboardContentType(rawValue: dict["type"] as? Int ?? 0) ?? .text,
            preview: dict["preview"] as? String ?? "",
            content: dict["content"] as? String ?? "",
            createdAt: (dict["createdAt"] as? String).flatMap { formatter.date(from: $0) } ?? Date(),
            isFavorite: (dict["isFavorite"] as? Int ?? 0) == 1,
            isPinned: (dict["isPinned"] as? Int ?? 0) == 1,
            tags: tags,
            characterCount: dict["characterCount"] as? Int,
            wordCount: dict["wordCount"] as? Int,
            domain: dict["domain"] as? String,
            fileExtension: dict["fileExtension"] as? String,
            language: dict["language"] as? String,
            imagePath: dict["imagePath"] as? String
        )
    }

    static func detectType(_ text: String) -> ClipboardContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") ||
           trimmed.hasPrefix("ftp://") || trimmed.hasPrefix("ftps://") ||
           trimmed.hasPrefix("magnet:") {
            return .url
        }
        if trimmed.range(of: #"^[\w\.-]+@[\w\.-]+\.\w+$"#, options: .regularExpression) != nil {
            return .email
        }
        if trimmed.range(of: #"^\+?[\d\s\-\(\)]{7,15}$"#, options: .regularExpression) != nil {
            return .phone
        }
        if let data = trimmed.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return .json
        }
        if trimmed.range(of: #"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$"#, options: .regularExpression) != nil ||
           trimmed.range(of: #"^rgb\(\d+,\s*\d+,\s*\d+\)$"#, options: .regularExpression) != nil ||
           trimmed.range(of: #"^hsl\(\d+,\s*\d+%,\s*\d+%\)$"#, options: .regularExpression) != nil ||
           trimmed.range(of: #"^rgba\(\d+,\s*\d+,\s*\d+,\s*[\d.]+\)$"#, options: .regularExpression) != nil {
            return .color
        }
        if trimmed.hasPrefix("/") || trimmed.range(of: #"^[A-Za-z]:\\"#, options: .regularExpression) != nil ||
           trimmed.range(of: #"^[A-Za-z]:/"#, options: .regularExpression) != nil {
            return .filePath
        }
        if text.contains("\n") || text.count > 200 {
            let codePatterns: [NSRegularExpression] = [
                try! NSRegularExpression(pattern: #"\bimport\b"#),
                try! NSRegularExpression(pattern: #"\bdef \b"#),
                try! NSRegularExpression(pattern: #"\bfunction\b"#),
                try! NSRegularExpression(pattern: #"\bclass\b"#),
                try! NSRegularExpression(pattern: #"\binterface\b"#),
                try! NSRegularExpression(pattern: #"\benum\b"#),
                try! NSRegularExpression(pattern: #"\bextends\b"#),
                try! NSRegularExpression(pattern: #"\bimplements\b"#),
                try! NSRegularExpression(pattern: #"\{[\s\S]*\}"#),
                try! NSRegularExpression(pattern: #"^<[^>]+>"#),
                try! NSRegularExpression(pattern: #"^</"#),
                try! NSRegularExpression(pattern: #"<!DOCTYPE"#),
                try! NSRegularExpression(pattern: #"\bSELECT\b|\bFROM\b|\bWHERE\b|\bJOIN\b|\bINSERT\b"#),
                try! NSRegularExpression(pattern: #"\bpublic\b|\bprivate\b|\bprotected\b|\bstatic\b"#),
                try! NSRegularExpression(pattern: #"\bvoid\b|\bint\b|\bstring\b|\bbool\b|\bdouble\b"#),
                try! NSRegularExpression(pattern: #"^[{\[(]"#),
            ]
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            for pattern in codePatterns {
                if pattern.firstMatch(in: text, options: [], range: nsRange) != nil {
                    return .code
                }
            }
        }
        return .text
    }

    static func detectLanguage(_ text: String) -> String {
        if text.range(of: #"\bimport\b.*\bpackage\b"#, options: .regularExpression) != nil { return "dart" }
        if text.range(of: #"\bimport\b.*\bUIKit\b"#, options: .regularExpression) != nil { return "swift" }
        if text.range(of: #"\bdef \b|\bimport\b|\bfrom\b.*\bimport\b"#, options: .regularExpression) != nil { return "python" }
        if text.range(of: #"\bfunction\b|\bconst\b|\blet\b|\bvar\b|\b=>\b"#, options: .regularExpression) != nil { return "javascript" }
        if text.range(of: #"^<!DOCTYPE html>"#, options: .regularExpression) != nil { return "html" }
        if text.range(of: #"@media"#, options: .regularExpression) != nil { return "css" }
        if text.range(of: #"\bSELECT\b|\bFROM\b|\bWHERE\b|\bJOIN\b"#, options: .regularExpression) != nil { return "sql" }
        return "code"
    }

    static func extractDomain(_ text: String) -> String? {
        URL(string: text)?.host
    }

    static func extractFileExtension(_ text: String) -> String? {
        let parts = (text as NSString).pathExtension
        return parts.isEmpty ? nil : parts
    }

    static func generatePreview(_ content: String, maxLength: Int = 120) -> String {
        if content.count <= maxLength { return content }
        return String(content.prefix(maxLength)) + "..."
    }

    func toDictionary() -> [String: Any] {
        let tagsJson = (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) }
        return [
            "id": id,
            "type": type.rawValue,
            "preview": preview,
            "content": content,
            "createdAt": ISO8601DateFormatter().string(from: createdAt),
            "isFavorite": isFavorite ? 1 : 0,
            "isPinned": isPinned ? 1 : 0,
            "tags": tagsJson as Any,
            "characterCount": characterCount,
            "wordCount": wordCount,
            "domain": domain as Any,
            "fileExtension": fileExtension as Any,
            "language": language as Any,
            "imagePath": imagePath as Any,
        ]
    }
}
