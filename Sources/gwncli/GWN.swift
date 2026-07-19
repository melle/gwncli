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

    static func getClients(context: GwnContext) async throws -> [GwnClient] {
        context.info("[gwncli] \(#function)")
        // the range request needs an explicit end index, so fetch the total count first
        guard let countRequest = GwnRequest.getClientsCount(context: context).urlRequest else {
            throw GwnError.freeForm("Failed to create getClientsCount request")
        }

        let (countData, _) = try await context.session.data(for: countRequest)
        context.debug("[gwncli] \(#function) - count response: \(String(data: countData, encoding: .utf8) ?? "<nil>")")

        let countResponse = try JSONDecoder().decode(GwnClientsCountResponse.self, from: countData)
        guard let count = countResponse.result.first?.count else {
            throw GwnError.freeForm("No client count found in response")
        }
        guard count > 0 else {
            return []
        }

        guard let rangeRequest = GwnRequest.getClientsRange(context: context, start: 0, end: count).urlRequest else {
            throw GwnError.freeForm("Failed to create getClientsRange request")
        }

        let (data, _) = try await context.session.data(for: rangeRequest)
        context.debug("[gwncli] \(#function) - response: \(String(data: data, encoding: .utf8) ?? "<nil>")")

        let response = try JSONDecoder().decode(GwnClientsResponse.self, from: data)
        guard let clientList = response.result.first else {
            throw GwnError.freeForm("No client list found in response")
        }
        context.info("[gwncli] \(#function) - found \(clientList.clients.count) clients")
        return clientList.clients
    }

    static func throttleRandomizedClients(context: GwnContext,
                                          drate: String,
                                          urate: String,
                                          ssidOverride: String?,
                                          dryRun: Bool) async throws -> [ThrottleCandidate] {
        context.info("[gwncli] \(#function) drate: \(drate) urate: \(urate)")
        let clients = try await getClients(context: context)
        let config = try await getConfiguration(context: context)

        let ssidIdsByName = Dictionary(config.ssids.map { ($0.ssid, $0.id) },
                                       uniquingKeysWith: { first, _ in first })
        let candidates = try clientsNeedingThrottle(clients: clients,
                                                    existingRules: config.bandwidthRules,
                                                    ssidIdsByName: ssidIdsByName,
                                                    ssidOverride: ssidOverride)
        guard !candidates.isEmpty, !dryRun else {
            return candidates
        }

        // Rule names for the whole batch - config.nextBandwidthRuleName would
        // return the same name for every candidate without a re-fetch.
        let ruleNames = nextRuleNames(existingRules: config.bandwidthRules, count: candidates.count)
        for (candidate, ruleName) in zip(candidates, ruleNames) {
            try await addRule(context: context,
                              ruleName: ruleName,
                              mac: candidate.mac,
                              ssid: candidate.ssidId,
                              drate: drate,
                              urate: urate)
        }

        try await applyPendingChanges(context: context)
        try await confirmPendingChanges(context: context)
        return candidates
    }

    /// A client with a randomized MAC that has no bandwidth rule yet.
    struct ThrottleCandidate: Sendable, Equatable {
        /// Normalized colon-separated MAC, i.e. "72:35:CF:2A:B2:37"
        let mac: String
        let hostname: String
        let ssidId: String
    }

    /// Selects all clients with a locally administered MAC that are not covered by an
    /// existing rule yet. A rule counts regardless of its SSID, so an already throttled
    /// MAC is never throttled twice. Clients reported on multiple radios are deduplicated.
    static func clientsNeedingThrottle(clients: [GwnClient],
                                       existingRules: [BandwidthRule],
                                       ssidIdsByName: [String: String],
                                       ssidOverride: String?) throws -> [ThrottleCandidate] {
        let ruleMacs = Set(existingRules.compactMap { MacAddress.normalized($0.id) })
        var seenMacs = Set<String>()
        var candidates: [ThrottleCandidate] = []
        for client in clients {
            guard let mac = MacAddress.normalized(client.clientMac),
                  MacAddress.isLocallyAdministered(mac),
                  !ruleMacs.contains(mac),
                  !seenMacs.contains(mac) else {
                continue
            }
            guard let ssidId = ssidOverride ?? ssidIdsByName[client.ssid] else {
                throw GwnError.freeForm("Cannot resolve SSID-id for SSID \"\(client.ssid)\" - pass --ssid explicitly")
            }
            seenMacs.insert(mac)
            candidates.append(.init(mac: mac, hostname: client.hostname, ssidId: ssidId))
        }
        return candidates
    }

    /// Returns `count` fresh rule names. Uses numeric comparison because the
    /// lexicographic sort in nextBandwidthRuleName would place "rule9" after "rule10".
    static func nextRuleNames(existingRules: [BandwidthRule], count: Int) -> [String] {
        let maxIndex = existingRules
            .compactMap { Int($0.name.dropFirst("rule".count)) }
            .max() ?? -1
        return (0..<count).map { "rule\(maxIndex + 1 + $0)" }
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
