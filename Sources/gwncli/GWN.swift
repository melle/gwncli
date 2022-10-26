// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import OpenCombineShim
import Foundation

struct GWN {
    private static var cancellables: Set<AnyCancellable> = .init()
    
    static func readAliases(context: GwnContext) -> Future<GwnContext, GwnError> {
        context.log {"[gwncli] \(#function)"}
        guard let url = context.aliasesFile,
              let aliases = try? String(contentsOf: url) else {
            return Future { promise in
                promise(.success(context))
            }
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
        context.log {"[gwncli] \(#function) - found \(context.aliases.aliasMap.count) aliases"}
        return Future { promise in
            promise(.success(context))
        }
    }

    static func acquireSession(context: GwnContext) -> Future<GwnContext, GwnError> {
        context.log {"[gwncli] \(#function)"}
        guard let request = GwnRequest.login(context: context).urlRequest else {
            return Future { promise in
                promise(.failure(GwnError.freeForm("FIXME \(#file):\(#line)")))
            }
        }
        
        return Future { promise in
            context.session
                .dataTaskPublisher(for: request)
                .map(\.data)
                .handleEvents(receiveOutput: { data in
                    context.log {"[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")"}
                })
                .decode(type: LoginResponse.self, decoder: JSONDecoder())
                .mapError(GwnError.networkError)
                .map(\.session)
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        promise(.failure(error))
                    }
                }, receiveValue: { (token: String) in
                    context.log {"[gwncli] \(#function) - got token: \(token)"}
                    context.sessionToken = token
                    promise(.success(context))
                })
                .store(in: &cancellables)
        }
            
    }
    
    static func getConfiguration(context: GwnContext) -> Future<GwnConfiguration, GwnError> {
        context.log {"[gwncli] \(#function)" }
        guard let request = GwnRequest.getConfig(context: context).urlRequest else {
            return Future { promise in
                promise(.failure(GwnError.freeForm("FIXME \(#file):\(#line)")))
            }
        }
        
        return Future { promise in
            context.session
                .dataTaskPublisher(for: request)
                .map(\.data)
                .handleEvents(receiveOutput: { data in
                    context.log {"[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")"}
                })
                .decode(type: GwnConfigurationResponse.self, decoder: JSONDecoder())
                .mapError(GwnError.networkError)
                .map(\.result)
                .compactMap{ $0.first } // grab the first array element
                .sink { completion in
                    if case let .failure(error) = completion {
                        promise(.failure(error))
                    }
                } receiveValue: { gwnConfiguration in
                    promise(.success(gwnConfiguration))
                }
                .store(in: &cancellables)
        }
    }
    
    static func deleteRule(context: GwnContext, ruleName: String?, macAddress: String?) -> AnyPublisher<GwnConfiguration, GwnError> {
        context.log {"[gwncli] \(#function) \(ruleName.map { "ruleName: " + $0 + " " } ?? "") \(macAddress.map { "macAddress: " + $0 + " " } ?? "")"}
        return getConfiguration(context: context)
            .flatMap { (config: GwnConfiguration) -> AnyPublisher<BandwidthRule, GwnError> in
                // only delete rules that exist :)
                let matchingRules: [BandwidthRule] =  config.bandwidthRules.filter({
                    $0.name == ruleName || $0.id == macAddress
                })
                if matchingRules.count == 0 {
                    return Fail<BandwidthRule, GwnError>(error: GwnError.ruleNotFound(ruleName ?? macAddress ?? ""))
                        .eraseToAnyPublisher()
                }
                
                return matchingRules
                    .publisher
                    .setFailureType(to: GwnError.self)
                    .eraseToAnyPublisher()
            }
            .flatMap { (rule: BandwidthRule) -> AnyPublisher<Void, GwnError> in deleteRuleWithoutCheck(context: context, ruleName: rule.name) }
            .last() // [Void] -> Void
            .flatMap { applyPendingChanges(context: context) }
            .flatMap { confirmPendingChanges(context: context) }
            .flatMap { getConfiguration(context: context) }
            .eraseToAnyPublisher()
    }
    
    static func addOrUpdateRule(context: GwnContext, mac: String, ssidId: String, drate: String, urate: String) -> AnyPublisher<GwnConfiguration, GwnError> {
        
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
            .eraseToAnyPublisher()
    }
}

extension GWN {
    
    static private func deleteRuleWithoutCheck(context: GwnContext, ruleName: String) -> AnyPublisher<Void, GwnError> {
        context.log {"[gwncli] \(#function) ruleName: \(ruleName)"}
        guard let request = GwnRequest.deleteRule(context: context, ruleName: ruleName).urlRequest else {
            return Fail<Void, GwnError>(error: GwnError.freeForm("FIXME \(#file):\(#line)"))
                .eraseToAnyPublisher()
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                context.log {"[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")"}
            })
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Delete rule \(ruleName) failed: \($0)") }
            .eraseToAnyPublisher()
    }
    
    static func addRule(context: GwnContext,
                        ruleName: String,
                        mac: String,
                        ssid: String,
                        drate: String,
                        urate: String) -> AnyPublisher<Void, GwnError> {
        context.log {"[gwncli] \(#function) ruleName: \(ruleName) mac: \(mac) ssid: \(ssid) drate: \(drate) urate: \(urate)"}
        guard let request = GwnRequest.addRule(context: context,
                                               ruleName: ruleName,
                                               id: mac,
                                               idType: "mac",
                                               urate: urate,
                                               drate: drate,
                                               ssidId: ssid).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)"))
                .eraseToAnyPublisher()
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                context.log {"[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")"}
            })
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Addd rule \(ruleName) failed: \($0)") }
            .eraseToAnyPublisher()
    }
    
    
    static func updateRule(context: GwnContext,
                           ruleName: String,
                           mac: String,
                           ssid: String,
                           drate: String,
                           urate: String) -> AnyPublisher<Void, GwnError> {
        context.log {"[gwncli] \(#function) context: \(context) ruleName: \(ruleName) mac: \(mac) ssid: \(ssid) drate: \(drate) urate: \(urate)"}
        guard let request = GwnRequest.setRule(context: context,
                                               ruleName: ruleName,
                                               id: mac,
                                               idType: "mac",
                                               urate: urate,
                                               drate: drate,
                                               ssidId: ssid).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)"))
                .eraseToAnyPublisher()
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                context.log {"[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")"}
            })
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Set rule \(ruleName) failed: \($0)") }
            .eraseToAnyPublisher()
    }
    
    static private func applyPendingChanges(context: GwnContext) -> AnyPublisher<Void, GwnError> {
        context.log {"[gwncli] \(#function)"}
        guard let request = GwnRequest.apply(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)"))
                .eraseToAnyPublisher()
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                context.log {"[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")"}
            })
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Apply failed: \($0)") }
            .eraseToAnyPublisher()
    }
    
    static private func confirmPendingChanges(context: GwnContext) -> AnyPublisher<Void, GwnError> {
        context.log {"[gwncli] \(#function)"}
        guard let request = GwnRequest.confirm(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)"))
                .eraseToAnyPublisher()
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                context.log {"[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")"}
            })
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Confirm failed: \($0)") }
            .eraseToAnyPublisher()
    }
    
    private static func evaluateResponse(response: GwnResponse, message: String) -> AnyPublisher<Void, GwnError> {
        guard response.isSuccess else {
            return Fail(error: GwnError.freeForm(message))
                .eraseToAnyPublisher()
        }
        
        return Just<Void>(())
            .setFailureType(to: GwnError.self)
            .eraseToAnyPublisher()
    }
}
