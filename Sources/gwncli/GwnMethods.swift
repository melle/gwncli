// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Combine
import Foundation

struct GwnMethods {
    
    static func acquireSession(url: URL, user: String, password: String, session: URLSession) -> Publishers.Promise<String, GwnError> {
        var request =  URLRequest(url: url.appendingPathComponent("/ubus/session.login"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = """
                           {
                             "id": 3,
                             "jsonrpc": "2.0",
                             "method": "call",
                             "params": [
                               "00000000000000000000000000000000",
                               "session",
                               "login",
                               {
                                 "username": "\(user)",
                                 "password": "\(password)"
                               }
                             ]
                           }
                           """.data(using: .utf8)
        
        return session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .map(\.session)
            .promise {
                .failure(GwnError.emptyLoginResponse)
            }
    }
    
    
}
