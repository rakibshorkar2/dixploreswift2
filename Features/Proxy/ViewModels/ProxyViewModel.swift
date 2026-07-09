import Foundation
import Network
import Yams
import UIKit

@MainActor
final class ProxyViewModel: ObservableObject {
    static let shared = ProxyViewModel()

    @Published private(set) var proxies: [ProxyModel] = []
    @Published var isLoading = false
    @Published var testingProxyId: String?
    @Published var errorMessage: String?

    private let manager = ProxyManager.shared

    private init() {}

    var activeProxy: ProxyModel? {
        proxies.first { $0.isActive }
    }

    var testedProxies: [ProxyModel] {
        proxies.filter { $0.latencyMs != nil }
    }

    var untestedProxies: [ProxyModel] {
        proxies.filter { $0.latencyMs == nil }
    }

    var failedProxies: [ProxyModel] {
        proxies.filter { $0.latencyMs == -1 }
    }

    func load() async {
        isLoading = true
        await manager.load()
        proxies = manager.proxies
        isLoading = false
    }

    func refresh() async {
        proxies = manager.proxies
    }

    func addProxy(host: String, port: Int, username: String? = nil, password: String? = nil, protocolType: ProxyProtocol = .socsk5) async throws {
        let id = "\(Int64(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 0..<9999))"
        let proxy = ProxyModel(id: id, protocolType: protocolType, host: host, port: port, username: username, password: password)
        try await manager.addProxy(proxy)
        proxies = manager.proxies
    }

    func addProxyFromUri(_ uri: String) async throws {
        guard let proxy = ProxyModel.fromUri(uri) else {
            throw ProxyError.invalidUri
        }
        try await manager.addProxy(proxy)
        proxies = manager.proxies
    }

    func addProxies(_ newProxies: [ProxyModel]) async throws {
        try await manager.addProxies(newProxies)
        proxies = manager.proxies
    }

    func updateProxy(_ proxy: ProxyModel) async throws {
        try await manager.updateProxy(proxy)
        proxies = manager.proxies
    }

    func deleteProxy(_ id: String) async throws {
        try await manager.deleteProxy(id)
        proxies = manager.proxies
    }

    func toggleProxy(_ id: String, active: Bool) async throws {
        try await manager.toggleProxy(id, active: active)
        proxies = manager.proxies
    }

    func testLatency(for proxyId: String) async {
        guard let proxy = proxies.first(where: { $0.id == proxyId }) else { return }
        testingProxyId = proxyId
        let ms = await manager.testLatency(proxy)
        if let idx = proxies.firstIndex(where: { $0.id == proxyId }) {
            proxies[idx].latencyMs = ms
        }
        testingProxyId = nil
    }

    func testAllProxies() async {
        isLoading = true
        for i in proxies.indices {
            let ms = await manager.testLatency(proxies[i])
            proxies[i].latencyMs = ms
        }
        isLoading = false
    }

    func importFromYamlFile(url: URL) async throws {
        let data = try Data(contentsOf: url)
        guard let yamlStr = String(data: data, encoding: .utf8) else {
            throw ProxyError.invalidYaml
        }
        let imported = try parseYamlProxies(yamlStr)
        try await manager.addProxies(imported)
        proxies = manager.proxies
    }

    func importFromYamlString(_ yaml: String) async throws {
        let imported = try parseYamlProxies(yaml)
        try await manager.addProxies(imported)
        proxies = manager.proxies
    }

    private func parseYamlProxies(_ yamlStr: String) throws -> [ProxyModel] {
        guard let yaml = try Yams.load(yaml: yamlStr) as? [String: Any],
              let proxiesList = yaml["proxies"] as? [[String: Any]] else {
            throw ProxyError.invalidYamlStructure
        }

        var result: [ProxyModel] = []
        for item in proxiesList {
            let type = item["type"] as? String ?? "socks5"
            let server = item["server"] as? String ?? item["ip"] as? String ?? ""
            let portStr = item["port"] as? String ?? "1080"
            let port = Int(portStr) ?? 1080
            let user = item["username"] as? String ?? ""
            let pass = item["password"] as? String ?? ""
            if server.isEmpty { continue }

            let proto: ProxyProtocol
            switch type.lowercased() {
            case "socks5": proto = .socsk5
            case "socks4": proto = .socks4
            case "https": proto = .https
            default: proto = .http
            }

            let proxy = ProxyModel(
                id: "\(Int64(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 0..<9999))",
                protocolType: proto,
                host: server,
                port: port,
                username: user.isEmpty ? nil : user,
                password: pass.isEmpty ? nil : pass
            )
            result.append(proxy)
        }
        return result
    }

    func bulkImport(uris: [String]) async throws {
        let proxies = uris.compactMap { ProxyModel.fromUri($0) }
        guard !proxies.isEmpty else { throw ProxyError.invalidUri }
        try await addProxies(proxies)
    }
}

enum ProxyError: LocalizedError {
    case invalidUri
    case invalidYaml
    case invalidYamlStructure

    var errorDescription: String? {
        switch self {
        case .invalidUri: return "Invalid proxy URI format"
        case .invalidYaml: return "Invalid YAML file"
        case .invalidYamlStructure: return "Invalid YAML structure - expected proxies list"
        }
    }
}
