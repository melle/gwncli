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
        
        public func aliasFor(id: String) -> String {
            let longestAliasCount = aliasMap.values.map { $0.count }.max() ?? 0
            let alias: String = aliasMap[id.lowercased()].map { " (\($0))" } ?? ""
            let fullString = id.lowercased() + alias
            return fullString.padding(toLength: id.count + longestAliasCount + 3, withPad: " ", startingAt: 0)
        }
    }
}
