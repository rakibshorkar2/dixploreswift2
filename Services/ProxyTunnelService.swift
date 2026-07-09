import Foundation
import Network

@MainActor
final class ProxyTunnelService {
    static let shared = ProxyTunnelService()

    private var listener: NWListener?
    private(set) var port: UInt16 = 8080
    private var isRunning = false

    private static let queue = DispatchQueue(label: "com.dirxplore.proxytunnel", qos: .userInitiated)

    private init() {}

    func start() async throws {
        guard !isRunning else { return }
        listener = try NWListener(using: .tcp, on: .loopback)
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener?.stateUpdateHandler = { [weak self] state in
            if case .ready = state, let port = self?.listener?.port?.rawValue {
                self?.port = port
                self?.isRunning = true
            }
        }
        listener?.start(queue: Self.queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    func tunnelUrl(for targetUrl: String) -> String {
        guard isRunning else { return targetUrl }
        let filename = URL(string: targetUrl)?.lastPathComponent ?? "media.mp4"
        if filename.isEmpty || !filename.contains(".") {
            return "http://127.0.0.1:\(port)/stream/media.mp4?url=\(targetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetUrl)"
        }
        let encoded = targetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetUrl
        return "http://127.0.0.1:\(port)/stream/\(filename)?url=\(encoded)"
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: Self.queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, error == nil else {
                connection.cancel()
                return
            }

            guard let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            self.processRequest(request, connection: connection)
        }
    }

    private func processRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(statusCode: 400, body: "Bad Request", connection: connection)
            return
        }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(statusCode: 400, body: "Bad Request", connection: connection)
            return
        }

        guard let urlStr = parts[safe: 1],
              let components = URLComponents(string: urlStr),
              let targetUrl = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let decodedTarget = targetUrl.removingPercentEncoding ?? targetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetUrl,
              let sourceUrl = URL(string: decodedTarget) else {
            sendResponse(statusCode: 400, body: "Missing target URL", connection: connection)
            return
        }

        let rangeHeader = lines.first(where: { $0.lowercased().hasPrefix("range:") })?
            .components(separatedBy: ":").dropFirst().joined().trimmingCharacters(in: .whitespaces)

        Task {
            await self.fetchAndStream(sourceUrl: sourceUrl, rangeHeader: rangeHeader, connection: connection)
        }
    }

    private func fetchAndStream(sourceUrl: URL, rangeHeader: String?, connection: NWConnection) async {
        var request = URLRequest(url: sourceUrl)
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        if let range = rangeHeader {
            request.setValue(range, forHTTPHeaderField: "Range")
        }

        do {
            let session = URLSession(configuration: .ephemeral)
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                sendResponse(statusCode: 500, body: "Invalid response", connection: connection)
                return
            }

            var headers = "HTTP/1.1 \(httpResponse.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))\r\n"
            for (key, value) in httpResponse.allHeaderFields {
                let keyLower = (key as? String ?? "").lowercased()
                if keyLower == "transfer-encoding" { continue }
                headers += "\(key): \(value)\r\n"
            }
            headers += "\r\n"

            guard let headerData = headers.data(using: .utf8) else {
                sendResponse(statusCode: 500, body: "Header encoding failed", connection: connection)
                return
            }

            connection.send(content: headerData, completion: .contentProcessed({ _ in
                Task {
                    do {
                        for try await chunk in bytes {
                            let data = Data(chunk)
                            connection.send(content: data, completion: .contentProcessed({ _ in }))
                        }
                        connection.send(content: nil, completion: .contentProcessed({ _ in
                            connection.cancel()
                        }))
                    } catch {
                        connection.cancel()
                    }
                }
            }))
        } catch {
            sendResponse(statusCode: 500, body: "Proxy error: \(error.localizedDescription)", connection: connection)
        }
    }

    private func sendResponse(statusCode: Int, body: String, connection: NWConnection) {
        let response = "HTTP/1.1 \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))\r\nContent-Length: \(body.utf8.count)\r\n\r\n\(body)"
        guard let data = response.data(using: .utf8) else {
            connection.cancel()
            return
        }
        connection.send(content: data, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
