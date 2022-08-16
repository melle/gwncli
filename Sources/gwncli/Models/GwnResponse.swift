// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

struct GwnResponse: Decodable {
    public let jsonrpc: String
    public let id: Int
    public let result: [ResultElement]
    
    public var isSuccess: Bool {
        if case let .integer(rc) = result.first {
            return rc == 0
        }
        return false
    }
}

enum ResultElement: Decodable {
    case integer(Int)
    case resultClass(ResultClass)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) {
            self = .integer(x)
            return
        }
        if let x = try? container.decode(ResultClass.self) {
            self = .resultClass(x)
            return
        }
        throw DecodingError.typeMismatch(ResultElement.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for ResultElement"))
    }
}

struct ResultClass: Decodable {
}
