// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class GwnContext {
    public let session: URLSession
    public let url: URL
    public let userName: String
    public let password: String
    public var sessionToken: String
    public var requestId: Int
    public var aliasesFile: URL?
    public var aliases: Aliases = .init(aliasMap: [:])
    
    init(session: URLSession,
         url: URL,
         userName: String,
         password: String,
         sessionToken: String = "00000000000000000000000000000000",
         requestId: Int = 1,
         aliases: String? = nil) {
        self.session = session
        self.url = url
        self.userName = userName
        self.password = password
        self.sessionToken = sessionToken
        self.requestId = requestId
        self.aliasesFile = aliases.map { URL(fileURLWithPath: $0,
                                             relativeTo: URL(fileURLWithPath: FileManager().currentDirectoryPath)) }
    }
    
    var nextRequestId: Int {
        requestId += 1
        return requestId
    }

    struct Aliases {
        public let aliasMap: [String: String]
        
        public func aliasFor(id: String) -> String {
            let longestAliasCount = aliasMap.values.map { $0.count }.max() ?? 0
            let alias: String = aliasMap[id].map { " (\($0))" } ?? ""
            let fullString = id + alias
            return fullString.padding(toLength: id.count + longestAliasCount + 3, withPad: " ", startingAt: 0)
        }
    }
}
