// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class GwnContext {
    
    // Poo mans OSLog (on Linux...)
    enum LogLevel: UInt, RawRepresentable, CaseIterable, Decodable {
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
    public var sessionToken: String
    public var requestId: Int
    public var aliasesFile: URL?
    public var aliases: Aliases = .init(aliasMap: [:])
    public let logLevel: LogLevel

    init(session: URLSession,
         url: URL,
         userName: String,
         password: String,
         sessionToken: String = "00000000000000000000000000000000",
         requestId: Int = 1,
         aliases: String? = nil,
         logLevel: LogLevel? = .warning) {
        self.session = session
        self.url = url
        self.userName = userName
        self.password = password
        self.sessionToken = sessionToken
        self.requestId = requestId
        self.aliasesFile = aliases.map { URL(fileURLWithPath: $0,
                                             relativeTo: URL(fileURLWithPath: FileManager().currentDirectoryPath)) }
        self.logLevel = logLevel ?? .warning
    }
    
    var nextRequestId: Int {
        requestId += 1
        return requestId
    }

    func info(_ message: () -> String) {
        guard logLevel.isInfo else { return }
        // there is no OSLog on Linux ;-(
        print(message())
    }

    func error(_ message: () -> String) {
        guard logLevel.isError else { return }
        print(message())
    }

    func debug(_ message: () -> String) {
        guard logLevel.isDebug else { return }
        // there is no OSLog on Linux ;-(
        print(message())
    }

    struct Aliases {
        public let aliasMap: [String: String]
        
        public func aliasFor(id: String) -> String {
            let longestAliasCount = aliasMap.values.map { $0.count }.max() ?? 0
            let alias: String = aliasMap[id.lowercased()].map { " (\($0))" } ?? ""
            let fullString = id.lowercased() + alias
            return fullString.padding(toLength: id.count + longestAliasCount + 3, withPad: " ", startingAt: 0)
        }
    }
}
