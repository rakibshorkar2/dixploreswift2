import Foundation

actor LinkResolver {
    static let shared = LinkResolver()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func resolve(_ urlString: String) async -> ResolvedLink {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ResolvedLink(error: .invalidURL)
        }

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else {
            return ResolvedLink(error: .invalidURL)
        }

        let sourceType = detectSourceType(from: url)
        var finalURL = url
        var fileName: String?
        var fileSize: Int64 = 0

        switch sourceType {
        case .googleDrive:
            let result = await resolveGoogleDrive(url)
            finalURL = result.url
            fileName = result.fileName
            fileSize = result.fileSize
        case .dropbox:
            finalURL = resolveDropbox(url)
        case .mediafire:
            let result = await resolveMediaFire(url)
            finalURL = result.url
            fileName = result.fileName
        default:
            break
        }

        if fileName == nil {
            fileName = extractFileName(from: finalURL)
        }

        let headResult = await fetchHeadInfo(url: finalURL)
        if fileName == nil || fileName == "download" {
            fileName = headResult.0
        }
        if fileSize == 0 {
            fileSize = headResult.1
        }

        let finalName = fileName ?? "download"
        if finalName == "download", let lastPath = finalURL.lastPathComponent.removingPercentEncoding, !lastPath.isEmpty, lastPath != "/" {
            let safeName = lastPath
            return ResolvedLink(url: finalURL, fileName: safeName, fileSize: fileSize, sourceType: sourceType, error: nil)
        }

        return ResolvedLink(
            url: finalURL,
            fileName: finalName,
            fileSize: fileSize,
            sourceType: sourceType,
            error: nil
        )
    }

    private func detectSourceType(from url: URL) -> LinkSourceType {
        let host = url.host?.lowercased() ?? ""
        let absoluteString = url.absoluteString.lowercased()

        if host.contains("drive.google.com") || absoluteString.contains("drive.google.com") {
            return .googleDrive
        }
        if host.contains("googleusercontent.com") || host.contains("ggpht.com") {
            return .googleDrive
        }
        if host.contains("seedr") || absoluteString.contains("seedr") {
            return .seedr
        }
        if host.contains("mediafire") {
            return .mediafire
        }
        if host.contains("mega") || absoluteString.contains("mega") {
            return .mega
        }
        if host.contains("dropbox") {
            return .dropbox
        }
        if host.contains("1drv") || host.contains("onedrive") || absoluteString.contains("onedrive") {
            return .onedrive
        }
        if host.contains("cloudflarestorage.com") || host.contains("r2.cloudflarestorage.com") {
            return .direct
        }
        if absoluteString.hasSuffix(".mp4") || absoluteString.hasSuffix(".zip") ||
           absoluteString.hasSuffix(".pdf") || absoluteString.hasSuffix(".png") ||
           absoluteString.hasSuffix(".jpg") || absoluteString.hasSuffix(".mp3") ||
           absoluteString.hasSuffix(".dmg") || absoluteString.hasSuffix(".exe") ||
           absoluteString.hasSuffix(".apk") || absoluteString.hasSuffix(".iso") ||
           absoluteString.hasSuffix(".rar") || absoluteString.hasSuffix(".7z") ||
           absoluteString.hasSuffix(".tar") || absoluteString.hasSuffix(".gz") ||
           absoluteString.hasSuffix(".webm") || absoluteString.hasSuffix(".m4a") ||
           absoluteString.hasSuffix(".mov") || absoluteString.hasSuffix(".avi") {
            return .direct
        }
        return .unknown
    }

    private func resolveGoogleDrive(_ url: URL) async -> (url: URL, fileName: String?, fileSize: Int64) {
        let fileID = extractGoogleDriveFileID(from: url)
        guard let id = fileID else {
            return (url, nil, 0)
        }

        guard let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let directURL = URL(string: "https://drive.google.com/uc?export=download&id=\(encodedID)"),
              let confirmURL = URL(string: "https://drive.google.com/uc?export=download&confirm=t&id=\(encodedID)") else {
            return (url, nil, 0)
        }

        var fileName: String?
        var fileSize: Int64 = 0

        var request = URLRequest(url: directURL)
        request.httpMethod = "HEAD"

        if let response = try? await session.data(for: request),
           let httpResponse = response.1 as? HTTPURLResponse {
            if let disposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
                fileName = extractFileName(from: disposition)
            }
            fileSize = httpResponse.expectedContentLength
        }

        let finalURL = fileSize > 0 ? directURL : confirmURL
        return (finalURL, fileName, max(fileSize, 0))
    }

    private func extractGoogleDriveFileID(from url: URL) -> String? {
        let patterns = [
            "/file/d/([^/]+)",
            "id=([^&]+)",
            "open\\?id=([^&]+)"
        ]
        let absoluteString = url.absoluteString
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: absoluteString, range: NSRange(absoluteString.startIndex..., in: absoluteString)),
               let range = Range(match.range(at: 1), in: absoluteString) {
                return String(absoluteString[range])
            }
        }
        return nil
    }

    private func resolveDropbox(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var queryItems = components.queryItems ?? []
        if queryItems.contains(where: { $0.name == "dl" && $0.value == "0" }) {
            queryItems.removeAll { $0.name == "dl" }
            queryItems.append(URLQueryItem(name: "dl", value: "1"))
        } else if !queryItems.contains(where: { $0.name == "dl" }) &&
                  !queryItems.contains(where: { $0.name == "raw" }) {
            queryItems.append(URLQueryItem(name: "dl", value: "1"))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url ?? url
    }

    private func resolveMediaFire(_ url: URL) async -> (url: URL, fileName: String?) {
        var fileName: String?
        if let response = try? await session.data(from: url),
           let html = String(data: response.0, encoding: .utf8),
           let range = html.range(of: "aria-label=\"Download") {
            let startIndex = range.lowerBound
            if let hrefStart = html.range(of: "href=\"", range: startIndex..<html.endIndex),
               let hrefEnd = html.range(of: "\"", range: hrefStart.upperBound..<html.endIndex) {
                let href = String(html[hrefStart.upperBound..<hrefEnd.lowerBound])
                if let downloadURL = URL(string: href) {
                    return (downloadURL, fileName)
                }
            }
        }
        return (url, fileName)
    }

    private func extractFileName(from url: URL) -> String? {
        let path = url.lastPathComponent
        if !path.isEmpty, path != "/" {
            return path.removingPercentEncoding ?? path
        }
        return nil
    }

    private func extractFileName(from contentDisposition: String) -> String? {
        let patterns = [
            "filename\\*?\\s*=\\s*UTF-8''([^;]+)",
            "filename\\s*=\\s*\"([^\"]+)\"",
            "filename\\s*=\\s*([^;]+)"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: contentDisposition, range: NSRange(contentDisposition.startIndex..., in: contentDisposition)),
               let range = Range(match.range(at: 1), in: contentDisposition) {
                let name = String(contentDisposition[range]).trimmingCharacters(in: .whitespaces)
                return name.removingPercentEncoding ?? name
            }
        }
        return nil
    }

    private func fetchHeadInfo(url: URL) async -> (String, Int64) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        guard let response = try? await session.data(for: request),
              let httpResponse = response.1 as? HTTPURLResponse else {
            return ("", 0)
        }
        var fileName = ""
        if let disposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
            fileName = extractFileName(from: disposition) ?? ""
        }
        if fileName.isEmpty, let lastPath = url.lastPathComponent.removingPercentEncoding, !lastPath.isEmpty, lastPath != "/" {
            fileName = lastPath
        }
        let size = max(httpResponse.expectedContentLength, 0)
        return (fileName, size)
    }

    private func fetchFileSize(url: URL) async -> Int64 {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        guard let response = try? await session.data(for: request),
              let httpResponse = response.1 as? HTTPURLResponse else {
            return 0
        }
        return max(httpResponse.expectedContentLength, 0)
    }
}

struct ResolvedLink {
    let url: URL
    let fileName: String
    let fileSize: Int64
    let sourceType: LinkSourceType
    let error: LinkError?

    init(url: URL = URL(fileURLWithPath: "/"),
         fileName: String = "",
         fileSize: Int64 = 0,
         sourceType: LinkSourceType = .unknown,
         error: LinkError? = nil) {
        self.url = url
        self.fileName = fileName
        self.fileSize = fileSize
        self.sourceType = sourceType
        self.error = error
    }

    enum LinkError: LocalizedError {
        case invalidURL
        case unsupportedLink
        case networkError(String)
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL. Please check the link and try again."
            case .unsupportedLink: return "This link type is not supported yet."
            case .networkError(let msg): return "Network error: \(msg)"
            case .fileTooLarge: return "File is too large to download."
            }
        }
    }
}
