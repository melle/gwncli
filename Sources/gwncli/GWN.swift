// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Combine
import Foundation
import FoundationExtensions

struct GWN {
    
    static func acquireSession(context: GwnContext) -> Publishers.Promise<GwnContext, GwnError> {
        guard let request = GrandstreamRequest.login(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME")).promise
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .map(\.session)
            .flatMap({ (token: String)  -> Publishers.Promise<GwnContext, GwnError> in
                context.sessionToken = token
                return Just<GwnContext>(context)
                    .mapError(absurd)
                    .promise
            })
            .promise {
                .failure(GwnError.emptyLoginResponse)
            }
    }
    
    static func getConfiguration(context: GwnContext) -> Publishers.Promise<GrandstreamConfiguration, GwnError> {
        guard let request = GrandstreamRequest.getConfig(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME")).promise
        }

        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GrandstreamConfigurationResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .map(\.result)
            .compactMap{ $0.first } // grab the first array element
            .promise {
                .failure(GwnError.emptyLoginResponse)
            }
        
    }
    
    static func deleteRule(context: GwnContext, ruleName: String) -> Publishers.Promise<Void, GwnError> {
        return getConfiguration(context: context)
            .flatMap { config in
                // only delete rules that exist :)
                guard config.bandwidthRules.contains(where: { $0.name == ruleName }) else {
                    return Publishers.Promise<Void, GwnError>(error: GwnError.ruleNotFound(ruleName))
                }
                
                // delete and confirm
                return deleteRuleWithoutCheck(context: context, ruleName: ruleName)
                    .flatMap { applyPendingChanges(url: context.url, session: context.session, token: context.sessionToken) }
                    .flatMap { confirmPendingChanges(url: context.url, session: context.session, token: context.sessionToken) }
            }
    }
}

extension GWN {
    
    static private func deleteRuleWithoutCheck(context: GwnContext, ruleName: String) -> Publishers.Promise<Void, GwnError> {
        guard let request = GrandstreamRequest.deleteRule(context: context, ruleName: ruleName).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME")).promise
        }
        
        return context.session
            .dataTaskPublisher(for: request)
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
