// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct GwnContext: Sendable {
    
    // Poor man's OSLog (on Linux...)
    enum LogLevel: UInt, RawRepresentable, CaseIterable, Decodable, Sendable {
        case fatal = 1
        case error = 2
        case warning = 3
        case info = 4
        case debug = 5
        
        var isError: Bool {
            self.rawValue >= LogLevel.error.rawValue
        }
        
        var isInfo: Bool {
            self.rawValue >= LogLevel.info.rawValue
        }
        
        var isDebug: Bool {
            self.rawValue >= LogLevel.debug.rawValue
        }
    }
    
    public let session: URLSession
    public let url: URL
    public let userName: String
    public let password: String
    public let sessionToken: String
    public let requestId: Int
    public let aliasesFile: URL?
    public let aliases: Aliases
    public let logLevel: LogLevel

    init(session: URLSession,
         url: URL,
         userName: String,
         password: String,
         sessionToken: String = "00000000000000000000000000000000",
         requestId: Int = 1,
         aliases: String? = nil,
         aliasesMap: Aliases = .init(aliasMap: [:]),
         logLevel: LogLevel? = .warning) {
        self.session = session
        self.url = url
        self.userName = userName
        self.password = password
        self.sessionToken = sessionToken
        self.requestId = requestId
        self.aliasesFile = aliases.map { URL(fileURLWithPath: $0,
                                             relativeTo: URL(fileURLWithPath: FileManager().currentDirectoryPath)) }
        self.aliases = aliasesMap
        self.logLevel = logLevel ?? .warning
    }
    
    var nextRequestId: Int {
        requestId + 1
    }
    
    func withNextRequestId() -> GwnContext {
        GwnContext(session: session, url: url, userName: userName, password: password,
                   sessionToken: sessionToken, requestId: nextRequestId,
                   aliases: aliasesFile.map { $0.path },
                   aliasesMap: aliases, logLevel: logLevel)
    }
    
    func withSessionToken(_ token: String) -> GwnContext {
        GwnContext(session: session, url: url, userName: userName, password: password,
                   sessionToken: token, requestId: requestId,
                   aliases: aliasesFile.map { $0.path },
                   aliasesMap: aliases, logLevel: logLevel)
    }
    
    func withAliases(_ newAliases: Aliases) -> GwnContext {
        GwnContext(session: session, url: url, userName: userName, password: password,
                   sessionToken: sessionToken, requestId: requestId,
                   aliases: aliasesFile.map { $0.path },
                   aliasesMap: newAliases, logLevel: logLevel)
    }

    func info(_ message: @autoclosure () -> String) {
        guard logLevel.isInfo else { return }
        // there is no OSLog on Linux ;-(
        print(message())
    }

    func error(_ message: @autoclosure () -> String) {
        guard logLevel.isError else { return }
        print(message())
    }

    func debug(_ message: @autoclosure () -> String) {
        guard logLevel.isDebug else { return }
        // there is no OSLog on Linux ;-(
        print(message())
    }

    struct Aliases: Sendable {
        public let aliasMap: [String: String]
        
        // Initializer that normalizes all keys to lowercase for case-insensitive lookups
        public init(aliasMap: [String: String]) {
            self.aliasMap = aliasMap.reduce(into: [:]) { result, pair in
                result[pair.key.lowercased()] = pair.value
            }
        }
        
        public func aliasFor(id: String) -> String {
            let longestAliasCount = aliasMap.values.map { $0.count }.max() ?? 0
            // Look up alias using lowercase, but preserve original ID casing in output
            let alias: String = aliasMap[id.lowercased()].map { " (\($0))" } ?? ""
            let fullString = id + alias
            return fullString.padding(toLength: id.count + longestAliasCount + 3, withPad: " ", startingAt: 0)
        }
    }
}

// MARK: - Fluent API for elegant async chaining
extension GwnContext {
    /// Reads aliases from the configured aliases file
    func readingAliases() async throws -> GwnContext {
        try await GWN.readAliases(context: self)
    }
    
    /// Acquires a session token by logging in
    func acquiringSession() async throws -> GwnContext {
        try await GWN.acquireSession(context: self)
    }
    
    /// Fetches the current configuration from the device
    func fetchingConfiguration() async throws -> GwnConfiguration {
        try await GWN.getConfiguration(context: self)
    }
    
    /// Deletes a bandwidth rule by name or MAC address
    func deletingRule(ruleName: String?, macAddress: String?) async throws -> GwnConfiguration {
        try await GWN.deleteRule(context: self, ruleName: ruleName, macAddress: macAddress)
    }
    
    /// Adds or updates a bandwidth rule for the given MAC address
    func addingOrUpdatingRule(mac: String, ssidId: String, drate: String, urate: String) async throws -> GwnConfiguration {
        try await GWN.addOrUpdateRule(context: self, mac: mac, ssidId: ssidId, drate: drate, urate: urate)
    }

    /// Fetches the list of WiFi clients known to the access point
    func fetchingClients() async throws -> [GwnClient] {
        try await GWN.getClients(context: self)
    }

    /// Ensures a bandwidth rule exists for every client with a randomized (locally administered) MAC
    func throttlingRandomizedClients(drate: String, urate: String, ssidOverride: String?, dryRun: Bool) async throws -> [GWN.ThrottleCandidate] {
        try await GWN.throttleRandomizedClients(context: self, drate: drate, urate: urate, ssidOverride: ssidOverride, dryRun: dryRun)
    }
}
