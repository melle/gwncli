import class Foundation.Bundle
@testable import gwncli
import XCTest

final class GwncliTests: XCTestCase { }

// MARK: - Parser tests

// These are no real unit tests, but are handy to develop the models and make sure we can parse the weird JSON.
extension GwncliTests {
    
    func testParseLoginResponse() throws {
        // when
        let sut: LoginResponse = try decode(resource: #function, to: LoginResponse.self)
        
        // then - do we have a session token?
        XCTAssertEqual(sut.jsonrpc, "2.0")
        XCTAssertEqual(sut.id, 3)
        XCTAssertEqual(sut.session, "e6fab30a2420c3396abd76d71d87ef07")
    }
    
    func testParseGrandstreamConfigurationResponse() throws {
        // when
        let sut: GrandstreamConfigurationResponse = try decode(resource: #function, to: GrandstreamConfigurationResponse.self)
        
        // then - this is the full configuration, we just check some of the values
        XCTAssertEqual(sut.result.first?.values.count, 33)
        
        if case let .rule(bandwidthRule) = sut.result.first?.values["rule4"] {
            XCTAssertEqual(bandwidthRule.anonymous, false)
            XCTAssertEqual(bandwidthRule.name, "rule4")
            XCTAssertEqual(bandwidthRule.index, 31)
            XCTAssertEqual(bandwidthRule.id, "00:11:22:33:44:55")
            XCTAssertEqual(bandwidthRule.enabled, "1")
            XCTAssertEqual(bandwidthRule.idType, "mac")
            XCTAssertEqual(bandwidthRule.urate, "123Kbps")
            XCTAssertEqual(bandwidthRule.drate, "456Kbps")
            XCTAssertEqual(bandwidthRule.ssid, "ssid0")
        } else {
            XCTFail("could not decode json")
        }
    }
    
    func testDecodebandwidthRule() throws {
        // when
        let sut: Dictionary<String, BandwidthRule> = try decode(resource: #function, to: Dictionary<String, BandwidthRule>.self)
        
        // then
        XCTAssertEqual(sut.first?.value.id, "00:11:22:33:44:55")
        XCTAssertEqual(sut.first?.value.anonymous, false)
        XCTAssertEqual(sut.first?.value.name, "rule4")
        XCTAssertEqual(sut.first?.value.index, 31)
        XCTAssertEqual(sut.first?.value.id, "00:11:22:33:44:55")
        XCTAssertEqual(sut.first?.value.enabled, "1")
        XCTAssertEqual(sut.first?.value.idType, "mac")
        XCTAssertEqual(sut.first?.value.urate, "123Kbps")
        XCTAssertEqual(sut.first?.value.drate, "456Kbps")
        XCTAssertEqual(sut.first?.value.ssid, "ssid0")
    }
    
    func testDecodeSSIDConfig() throws {
        // when
        let sut: SsidConfig = try decode(resource: #function, to: SsidConfig.self)
        
        // then
        XCTAssertEqual(sut.anonymous, false)
        XCTAssertEqual(sut.type, "additional_ssid")
        XCTAssertEqual(sut.name, "ssid1")
        XCTAssertEqual(sut.index, 18)
        XCTAssertEqual(sut.id, "ssid1")
        XCTAssertEqual(sut.enable, "1")
        XCTAssertEqual(sut.ssid, "Freifunk")
        XCTAssertEqual(sut.ssidHidden, "0")
        XCTAssertEqual(sut.clientIPAssignment, "0")
        XCTAssertEqual(sut.portalEnable, "0")
        XCTAssertEqual(sut.enableSchedule, "0")
        XCTAssertEqual(sut.encryption, "6")
        XCTAssertEqual(sut.wpaKeyMode, "2")
        XCTAssertEqual(sut.wpaEncryption, "0")
        XCTAssertEqual(sut.wpaKey, "supersecret")
        XCTAssertEqual(sut.bridgeEnable, "0")
        XCTAssertEqual(sut.macFiltering, "0")
        XCTAssertEqual(sut.isolation, "0")
        XCTAssertEqual(sut.dtimPeriod, "1")
        XCTAssertEqual(sut.bms, "0")
        XCTAssertEqual(sut.mcastToUcast, "0")
        XCTAssertEqual(sut.wifi80211k, "0")
        XCTAssertEqual(sut.wifi80211v, "0")
        XCTAssertEqual(sut.proxyarp, "0")
        XCTAssertEqual(sut.uapsd, "1")
        XCTAssertEqual(sut.voiceEnterprise, "0")
        XCTAssertEqual(sut.wifi80211r, "0")
        XCTAssertEqual(sut.staIdleTimeout, "300")
        XCTAssertEqual(sut.bintval, "100")
        XCTAssertEqual(sut.rssiEnable, "0")
        XCTAssertEqual(sut.ratelimitEnable, "1")
        XCTAssertEqual(sut.minirate, "6")
    }
    
    func testEncodLoginRequest() throws {
        // given
        let context = GwnContext(session: .shared,
                                 url: URL.init(fileURLWithPath: "/tmp"),
                                 userName: "user",
                                 password: "password")
        let sut = GrandstreamRequest.login(context: context)
        
        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let result = String(data: try encoder.encode(sut), encoding: .utf8)
        
        // then
        let expected = """
                        {
                          "id" : 2,
                          "jsonrpc" : "2.0",
                          "method" : "call",
                          "params" : [
                            "00000000000000000000000000000000",
                            "session",
                            "login",
                            {
                              "username" : "user",
                              "password" : "password"
                            }
                          ]
                        }
                        """
        XCTAssertEqual(result, expected)
    }
    
    func testEncodGetConfigRequest() throws {
        // given
        let context = GwnContext(session: .shared,
                                 url: URL.init(fileURLWithPath: "/tmp"),
                                 userName: "user",
                                 password: "password")
        let sut = GrandstreamRequest.getConfig(context: context)
        
        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let result = String(data: try encoder.encode(sut), encoding: .utf8)
        
        // then
        let expected = """
                       {
                         "id" : 2,
                         "jsonrpc" : "2.0",
                         "method" : "call",
                         "params" : [
                           "00000000000000000000000000000000",
                           "uci",
                           "get",
                           {
                             "config" : "grandstream"
                           }
                         ]
                       }
                       """
        XCTAssertEqual(result, expected)
    }
    
    func testEncodDeleteRulegRequest() throws {
        // given
        let context = GwnContext(session: .shared,
                                 url: URL.init(fileURLWithPath: "/tmp"),
                                 userName: "user",
                                 password: "password")
        let sut = GrandstreamRequest.deleteRule(context: context, ruleName: "rule34")

        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let result = String(data: try encoder.encode(sut), encoding: .utf8)

        // then
        let expected = """
                       {
                         "id" : 2,
                         "jsonrpc" : "2.0",
                         "method" : "call",
                         "params" : [
                           "00000000000000000000000000000000",
                           "uci",
                           "delete",
                           {
                             "section" : "rule34",
                             "config" : "grandstream"
                           }
                         ]
                       }
                       """
        XCTAssertEqual(result, expected)
    }
    
    func testEncodApplyRequest() throws {
        // given
        let context = GwnContext(session: .shared,
                                 url: URL.init(fileURLWithPath: "/tmp"),
                                 userName: "user",
                                 password: "password")
        let sut = GrandstreamRequest.apply(context: context)

        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let result = String(data: try encoder.encode(sut), encoding: .utf8)

        // then
        let expected = """
                       {
                         "id" : 2,
                         "jsonrpc" : "2.0",
                         "method" : "call",
                         "params" : [
                           "00000000000000000000000000000000",
                           "uci",
                           "apply",
                           {
                             "timeout" : 10,
                             "rollback" : true
                           }
                         ]
                       }
                       """
        XCTAssertEqual(result, expected)
    }
    
    func testEncodConfirmRequest() throws {
        // given
        let context = GwnContext(session: .shared,
                                 url: URL.init(fileURLWithPath: "/tmp"),
                                 userName: "user",
                                 password: "password")
        let sut = GrandstreamRequest.confirm(context: context)

        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let result = String(data: try encoder.encode(sut), encoding: .utf8)

        // then
        let expected = """
                       {
                         "id" : 2,
                         "jsonrpc" : "2.0",
                         "method" : "call",
                         "params" : [
                           "00000000000000000000000000000000",
                           "uci",
                           "confirm",
                           {

                           }
                         ]
                       }
                       """
        XCTAssertEqual(result, expected)
    }
}

// MARK: - Console output

extension GwncliTests {
    func testBandwidthRulesFormatted() throws {
        // given
        let configResponse: [GrandstreamConfigurationResponse] = try decode(resource: #function, to: [GrandstreamConfigurationResponse].self)
        
        // when
        guard let sut = configResponse.first?.result.first?.bandwidthRulesFormatted else { XCTFail() ; return }
        
        // then - rules must appear properly formatted in the right order
        XCTAssertEqual(sut,
                       """
                       rule4\t[enabled] \tU: 123Kbps\tD:456Kbps\tSSID: ssid0\tmac\t00:11:22:33:44:55
                       rule5\t[enabled] \tU: 123Kbps\tD:456Kbps\tSSID: ssid1\tmac\t00:11:22:33:44:55
                       rule2\t[enabled] \tU: 96Kbps\tD:96Kbps\tSSID: ssid0\tmac\t6C:C4:D5:50:95:F1
                       rule3\t[enabled] \tU: 96Kbps\tD:96Kbps\tSSID: ssid1\tmac\t6C:C4:D5:50:95:F1
                       rule0\t[enabled] \tU: 96Kbps\tD:96Kbps\tSSID: ssid0\tmac\t9C:FC:28:D1:F7:20
                       rule1\t[enabled] \tU: 96Kbps\tD:96Kbps\tSSID: ssid1\tmac\t9C:FC:28:D1:F7:20
                       """
        )
    }
}

// MARK: - Helpers

extension GwncliTests {
    
    func decode<T: Decodable>(resource: String, to type: T.Type) throws -> T {
        return try JSONDecoder().decode(T.self, from: data(resource: resource))
    }
    
    func data(resource: String) throws -> Data {
        // no idea why but `Bundle.module.url(forResource: functionName, withExtension: "json")` fails here 🤷‍♂️
        let url = Bundle.module.bundleURL.appendingPathComponent("Contents/Resources/Resources/\(resource).json")
        return try Data(contentsOf: url)
    }
}
