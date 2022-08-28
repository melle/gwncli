
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Grandstream APs use self signed certificates, we have to ignore the certificate warnings.
/// This is bad, but better than plain http, also there is no real solution for secure local networking).
class TlsWarningsIgnoringUrlSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!) )
    }
}
