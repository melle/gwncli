// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

struct LoginResponse: Decodable {
    let jsonrpc: String
    let id: Int
    @LossyCodableList var result: [LoginResult]
    
    var session: String {
        result.first?.ubus_rpc_session ?? "00000000000000000000000000000000"
    }
}

struct LoginResult: Equatable, Decodable {
    let ubus_rpc_session: String
}
