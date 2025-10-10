// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

struct GWN {
    
    static func readAliases(context: GwnContext) async throws -> GwnContext {
        context.info("[gwncli] \(#function)")
        guard let url = context.aliasesFile,
              let aliases = try? String(contentsOf: url) else {
            return context
        }
        let lines = aliases.split(separator: "\n")
        let result = lines.compactMap({ line in
            let comps = line.components(separatedBy: .whitespaces)
            if let mac = comps.first, let alias = comps.last {
                return (mac.lowercased(), alias)
            }
            return nil
        }).reduce(into: Dictionary<String, String>()) { $0[$1.0] = $1.1 }
        
        let newAliases = GwnContext.Aliases(aliasMap: result)
        let updatedContext = context.withAliases(newAliases)
        updatedContext.info("[gwncli] \(#function) - found \(newAliases.aliasMap.count) aliases")
        return updatedContext
    }

    static func acquireSession(context: GwnContext) async throws -> GwnContext {
        context.info("[gwncli] \(#function)")
        guard let request = GwnRequest.login(context: context).urlRequest else {
            throw GwnError.freeForm("Failed to create login request")
        }
        
        let (data, _) = try await context.session.data(for: request)
        context.debug("[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")")
        
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)
        let token = response.session
        
        let updatedContext = context.withSessionToken(token)
        updatedContext.info("[gwncli] \(#function) - got token: \(token)")
        return updatedContext
    }
    
    static func getConfiguration(context: GwnContext) async throws -> GwnConfiguration {
        context.info("[gwncli] \(#function)")
        guard let request = GwnRequest.getConfig(context: context).urlRequest else {
            throw GwnError.freeForm("Failed to create getConfig request")
        }
        
        let (data, _) = try await context.session.data(for: request)
        context.debug("[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")")
        
        let response = try JSONDecoder().decode(GwnConfigurationResponse.self, from: data)
        guard let configuration = response.result.first else {
            throw GwnError.freeForm("No configuration found in response")
        }
        return configuration
    }
    
    static func deleteRule(context: GwnContext, ruleName: String?, macAddress: String?) async throws -> GwnConfiguration {
        context.info("[gwncli] \(#function) \(ruleName.map { "ruleName: " + $0 + " " } ?? "") \(macAddress.map { "macAddress: " + $0 + " " } ?? "")")
        
        let config = try await getConfiguration(context: context)
        
        // only delete rules that exist
        let matchingRules = config.bandwidthRules.filter {
            $0.name == ruleName || $0.id == macAddress
        }
        
        guard !matchingRules.isEmpty else {
            throw GwnError.ruleNotFound(ruleName ?? macAddress ?? "")
        }
        
        // Delete each matching rule
        for rule in matchingRules {
            try await deleteRuleWithoutCheck(context: context, ruleName: rule.name)
        }
        
        try await applyPendingChanges(context: context)
        try await confirmPendingChanges(context: context)
        return try await getConfiguration(context: context)
    }
    
    static func addOrUpdateRule(context: GwnContext, mac: String, ssidId: String, drate: String, urate: String) async throws -> GwnConfiguration {
        let config = try await getConfiguration(context: context)
        
        // check if rule for SSID-ID and MAC exist? -> Add, if nothing is found
        if let existingRule = config.bandwidthRules.first(where: {
            $0.id.localizedLowercase == mac.localizedLowercase &&
            $0.ssidId == ssidId
        }) {
            // rule exists -> update
            try await updateRule(context: context,
                              ruleName: existingRule.name,
                              mac: mac,
                              ssid: ssidId,
                              drate: drate,
                              urate: urate)
        } else {
            // Add new rule
            try await addRule(context: context,
                           ruleName: config.nextBandwidthRuleName,
                           mac: mac,
                           ssid: ssidId,
                           drate: drate,
                           urate: urate)
        }
        
        try await applyPendingChanges(context: context)
        try await confirmPendingChanges(context: context)
        return try await getConfiguration(context: context)
    }
}

extension GWN {
    
    static private func deleteRuleWithoutCheck(context: GwnContext, ruleName: String) async throws {
        context.info("[gwncli] \(#function) ruleName: \(ruleName)")
        guard let request = GwnRequest.deleteRule(context: context, ruleName: ruleName).urlRequest else {
            throw GwnError.freeForm("Failed to create delete request")
        }
        
        let (data, _) = try await context.session.data(for: request)
        context.debug("[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")")
        
        let response = try JSONDecoder().decode(GwnResponse.self, from: data)
        try evaluateResponse(response: response, message: "Delete rule \(ruleName) failed: \(response)")
    }
    
    static func addRule(context: GwnContext,
                        ruleName: String,
                        mac: String,
                        ssid: String,
                        drate: String,
                        urate: String) async throws {
        context.info("[gwncli] \(#function) ruleName: \(ruleName) mac: \(mac) ssid: \(ssid) drate: \(drate) urate: \(urate)")
        guard let request = GwnRequest.addRule(context: context,
                                               ruleName: ruleName,
                                               id: mac,
                                               idType: "mac",
                                               urate: urate,
                                               drate: drate,
                                               ssidId: ssid).urlRequest else {
            throw GwnError.freeForm("Failed to create request")
        }
        
        let (data, _) = try await context.session.data(for: request)
        context.debug("[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")")
        
        let response = try JSONDecoder().decode(GwnResponse.self, from: data)
        try evaluateResponse(response: response, message: "Add rule \(ruleName) failed: \(response)")
    }
    
    
    static func updateRule(context: GwnContext,
                           ruleName: String,
                           mac: String,
                           ssid: String,
                           drate: String,
                           urate: String) async throws {
        context.info("[gwncli] \(#function) context: \(context) ruleName: \(ruleName) mac: \(mac) ssid: \(ssid) drate: \(drate) urate: \(urate)")
        guard let request = GwnRequest.setRule(context: context,
                                               ruleName: ruleName,
                                               id: mac,
                                               idType: "mac",
                                               urate: urate,
                                               drate: drate,
                                               ssidId: ssid).urlRequest else {
            throw GwnError.freeForm("Failed to create request")
        }
        
        let (data, _) = try await context.session.data(for: request)
        context.debug("[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")")
        
        let response = try JSONDecoder().decode(GwnResponse.self, from: data)
        try evaluateResponse(response: response, message: "Set rule \(ruleName) failed: \(response)")
    }
    
    static private func applyPendingChanges(context: GwnContext) async throws {
        context.info("[gwncli] \(#function)")
        guard let request = GwnRequest.apply(context: context).urlRequest else {
            throw GwnError.freeForm("Failed to create request")
        }
        
        let (data, _) = try await context.session.data(for: request)
        context.debug("[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")")
        
        let response = try JSONDecoder().decode(GwnResponse.self, from: data)
        try evaluateResponse(response: response, message: "Apply failed: \(response)")
    }
    
    static private func confirmPendingChanges(context: GwnContext) async throws {
        context.info("[gwncli] \(#function)")
        guard let request = GwnRequest.confirm(context: context).urlRequest else {
            throw GwnError.freeForm("Failed to create request")
        }
        
        let (data, _) = try await context.session.data(for: request)
        context.debug("[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")")
        
        let response = try JSONDecoder().decode(GwnResponse.self, from: data)
        try evaluateResponse(response: response, message: "Confirm failed: \(response)")
    }
    
    private static func evaluateResponse(response: GwnResponse, message: String) throws {
        guard response.isSuccess else {
            throw GwnError.freeForm(message)
        }
    }
}
