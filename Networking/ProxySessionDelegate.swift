import Foundation

final class ProxySessionDelegate: NSObject {
    private let proxyHost: String
    private let proxyPort: Int
    private let proxyUsername: String?
    private let proxyPassword: String?

    init(host: String, port: Int, username: String? = nil, password: String? = nil) {
        self.proxyHost = host
        self.proxyPort = port
        self.proxyUsername = username
        self.proxyPassword = password
        super.init()
    }

    func makeSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        var proxyDict: [AnyHashable: Any] = [:]
        proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
        proxyDict[kCFNetworkProxiesHTTPProxy as String] = proxyHost
        proxyDict[kCFNetworkProxiesHTTPPort as String] = proxyPort
        proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
        proxyDict[kCFNetworkProxiesHTTPSProxy as String] = proxyHost
        proxyDict[kCFNetworkProxiesHTTPSPort as String] = proxyPort
        proxyDict[kCFNetworkProxiesSOCKSEnable as String] = 1
        proxyDict[kCFNetworkProxiesSOCKSProxy as String] = proxyHost
        proxyDict[kCFNetworkProxiesSOCKSPort as String] = proxyPort
        if let user = proxyUsername, !user.isEmpty {
            proxyDict[kCFProxyUsernameKey as String] = user
            proxyDict[kCFProxyPasswordKey as String] = proxyPassword ?? ""
        }
        config.connectionProxyDictionary = proxyDict
        return config
    }
}

extension ProxySessionDelegate: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPProxy {
            if let user = proxyUsername, let pass = proxyPassword {
                let credential = URLCredential(user: user, password: pass, persistence: .forSession)
                completionHandler(.useCredential, credential)
                return
            }
        }
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
}
