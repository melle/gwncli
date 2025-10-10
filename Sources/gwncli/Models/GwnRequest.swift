// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct GwnRequest: Encodable, Sendable {
    public let id: Int
    public let jsonrpc: String = "2.0"
    public let method: String
    public let params: [RequestParameters]
    
    enum CodingKeys: CodingKey {
        case id
        case jsonrpc
        case method
        case params
    }
    
    let urlPath: String
    let context: GwnContext
    
    static func login(context: GwnContext) -> GwnRequest {
        GwnRequest(id: context.nextRequestId,
                   method: "call",
                   params: [
                    .value(context.sessionToken),
                    .value("session"),
                    .value("login"),
                    .login(.init(username: context.userName, password: context.password))
                   ],
                   urlPath: "/ubus/session.login",
                   context: context
        )
    }
    
    static func getConfig(context: GwnContext) -> GwnRequest {
        GwnRequest(id: context.nextRequestId,
                   method: "call",
                   params: [
                    .value(context.sessionToken),
                    .value("uci"),
                    .value("get"),
                    .getConfig(.init())
                   ],
                   urlPath: "/ubus/uci.get",
                   context: context
        )
    }
    
    static func deleteRule(context: GwnContext, ruleName: String) -> GwnRequest {
        GwnRequest(id: context.nextRequestId,
                   method: "call",
                   params: [
                    .value(context.sessionToken),
                    .value("uci"),
                    .value("delete"),
                    .deleteRule(.init(section: ruleName))
                   ],
                   urlPath: "/ubus/uci.delete",
                   context: context
        )
    }
    
    static func addRule(context: GwnContext,
                        ruleName: String,
                        id: String,
                        idType: String,
                        urate: String,
                        drate: String,
                        ssidId: String) -> GwnRequest {
        GwnRequest(id: context.nextRequestId,
                   method: "call",
                   params: [
                    .value(context.sessionToken),
                    .value("uci"),
                    .value("add"),
                    .addRule(.init(values: .init(id: id.uppercased(),
                                                 enabled: 1,
                                                 idType: idType,
                                                 urate: urate,
                                                 drate: drate,
                                                 ssidId: ssidId),
                                   name: ruleName))
                   ],
                   urlPath: "/ubus/uci.add",
                   context: context
        )
    }
    
    static func setRule(context: GwnContext,
                        ruleName: String,
                        id: String,
                        idType: String,
                        urate: String,
                        drate: String,
                        ssidId: String) -> GwnRequest {
        GwnRequest(id: context.nextRequestId,
                   method: "call",
                   params: [
                    .value(context.sessionToken),
                    .value("uci"),
                    .value("set"),
                    .setRule(.init(section: ruleName,
                                   values: .init(id: id.uppercased(),
                                                 enabled: 1,
                                                 idType: idType,
                                                 urate: urate,
                                                 drate: drate,
                                                 ssidId: ssidId)
                                  )
                    )
                   ],
                   urlPath: "/ubus/uci.set",
                   context: context
        )
    }
    
    static func apply(context: GwnContext) -> GwnRequest {
        GwnRequest(id: context.nextRequestId,
                   method: "call",
                   params: [
                    .value(context.sessionToken),
                    .value("uci"),
                    .value("apply"),
                    .apply(.init())
                   ],
                   urlPath: "/ubus/uci.apply",
                   context: context
        )
    }
    
    static func confirm(context: GwnContext) -> GwnRequest {
        GwnRequest(id: context.nextRequestId,
                   method: "call",
                   params: [
                    .value(context.sessionToken),
                    .value("uci"),
                    .value("confirm"),
                    .confirm(.init())
                   ],
                   urlPath: "/ubus/uci.confirm",
                   context: context
        )
    }
    
    
    
    var urlRequest: URLRequest? {
        var request =  URLRequest(url: context.url.appendingPathComponent(urlPath))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        request.httpBody = try? encoder.encode(self)
        
        return request
    }
}

enum RequestParameters: Encodable, Sendable {
    case value(String)
    case login(Login)
    case getConfig(Config)
    case deleteRule(DeleteRule)
    case addRule(AddRule)
    case setRule(SetRule)
    case apply(Apply)
    case confirm(Confirm)
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .value(let x):
            try container.encode(x)
        case .login(let x):
            try container.encode(x)
        case .getConfig(let x):
            try container.encode(x)
        case .deleteRule(let x):
            try container.encode(x)
        case .addRule(let x):
            try container.encode(x)
        case .setRule(let x):
            try container.encode(x)
        case .apply(let x):
            try container.encode(x)
        case .confirm(let x):
            try container.encode(x)
        }
    }
    
    struct Login: Encodable, Sendable {
        public let username: String
        public let password: String
    }
    
    struct Config: Encodable, Sendable {
        public let config: String = "grandstream"
    }
    
    struct DeleteRule: Encodable, Sendable {
        public let config: String = "grandstream"
        public let section: String
    }
    
    struct AddRule: Encodable, Sendable {
        public let config: String = "grandstream"
        public let values: RuleModification
        public let type: String = "bwctrl-rule"
        public let name: String
    }
    
    struct SetRule: Encodable, Sendable {
        public let config: String = "grandstream"
        /// rule name
        public let section: String
        public let values: RuleModification
    }
    
    struct RuleModification: Encodable, Sendable {
        let id: String
        let enabled: Int
        let idType: String
        let urate: String
        let drate: String
        let ssidId: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case enabled
            case idType = "type"
            case urate
            case drate
            case ssidId = "ssid_id"
        }
    }
    
    struct Apply: Encodable, Sendable {
        public let timeout: Int = 10
        public let rollback: Bool = true
        
    }
    
    struct Confirm: Encodable, Sendable {
    }
}

