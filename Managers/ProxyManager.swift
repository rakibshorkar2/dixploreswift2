import Foundation
import Network

@MainActor
final class ProxyManager: ObservableObject {
    static let shared = ProxyManager()

    @Published private(set) var proxies: [ProxyModel] = []

    private init() {}

    var activeProxy: ProxyModel? {
        proxies.first { $0.isActive }
    }

    func load() async {
        try? DatabaseService.shared.createProxiesTable()
        if var loaded = try? await DatabaseService.shared.getProxies(), !loaded.isEmpty {
            proxies = loaded
            applyActiveProxyToSessions()
            return
        }

        if let imported = await importFromYaml() {
            proxies = imported
            for proxy in imported {
                try? await DatabaseService.shared.insertProxy(proxy)
            }
            applyActiveProxyToSessions()
        }
    }

    private func importFromYaml() async -> [ProxyModel]? {
        guard let url = Bundle.main.url(forResource: "bypassempire", withExtension: "yaml"),
              let data = try? Data(contentsOf: url),
              let yamlStr = String(data: data, encoding: .utf8) else { return nil }

        var result: [ProxyModel] = []
        let lines = yamlStr.components(separatedBy: "\n")
        var inProxies = false
        var currentProxy: [String: String] = [:]
        var count = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "proxies:" { inProxies = true; continue }
            guard inProxies else { continue }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("  - ") {
                if !currentProxy.isEmpty, let model = buildProxy(from: currentProxy) {
                    model.isActive = count == 6
                    result.append(model)
                    count += 1
                }
                currentProxy = [:]
                let kv = trimmed.replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                if let colonIdx = kv.firstIndex(of: ":"), colonIdx != kv.endIndex {
                    let key = String(kv[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                    let val = String(kv[kv.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    currentProxy[key] = val
                }
            } else if !currentProxy.isEmpty, let colonIdx = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let val = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                currentProxy[key] = val
            }
        }

        if !currentProxy.isEmpty, let model = buildProxy(from: currentProxy) {
            result.append(model)
        }

        return result.isEmpty ? nil : result
    }

    private func buildProxy(from dict: [String: String]) -> ProxyModel? {
        guard let server = dict["server"], !server.isEmpty else { return nil }
        let type = dict["type"] ?? "socks5"
        let portStr = dict["port"] ?? "1080"
        let port = Int(portStr) ?? 1080
        let user = dict["username"] ?? ""
        let pass = dict["password"] ?? ""

        let proto: ProxyProtocol
        switch type.lowercased() {
        case "socks5": proto = .socsk5
        case "socks4": proto = .socks4
        case "https": proto = .https
        default: proto = .http
        }

        return ProxyModel(
            id: "\(Date().timeIntervalSince1970)_\(Int.random(in: 0..<1000))",
            protocolType: proto,
            host: server,
            port: port,
            username: user.isEmpty ? nil : user,
            password: pass.isEmpty ? nil : pass
        )
    }

    func addProxy(_ proxy: ProxyModel) async throws {
        try await DatabaseService.shared.insertProxy(proxy)
        if var loaded = try? await DatabaseService.shared.getProxies() {
            proxies = loaded
            applyActiveProxyToSessions()
        }
    }

    func addProxies(_ newProxies: [ProxyModel]) async throws {
        for proxy in newProxies {
            try await DatabaseService.shared.insertProxy(proxy)
        }
        if var loaded = try? await DatabaseService.shared.getProxies() {
            proxies = loaded
            applyActiveProxyToSessions()
        }
    }

    func updateProxy(_ proxy: ProxyModel) async throws {
        try await DatabaseService.shared.updateProxy(proxy)
        if let idx = proxies.firstIndex(where: { $0.id == proxy.id }) {
            proxies[idx] = proxy
            applyActiveProxyToSessions()
        }
    }

    func deleteProxy(_ id: String) async throws {
        try await DatabaseService.shared.deleteProxy(id)
        proxies.removeAll { $0.id == id }
        applyActiveProxyToSessions()
    }

    func toggleProxy(_ id: String, active: Bool) async throws {
        if active {
            try await DatabaseService.shared.deactivateAllProxies()
        }
        try await DatabaseService.shared.updateProxy(ProxyModel(
            id: id,
            protocolType: proxies.first(where: { $0.id == id })?.protocolType ?? .http,
            host: proxies.first(where: { $0.id == id })?.host ?? "",
            port: proxies.first(where: { $0.id == id })?.port ?? 1080,
            username: proxies.first(where: { $0.id == id })?.username,
            password: proxies.first(where: { $0.id == id })?.password,
            isActive: active
        ))
        if var loaded = try? await DatabaseService.shared.getProxies() {
            proxies = loaded
            applyActiveProxyToSessions()
        }
    }

    func testLatency(_ proxy: ProxyModel) async -> Int {
        let start = Date()
        do {
            let connection = NWConnection(host: NWEndpoint.Host(proxy.host), port: NWEndpoint.Port(rawValue: UInt16(proxy.port))!, using: .tcp)
            return try await withCheckedThrowingContinuation { continuation in
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        let ms = Int(Date().timeIntervalSince(start) * 1000)
                        connection.cancel()
                        continuation.resume(returning: ms)
                    case .failed, .cancelled:
                        continuation.resume(returning: -1)
                    default:
                        break
                    }
                }
                connection.start(queue: .global(qos: .background))
            }
        } catch {
            return -1
        }
    }

    func testAllProxies() async {
        for i in proxies.indices {
            let ms = await testLatency(proxies[i])
            proxies[i].latencyMs = ms
        }
    }

    func applyActiveProxyToSessions() {
        let proxy = activeProxy
        URLSessionConfiguration.default.connectionProxyDictionary = nil

        guard let proxy = proxy else {
            DownloadManager.shared.refreshSessionsForProxyChange()
            return
        }

        var proxyDict: [AnyHashable: Any] = [:]
        switch proxy.protocolType {
        case .http:
            proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
            proxyDict[kCFNetworkProxiesHTTPProxy as String] = proxy.host
            proxyDict[kCFNetworkProxiesHTTPPort as String] = proxy.port
        case .https:
            proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
            proxyDict[kCFNetworkProxiesHTTPSProxy as String] = proxy.host
            proxyDict[kCFNetworkProxiesHTTPSPort as String] = proxy.port
        case .socsk5, .socks4:
            proxyDict[kCFNetworkProxiesSOCKSEnable as String] = 1
            proxyDict[kCFNetworkProxiesSOCKSProxy as String] = proxy.host
            proxyDict[kCFNetworkProxiesSOCKSPort as String] = proxy.port
        }
        if let user = proxy.username, !user.isEmpty {
            proxyDict[kCFProxyUsernameKey as String] = user
            proxyDict[kCFProxyPasswordKey as String] = proxy.password ?? ""
        }
        URLSessionConfiguration.default.connectionProxyDictionary = proxyDict

        DownloadManager.shared.refreshSessionsForProxyChange()
    }
}
