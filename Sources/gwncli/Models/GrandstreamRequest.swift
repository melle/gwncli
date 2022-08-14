// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

struct GrandstreamRequest: Encodable {
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
   
    public let urlPath: String
    public let context: GwnContext
    
    static func login(context: GwnContext) -> GrandstreamRequest {
        GrandstreamRequest(id: context.nextRequestId,
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
    
    static func getConfig(context: GwnContext) -> GrandstreamRequest {
        GrandstreamRequest(id: context.nextRequestId,
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

    static func deleteRule(context: GwnContext, ruleName: String) -> GrandstreamRequest {
        GrandstreamRequest(id: context.nextRequestId,
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

    var urlRequest: URLRequest? {
        var request =  URLRequest(url: context.url.appendingPathComponent(urlPath))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        request.httpBody = try? encoder.encode(self)
        
        return request
    }
}

enum RequestParameters: Encodable {
    case value(String)
    case login(Login)
    case getConfig(Config)
    case deleteRule(DeleteRule)
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .value(let x):
            try container.encode(x)
        case .login(let y):
            try container.encode(y)
        case .getConfig(let y):
            try container.encode(y)
        case .deleteRule(let y):
            try container.encode(y)
        }
    }
    
    var requestPath: String {
        switch self {
        case .value: return ""
        case .login: return ""
        case .getConfig: return ""
        case .deleteRule: return ""
        }
    }
    
    struct Login: Encodable {
        public let username: String
        public let password: String
    }
    
    struct Config: Encodable {
        public let config: String = "grandstream"
    }

    struct DeleteRule: Encodable {
        public let config: String = "grandstream"
        public let section: String
    }
}

