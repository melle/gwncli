// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

final class GwnContext {
    public let session: URLSession
    public let url: URL
    public let userName: String
    public let password: String
    public var sessionToken: String
    public var requestId: Int
    
    init(session: URLSession,
         url: URL,
         userName: String,
         password: String,
         sessionToken: String = "00000000000000000000000000000000",
         requestId: Int = 1) {
        self.session = session
        self.url = url
        self.userName = userName
        self.password = password
        self.sessionToken = sessionToken
        self.requestId = requestId
    }
    
    var nextRequestId: Int {
        requestId += 1
        return requestId
    }
    
}
