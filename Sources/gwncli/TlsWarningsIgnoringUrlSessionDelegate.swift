
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if !os(Linux)

/// Grandstream APs use self signed certificates, we have to ignore the certificate warnings.
/// This is bad, but better than plain http, also there is no real solution for secure local networking).
///
/// Unfortunately URLCredential(trust:) is unavailable on Linux. In order to communicate to a
/// Grandstream AP with it's self-signed certificate, you have to setup a reverse-proxy like nginx with
/// the option `proxy_ssl_verify off;` and let gwncli talk to that proxy.
final class TlsWarningsIgnoringUrlSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    nonisolated func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!) )
    }
}

#endif
