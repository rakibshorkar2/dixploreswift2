import Foundation

final class NetworkService: NSObject {
    static let shared = NetworkService()

    private var activeProxy: ProxyModel? {
        ProxyManager.shared.activeProxy
    }

    private var _sessionDelegate: ProxySessionDelegate?
    private var _session: URLSession?

    private lazy var defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private lazy var streamingSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 86400
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private var cachedSession: (proxyId: String?, session: URLSession, delegate: ProxySessionDelegate?)

    private func createProxySession() -> URLSession {
        if let proxy = activeProxy {
            let delegate = ProxySessionDelegate(
                host: proxy.host,
                port: proxy.port,
                username: proxy.username,
                password: proxy.password
            )
            _sessionDelegate = delegate
            let session = URLSession(configuration: delegate.makeSessionConfiguration(), delegate: self, delegateQueue: nil)
            _session = session
            return session
        }
        _sessionDelegate = nil
        _session = nil
        return defaultSession
    }

    private var activeSession: URLSession {
        let proxyId = activeProxy?.id ?? ""
        if cachedSession.proxyId == proxyId, cachedSession.proxyId != nil {
            return cachedSession.session
        }
        let session = createProxySession()
        cachedSession = (proxyId, session, _sessionDelegate)
        return session
    }

    private override init() {
        cachedSession = (nil, defaultSession, nil)
        super.init()
    }

    func refreshSession() {
        _session?.invalidateAndCancel()
        _sessionDelegate = nil
        cachedSession = (nil, defaultSession, nil)
        _ = activeSession
    }

    private var defaultHeaders: [String: String] {
        var headers: [String: String] = [:]
        headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        headers["Accept"] = "*/*"
        headers["Accept-Language"] = "en-US,en;q=0.9"
        return headers
    }

    func head(url: String, customHeaders: [String: String] = [:]) async throws -> HTTPURLResponse {
        guard let requestUrl = URL(string: url) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 30
        for (key, value) in defaultHeaders { request.setValue(value, forHTTPHeaderField: key) }
        for (key, value) in customHeaders { request.setValue(value, forHTTPHeaderField: key) }
        let (_, response) = try await activeSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        return httpResponse
    }

    func get(url: String, customHeaders: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        guard let requestUrl = URL(string: url) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        for (key, value) in defaultHeaders { request.setValue(value, forHTTPHeaderField: key) }
        for (key, value) in customHeaders { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await activeSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        return (data, httpResponse)
    }

    func streamDownload(url: String, customHeaders: [String: String] = [:], progressHandler: ((Double, Int64, Int64) -> Void)? = nil) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let requestUrl = URL(string: url) else {
                    continuation.finish(throwing: NetworkError.invalidURL)
                    return
                }
                var request = URLRequest(url: requestUrl)
                request.httpMethod = "GET"
                request.timeoutInterval = 0
                for (key, value) in defaultHeaders { request.setValue(value, forHTTPHeaderField: key) }
                for (key, value) in customHeaders { request.setValue(value, forHTTPHeaderField: key) }

                do {
                    let (bytes, response) = try await streamingSession.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: NetworkError.invalidResponse)
                        return
                    }
                    let totalBytes = httpResponse.expectedContentLength
                    var receivedBytes: Int64 = 0
                    for try await byte in bytes {
                        continuation.yield(byte)
                        receivedBytes += 1
                        if totalBytes > 0 {
                            let progress = Double(receivedBytes) / Double(totalBytes)
                            progressHandler?(progress, receivedBytes, totalBytes)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func download(url: String, to fileURL: URL, customHeaders: [String: String] = [:], progressHandler: ((Double) -> Void)? = nil) async throws {
        guard let requestUrl = URL(string: url) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        request.timeoutInterval = 0
        for (key, value) in defaultHeaders { request.setValue(value, forHTTPHeaderField: key) }
        for (key, value) in customHeaders { request.setValue(value, forHTTPHeaderField: key) }

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let (bytes, response) = try await streamingSession.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        let totalBytes = httpResponse.expectedContentLength
        var receivedBytes: Int64 = 0

        guard let outputStream = OutputStream(url: tmpURL, append: false) else { throw NetworkError.streamCreationFailed }
        outputStream.open()
        defer { outputStream.close() }

        var buffer = Data()
        buffer.reserveCapacity(65536)

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 65536 {
                buffer.withUnsafeBytes { ptr in
                    outputStream.write(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), maxLength: buffer.count)
                }
                buffer.removeAll(keepingCapacity: true)
            }
            receivedBytes += 1
            if totalBytes > 0 {
                let progress = Double(receivedBytes) / Double(totalBytes)
                progressHandler?(progress)
            }
        }

        if !buffer.isEmpty {
            buffer.withUnsafeBytes { ptr in
                outputStream.write(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), maxLength: buffer.count)
            }
        }

        try FileManager.default.moveItem(at: tmpURL, to: fileURL)
    }
}

extension NetworkService: URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: trust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case streamCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .streamCreationFailed: return "Failed to create output stream"
        }
    }
}
