import Foundation
import UIKit

actor DownloadService {
    static let shared = DownloadService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 86400
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func downloadFile(from url: URL, fileName: String? = nil) {
        Task { @MainActor in
            DownloadManager.shared.addTask(url: url, fileName: fileName ?? url.lastPathComponent)
        }
    }

    func validateLink(_ urlString: String) async -> LinkValidationResult {
        let resolved = await LinkResolver.shared.resolve(urlString)

        if let error = resolved.error {
            return .invalid(error)
        }

        return .valid(
            url: resolved.url,
            fileName: resolved.fileName,
            fileSize: resolved.fileSize,
            sourceType: resolved.sourceType
        )
    }

    func pasteFromClipboard() -> String? {
        UIPasteboard.general.string
    }

    func startDownload(resolved: ResolvedLink) {
        Task { @MainActor in
            DownloadManager.shared.addTask(url: resolved.url, fileName: resolved.fileName, sourceType: resolved.sourceType)
        }
    }
}

enum LinkValidationResult {
    case valid(url: URL, fileName: String, fileSize: Int64, sourceType: LinkSourceType)
    case invalid(ResolvedLink.LinkError)
}
