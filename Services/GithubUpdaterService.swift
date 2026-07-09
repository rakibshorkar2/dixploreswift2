import Foundation

@MainActor
final class GithubUpdaterService {
    static let shared = GithubUpdaterService()

    private let repoUrl = "https://api.github.com/repos/rakibdev/DirXplore/releases/latest"
    private var cachedVersion: String?
    private var cachedDownloadUrl: String?

    private init() {}

    struct UpdateInfo {
        let version: String
        let downloadUrl: String
        let releaseNotes: String
    }

    func checkForUpdate(currentVersion: String) async -> UpdateInfo? {
        guard let url = URL(string: repoUrl) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("DirXplore/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

            let tagName = json["tag_name"] as? String ?? ""
            let version = tagName.replacingOccurrences(of: "^v", with: "", options: .regularExpression)
            let body = json["body"] as? String ?? ""
            let assets = json["assets"] as? [[String: Any]] ?? []
            let downloadUrl = assets.first?["browser_download_url"] as? String ?? ""

            guard !version.isEmpty, version.compare(currentVersion, options: .numeric) == .orderedDescending else {
                return nil
            }

            cachedVersion = version
            cachedDownloadUrl = downloadUrl

            return UpdateInfo(version: version, downloadUrl: downloadUrl, releaseNotes: body)
        } catch {
            return nil
        }
    }

    func openUpdatePage(url: String) {
        guard let url = URL(string: url) else { return }
        UIApplication.shared.open(url, options: [:])
    }
}
