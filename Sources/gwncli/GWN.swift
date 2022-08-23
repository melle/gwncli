// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Combine
import Foundation
import FoundationExtensions

struct GWN {
    
    static func readAliases(context: GwnContext) -> Publishers.Promise<GwnContext, GwnError> {
        guard let url = context.aliasesFile,
              let aliases = try? String(contentsOf: url) else {
            return Just(context)
                .mapError(absurd)
                .promise
        }
        let lines = aliases.split(separator: "\n")
        let result = lines.compactMap({ line in
            let comps = line.components(separatedBy: .whitespaces)
            if let mac = comps.first, let alias = comps.last {
                return (mac, alias)
            }
            return nil
        }).reduce(into: Dictionary<String, String>()) { $0[$1.0] = $1.1 }
        
        context.aliases = GwnContext.Aliases(aliasMap: result)
        return Just(context)
            .mapError(absurd)
            .promise
    }

    static func acquireSession(context: GwnContext) -> Publishers.Promise<GwnContext, GwnError> {
        guard let request = GwnRequest.login(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)")).promise
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
    
    static func getConfiguration(context: GwnContext) -> Publishers.Promise<GwnConfiguration, GwnError> {
        guard let request = GwnRequest.getConfig(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)")).promise
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GwnConfigurationResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .map(\.result)
            .compactMap{ $0.first } // grab the first array element
            .promise {
                .failure(GwnError.emptyLoginResponse)
            }
    }
    
    static func deleteRule(context: GwnContext, ruleName: String) -> Publishers.Promise<GwnConfiguration, GwnError> {
        getConfiguration(context: context)
            .flatMap { config in
                // only delete rules that exist :)
                guard config.bandwidthRules.contains(where: { $0.name == ruleName }) else {
                    return Publishers.Promise<GwnConfiguration, GwnError>(error: GwnError.ruleNotFound(ruleName))
                }
                
                // delete and confirm
                return deleteRuleWithoutCheck(context: context, ruleName: ruleName)
                    .flatMap { applyPendingChanges(context: context) }
                    .flatMap { confirmPendingChanges(context: context) }
                    .flatMap { getConfiguration(context: context) }
            }
    }
    
    static func addOrUpdateRule(context: GwnContext, mac: String, ssidId: String, drate: String, urate: String) -> Publishers.Promise<GwnConfiguration, GwnError> {
        
        return getConfiguration(context: context)
            .flatMap { config in
                // check if rule for SSID-ID and MAC exist? -> Add, if nothing is found
                guard let existingRule = config.bandwidthRules.first(where: {
                    $0.id.localizedLowercase == mac.localizedLowercase &&
                    $0.ssidId == ssidId
                }) else {
                    return addRule(context: context,
                                   ruleName: config.nextBandwidthRuleName,
                                   mac: mac,
                                   ssid: ssidId,
                                   drate: drate,
                                   urate: urate)
                    .flatMap { applyPendingChanges(context: context) }
                    .flatMap { confirmPendingChanges(context: context) }
                    .flatMap { getConfiguration(context: context) }
                }
                
                // rule exists? -> update
                return updateRule(context: context,
                                  ruleName: existingRule.name,
                                  mac: mac,
                                  ssid: ssidId,
                                  drate: drate,
                                  urate: urate)
                .flatMap { applyPendingChanges(context: context) }
                .flatMap { confirmPendingChanges(context: context) }
                .flatMap { getConfiguration(context: context) }
            }
    }
}

extension GWN {
    
    static private func deleteRuleWithoutCheck(context: GwnContext, ruleName: String) -> Publishers.Promise<Void, GwnError> {
        guard let request = GwnRequest.deleteRule(context: context, ruleName: ruleName).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)")).promise
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Delete rule \(ruleName) failed: \($0)") }
            .promise {
                // in case of an empty promise
                .failure(GwnError.freeForm("Error \(#file):\(#line)"))
            }
    }
    
    static func addRule(context: GwnContext,
                        ruleName: String,
                        mac: String,
                        ssid: String,
                        drate: String,
                        urate: String) -> Publishers.Promise<Void, GwnError> {
        guard let request = GwnRequest.addRule(context: context,
                                               ruleName: ruleName,
                                               id: mac,
                                               idType: "mac",
                                               urate: urate,
                                               drate: drate,
                                               ssidId: ssid).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)")).promise
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Addd rule \(ruleName) failed: \($0)") }
            .promise {
                // in case of an empty promise
                .failure(GwnError.freeForm("Error \(#file):\(#line)"))
            }
    }
    
    
    static func updateRule(context: GwnContext,
                           ruleName: String,
                           mac: String,
                           ssid: String,
                           drate: String,
                           urate: String) -> Publishers.Promise<Void, GwnError> {
        guard let request = GwnRequest.setRule(context: context,
                                               ruleName: ruleName,
                                               id: mac,
                                               idType: "mac",
                                               urate: urate,
                                               drate: drate,
                                               ssidId: ssid).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)")).promise
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Set rule \(ruleName) failed: \($0)") }
            .promise {
                // in case of an empty promise
                .failure(GwnError.freeForm("Error \(#file):\(#line)"))
            }
    }
    
    static private func applyPendingChanges(context: GwnContext) -> Publishers.Promise<Void, GwnError> {
        guard let request = GwnRequest.apply(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)")).promise
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Apply failed: \($0)") }
            .promise {
                // in case of an empty promise
                .failure(GwnError.freeForm("Error \(#file):\(#line)"))
            }
    }
    
    static private func confirmPendingChanges(context: GwnContext) -> Publishers.Promise<Void, GwnError> {
        guard let request = GwnRequest.confirm(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)")).promise
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Confirm failed: \($0)") }
            .promise {
                // in case of an empty promise
                .failure(GwnError.freeForm("Error \(#file):\(#line)"))
            }
    }
    
    private static func evaluateResponse(response: GwnResponse, message: String) -> Publishers.Promise<Void, GwnError> {
        guard response.isSuccess else {
            return Fail(error: GwnError.freeForm(message))
                .promise
        }
        
        return Just(())
            .mapError(absurd)
            .promise
    }
}
