import Foundation

enum ProxyProtocol: Int, Codable {
    case socsk5, socks4, http, https

    var label: String {
        switch self {
        case .socsk5: return "SOCKS5"
        case .socks4: return "SOCKS4"
        case .http: return "HTTP"
        case .https: return "HTTPS"
        }
    }
}

struct ProxyModel: Identifiable, Codable {
    let id: String
    var protocolType: ProxyProtocol
    var host: String
    var port: Int
    var username: String?
    var password: String?
    var isActive: Bool
    var latencyMs: Int?

    init(
        id: String,
        protocolType: ProxyProtocol,
        host: String,
        port: Int,
        username: String? = nil,
        password: String? = nil,
        isActive: Bool = false,
        latencyMs: Int? = nil
    ) {
        self.id = id
        self.protocolType = protocolType
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.isActive = isActive
        self.latencyMs = latencyMs
    }

    var uri: String {
        var result = "\(protocolType.label.lowercased())://"
        if let user = username, !user.isEmpty {
            result += "\(user):\(password ?? "")@"
        }
        result += "\(host):\(port)"
        return result
    }

    var displayUri: String {
        var result = "\(protocolType.label)://"
        if let user = username, !user.isEmpty {
            result += "\(user):***@"
        }
        result += "\(host):\(port)"
        return result
    }

    static func fromUri(_ raw: String) -> ProxyModel? {
        var sanitized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        if sanitized.hasSuffix("/") { sanitized = String(sanitized.dropLast()) }

        guard let url = URL(string: sanitized) else { return nil }
        let proto: ProxyProtocol
        switch url.scheme?.lowercased() {
        case "socks5": proto = .socsk5
        case "socks4": proto = .socks4
        case "https": proto = .https
        default: proto = .http
        }
        let userInfo = url.userInfo(percentEncoded: false)
        let user = userInfo.flatMap { $0.contains(":") ? $0.components(separatedBy: ":").first : ($0.isEmpty ? nil : $0) }
        let pass = userInfo.flatMap { $0.contains(":") ? $0.components(separatedBy: ":").dropFirst().joined(separator: ":") : nil }
        return ProxyModel(
            id: "\(Date().timeIntervalSince1970)_\(Int.random(in: 0..<1000))",
            protocolType: proto,
            host: url.host ?? "",
            port: url.port ?? 1080,
            username: user,
            password: pass?.isEmpty == true ? nil : pass
        )
    }

    init(from dict: [String: Any]) {
        self.init(
            id: dict["id"] as? String ?? UUID().uuidString,
            protocolType: ProxyProtocol(rawValue: dict["protocol"] as? Int ?? 0) ?? .http,
            host: dict["host"] as? String ?? "",
            port: dict["port"] as? Int ?? 1080,
            username: dict["username"] as? String,
            password: dict["password"] as? String,
            isActive: (dict["isActive"] as? Int ?? 0) == 1,
            latencyMs: dict["latencyMs"] as? Int
        )
    }

    func toDictionary() -> [String: Any] {
        [
            "id": id,
            "protocol": protocolType.rawValue,
            "host": host,
            "port": port,
            "username": username as Any,
            "password": password as Any,
            "isActive": isActive ? 1 : 0,
        ]
    }
}
