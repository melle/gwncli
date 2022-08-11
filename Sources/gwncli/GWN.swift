// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Combine
import Foundation
import FoundationExtensions

struct GWN {
    
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
    
    static func getConfiguration(url: URL, session: URLSession, token: String) -> Publishers.Promise<GrandstreamConfiguration, GwnError> {
        var request =  URLRequest(url: url.appendingPathComponent("/ubus/uci.get"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = """
                           [
                             {
                               "id": 3306,
                               "jsonrpc": "2.0",
                               "method": "call",
                               "params": [
                                 "\(token)",
                                 "uci",
                                 "get",
                                 {
                                   "config": "grandstream"
                                 }
                               ]
                             }
                           ]
                           """.data(using: .utf8)
        
        return session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [GrandstreamConfigurationResponse].self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .compactMap(\.first) // [GrandstreamConfigurationResponse] -> GrandstreamConfigurationResponse
            .map(\.result)
            .compactMap{ $0.first } // grab the first array element
            .promise {
                .failure(GwnError.emptyLoginResponse)
            }
        
    }
    
    static func deleteRule(url: URL, session: URLSession, token: String, ruleName: String) -> Publishers.Promise<Void, GwnError> {
        return getConfiguration(url: url, session: session, token: token)
            .flatMap { config in
                // only delete rules that exist :)
                guard config.bandwidthRules.contains(where: { $0.name == ruleName }) else {
                    return Publishers.Promise<Void, GwnError>(error: GwnError.ruleNotFound(ruleName))
                }
                
                // delete and confirm
                return deleteRuleWithoutCheck(url: url, session: session, token: token, ruleName: ruleName)
                    .flatMap { applyPendingChanges(url: url, session: session, token: token) }
                    .flatMap { confirmPendingChanges(url: url, session: session, token: token) }
            }
    }
}

extension GWN {
    
    static private func deleteRuleWithoutCheck(url: URL, session: URLSession, token: String, ruleName: String) -> Publishers.Promise<Void, GwnError> {
        var request =  URLRequest(url: url.appendingPathComponent("/ubus/uci.delete"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = """
                           {
                             "id": 42,
                             "jsonrpc": "2.0",
                             "method": "call",
                             "params": [
                               "\(token)",
                               "uci",
                               "delete",
                               {
                                 "config": "grandstream",
                                 "section": "\(ruleName)"
                               }
                             ]
                           }
                           """.data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .mapError(GwnError.networkError)
            .map(\.data)
            .flatMap { (data: Data) -> Publishers.Promise<Void, GwnError> in
                print("deleteRuleWithoutCheck: \(String(data: data, encoding: .utf8))")
                // FIXME: check for error from backend
                return Just(())
                    .mapError(absurd)
                    .promise
            }
            .promise {
                // in case of an empty promise
                .failure(GwnError.freeForm("bar"))
            }
    }

    static private func applyPendingChanges(url: URL, session: URLSession, token: String) -> Publishers.Promise<Void, GwnError> {
        var request =  URLRequest(url: url.appendingPathComponent("/ubus/uci.apply"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = """
                           {
                             "id": 43,
                             "jsonrpc": "2.0",
                             "method": "call",
                             "params": [
                               "\(token)",
                               "uci",
                               "apply",
                               {
                                 "timeout": 10,
                                 "rollback": true
                               }
                             ]
                           }
                           """.data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .mapError(GwnError.networkError)
            .map(\.data)
            .flatMap { (data: Data) -> Publishers.Promise<Void, GwnError> in
                print("applyPendingChanges: \(String(data: data, encoding: .utf8))")
                // FIXME: check for error from backend

                return Just(())
                    .mapError(absurd)
                    .promise
            }
            .promise {
                // in case of an empty promise
                .failure(GwnError.freeForm("bar"))
            }
    }
    
    static private func confirmPendingChanges(url: URL, session: URLSession, token: String) -> Publishers.Promise<Void, GwnError> {
        var request =  URLRequest(url: url.appendingPathComponent("/ubus/uci.confirm"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = """
                           {
                             "id": 55,
                             "jsonrpc": "2.0",
                             "method": "call",
                             "params": [
                               "\(token)",
                               "uci",
                               "confirm",
                               {}
                             ]
                           }
                           """.data(using: .utf8)
        
        return session.dataTaskPublisher(for: request)
            .mapError(GwnError.networkError)
            .map(\.data)
            .flatMap { (data: Data) -> Publishers.Promise<Void, GwnError> in
                print("confirmPendingChanges: \(String(data: data, encoding: .utf8))")
                // FIXME: check for error from backend

                return Just(())
                    .mapError(absurd)
                    .promise
            }
            .promise {
                // in case of an empty promise
                .failure(GwnError.freeForm("bar"))
            }
    }
}
