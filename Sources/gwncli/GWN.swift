// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import OpenCombineShim
import Foundation

struct GWN {
    private static var cancellables: Set<AnyCancellable> = .init()
    
    static func readAliases(context: GwnContext) -> Future<GwnContext, GwnError> {
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
        return Future { promise in
            promise(.success(context))
        }
    }

    static func acquireSession(context: GwnContext) -> Future<GwnContext, GwnError> {
        guard let request = GwnRequest.login(context: context).urlRequest else {
            return Future { promise in
                promise(.failure(GwnError.freeForm("FIXME \(#file):\(#line)")))
            }
        }
        
        return Future { promise in
            context.session
                .dataTaskPublisher(for: request)
                .map(\.data)
                .decode(type: LoginResponse.self, decoder: JSONDecoder())
                .mapError(GwnError.networkError)
                .map(\.session)
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        promise(.failure(error))
                    }
                }, receiveValue: { (token: String) in
                    context.sessionToken = token
                    promise(.success(context))
                })
                .store(in: &cancellables)
        }
            
    }
    
    static func getConfiguration(context: GwnContext) -> Future<GwnConfiguration, GwnError> {
        guard let request = GwnRequest.getConfig(context: context).urlRequest else {
            return Future { promise in
                promise(.failure(GwnError.freeForm("FIXME \(#file):\(#line)")))
            }
        }
        
        return Future { promise in
            context.session
                .dataTaskPublisher(for: request)
                .map(\.data)
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
    
    static func deleteRule(context: GwnContext, ruleName: String) -> AnyPublisher<GwnConfiguration, GwnError> {
        getConfiguration(context: context)
            .flatMap { config in
                // only delete rules that exist :)
                guard config.bandwidthRules.contains(where: { $0.name == ruleName }) else {
                    return Fail<GwnConfiguration, GwnError>(error: GwnError.ruleNotFound(ruleName))
                        .eraseToAnyPublisher()
                }
                
                // delete and confirm
                return deleteRuleWithoutCheck(context: context, ruleName: ruleName)
                    .flatMap { applyPendingChanges(context: context) }
                    .flatMap { confirmPendingChanges(context: context) }
                    .flatMap { getConfiguration(context: context) }
                    .eraseToAnyPublisher()
            }
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
        guard let request = GwnRequest.deleteRule(context: context, ruleName: ruleName).urlRequest else {
            return Fail<Void, GwnError>(error: GwnError.freeForm("FIXME \(#file):\(#line)"))
                .eraseToAnyPublisher()
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
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
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Set rule \(ruleName) failed: \($0)") }
            .eraseToAnyPublisher()
    }
    
    static private func applyPendingChanges(context: GwnContext) -> AnyPublisher<Void, GwnError> {
        guard let request = GwnRequest.apply(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)"))
                .eraseToAnyPublisher()
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: GwnResponse.self, decoder: JSONDecoder())
            .mapError(GwnError.networkError)
            .flatMap { evaluateResponse(response: $0, message: "Apply failed: \($0)") }
            .eraseToAnyPublisher()
    }
    
    static private func confirmPendingChanges(context: GwnContext) -> AnyPublisher<Void, GwnError> {
        guard let request = GwnRequest.confirm(context: context).urlRequest else {
            return Fail(error: GwnError.freeForm("FIXME \(#file):\(#line)"))
                .eraseToAnyPublisher()
        }
        
        return context.session
            .dataTaskPublisher(for: request)
            .map(\.data)
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
