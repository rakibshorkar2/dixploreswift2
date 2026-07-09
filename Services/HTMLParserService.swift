import Foundation

final class HTMLParserService {

    static func parseApacheDirectoryAsync(html: String, baseUrl: String) async -> [DirectoryItem] {
        return await Task.detached(priority: .background) {
            parseApacheDirectory(html: html, baseUrl: baseUrl)
        }.value
    }

    static func parseApacheDirectory(html: String, baseUrl: String) -> [DirectoryItem] {
        var items: [DirectoryItem] = []

        guard let baseUri = URL(string: baseUrl) else { return [] }

        let anchorPattern = try? NSRegularExpression(
            pattern: "<a\\s+[^>]*href\\s*=\\s*\"([^\"]*)\"[^>]*>([^<]*)</a>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        let tdPattern = try? NSRegularExpression(
            pattern: "<td[^>]*>([^<]*)</td>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
        let trPattern = try? NSRegularExpression(
            pattern: "<tr[^>]*>(.*?)</tr>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )

        let fullRange = NSRange(html.startIndex..<html.endIndex, in: html)

        guard let trMatches = trPattern?.matches(in: html, options: [], range: fullRange) else {
            return parseAnchorOnly(html: html, baseUri: baseUri, anchorPattern: anchorPattern)
        }

        for trMatch in trMatches {
            guard let trRange = Range(trMatch.range, in: html) else { continue }
            let trContent = String(html[trRange])
            let trNSRange = NSRange(trContent.startIndex..<trContent.endIndex, in: trContent)

            var cells: [String] = []
            if let tdMatches = tdPattern?.matches(in: trContent, options: [], range: trNSRange) {
                for tdMatch in tdMatches {
                    if let tdRange = Range(tdMatch.range(at: 1), in: trContent) {
                        cells.append(String(trContent[tdRange]).trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }

            guard let aMatch = anchorPattern?.firstMatch(in: trContent, options: [], range: trNSRange),
                  let hrefRange = Range(aMatch.range(at: 1), in: trContent),
                  let textRange = Range(aMatch.range(at: 2), in: trContent) else { continue }

            let href = String(trContent[hrefRange])
            var text = String(trContent[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard processAnchor(href: href, text: &text, baseUri: baseUri, baseUrl: baseUrl) else { continue }

            let isDir = href.hasSuffix("/")
            var sizeStr: String?
            if cells.count >= 4 {
                let rawSize = cells[3]
                sizeStr = rawSize == "-" ? nil : rawSize
            }

            guard let finalUrl = resolveUrl(href: href, baseUri: baseUri, isDir: isDir),
                  finalUrl != baseUrl else { continue }
            if text.isEmpty { continue }

            items.append(DirectoryItem(
                name: text,
                url: finalUrl,
                type: isDir ? .directory : DirectoryItem.type(fromExtension: text),
                size: DirectoryItem.formatSize(sizeStr)
            ))
        }

        if items.isEmpty {
            items = parseAnchorOnly(html: html, baseUri: baseUri, anchorPattern: anchorPattern)
        }

        return items
    }

    private static func parseAnchorOnly(html: String, baseUri: URL, anchorPattern: NSRegularExpression?) -> [DirectoryItem] {
        var items: [DirectoryItem] = []
        guard let pattern = anchorPattern else { return [] }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = pattern.matches(in: html, options: [], range: nsRange)

        for match in matches {
            guard let hrefRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else { continue }
            let href = String(html[hrefRange])
            var text = String(html[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard processAnchor(href: href, text: &text, baseUri: baseUri, baseUrl: baseUri.absoluteString) else { continue }
            let isDir = href.hasSuffix("/")
            guard let finalUrl = resolveUrl(href: href, baseUri: baseUri, isDir: isDir),
                  finalUrl != baseUri.absoluteString else { continue }
            if text.isEmpty { continue }

            items.append(DirectoryItem(
                name: text,
                url: finalUrl,
                type: isDir ? .directory : DirectoryItem.type(fromExtension: text),
                size: nil
            ))
        }
        return items
    }

    private static func processAnchor(href: String, text: inout String, baseUri: URL, baseUrl: String) -> Bool {
        if href.isEmpty || href.hasPrefix("?") || href.hasPrefix("#") { return false }
        if href == "../" || href == "/" || href == "./" { return false }

        let tLower = text.lowercased()
        if ["parent directory", "name", "size", "date", "description", "last modified"].contains(tLower) {
            return false
        }

        let isDir = href.hasSuffix("/")
        if isDir && text.hasSuffix("/") {
            text = String(text.dropLast())
        }

        if href.lowercased().hasPrefix("http") && !isDir && text.isEmpty {
            text = URL(string: href)?.lastPathComponent ?? ""
        }

        return true
    }

    private static func resolveUrl(href: String, baseUri: URL, isDir: Bool) -> String? {
        guard let resolved = URL(string: href, relativeTo: baseUri)?.absoluteURL else { return nil }
        var finalUrl = resolved.absoluteString
        if isDir && !finalUrl.hasSuffix("/") {
            finalUrl += "/"
        }
        return finalUrl
    }
}
