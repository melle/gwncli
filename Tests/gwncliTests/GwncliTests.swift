import XCTest
@testable import gwncli
import class Foundation.Bundle

final class GwncliTests: XCTestCase { }

// MARK: - Parser tests

// These are no real unit tests, but used to develop the models and make sure we can parse the weird JSON.
extension GwncliTests {
    
    func testParseLoginResponse() throws {
        // given (acls are not relevant and have been omited in the json)
        let json = """
                   {
                       "jsonrpc": "2.0",
                       "id": 3,
                       "result": [
                           0,
                           {
                               "ubus_rpc_session": "e6fab30a2420c3396abd76d71d87ef07",
                               "timeout": 300,
                               "expires": 299,
                               "acls": {
                               },
                               "data": {
                                   "username": "admin"
                               }
                           }
                       ]
                   }
                   """.data(using: .utf8)!

        // when
        let sut: LoginResponse = try JSONDecoder().decode(LoginResponse.self, from: json)
        
        // then - do we have a session token?
        XCTAssertEqual(sut.jsonrpc, "2.0")
        XCTAssertEqual(sut.id, 3)
        XCTAssertEqual(sut.session, "e6fab30a2420c3396abd76d71d87ef07")
    }
}
