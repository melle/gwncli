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
    
    func testParseGwnConfigurationResponse() throws {
        // when
        let sut: GwnConfigurationResponse = try decode(resource: #function, to: GwnConfigurationResponse.self)
        
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
            XCTAssertEqual(bandwidthRule.ssidId, "ssid0")
        } else {
            XCTFail("could not decode json")
        }
    }
    
    func testDecodeBandwidthRule() throws {
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
        XCTAssertEqual(sut.first?.value.ssidId, "ssid0")
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
        let sut = GwnRequest.login(context: context)
        
        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
                              "password" : "password",
                              "username" : "user"
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
        let sut = GwnRequest.getConfig(context: context)
        
        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
    
    func testEncodDeleteRuleRequest() throws {
        // given
        let context = GwnContext(session: .shared,
                                 url: URL.init(fileURLWithPath: "/tmp"),
                                 userName: "user",
                                 password: "password")
        let sut = GwnRequest.deleteRule(context: context, ruleName: "rule34")
        
        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
                             "config" : "grandstream",
                             "section" : "rule34"
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
        let sut = GwnRequest.apply(context: context)
        
        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
                             "rollback" : true,
                             "timeout" : 10
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
        let sut = GwnRequest.confirm(context: context)
        
        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
    
    func testParseClientsCountResponse() throws {
        // when
        let sut: GwnClientsCountResponse = try decode(resource: #function, to: GwnClientsCountResponse.self)

        // then
        XCTAssertEqual(sut.result.first?.count, 28)
        XCTAssertEqual(sut.result.first?.online, 22)
    }

    func testParseClientsRangeResponse() throws {
        // when
        let sut: GwnClientsResponse = try decode(resource: #function, to: GwnClientsResponse.self)

        // then
        let clientList = try XCTUnwrap(sut.result.first)
        XCTAssertEqual(clientList.count, 3)
        XCTAssertEqual(clientList.online, 2)
        XCTAssertEqual(clientList.clients.count, 3)

        let first = try XCTUnwrap(clientList.clients.first)
        XCTAssertEqual(first.clientMac, "7235cf2ab237")
        XCTAssertEqual(first.ssid, "MyWifi")
        XCTAssertEqual(first.online, 1)
        XCTAssertEqual(first.wired, 0)
        XCTAssertEqual(first.associatedAp, "c074ad000001")
        XCTAssertEqual(first.clientIpv4, "192.168.7.55")
        XCTAssertEqual(first.hostname, "")

        let last = try XCTUnwrap(clientList.clients.last)
        XCTAssertEqual(last.clientMac, "7a523defb445")
        XCTAssertEqual(last.hostname, "Watch")
        XCTAssertEqual(last.os, "iOS")
        XCTAssertEqual(last.online, 0)
    }

    func testEncodGetClientsCountRequest() throws {
        // given
        let context = GwnContext(session: .shared,
                                 url: URL.init(fileURLWithPath: "/tmp"),
                                 userName: "user",
                                 password: "password")
        let sut = GwnRequest.getClientsCount(context: context)

        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let result = String(data: try encoder.encode(sut), encoding: .utf8)

        // then
        let expected = """
                       {
                         "id" : 2,
                         "jsonrpc" : "2.0",
                         "method" : "call",
                         "params" : [
                           "00000000000000000000000000000000",
                           "controller.core",
                           "get_clients_count",
                           {

                           }
                         ]
                       }
                       """
        XCTAssertEqual(result, expected)
    }

    func testEncodGetClientsRangeRequest() throws {
        // given
        let context = GwnContext(session: .shared,
                                 url: URL.init(fileURLWithPath: "/tmp"),
                                 userName: "user",
                                 password: "password")
        let sut = GwnRequest.getClientsRange(context: context, start: 0, end: 28)

        // when
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let result = String(data: try encoder.encode(sut), encoding: .utf8)

        // then
        let expected = """
                       {
                         "id" : 2,
                         "jsonrpc" : "2.0",
                         "method" : "call",
                         "params" : [
                           "00000000000000000000000000000000",
                           "controller.core",
                           "get_clients_range",
                           {
                             "associated_ap" : "",
                             "end" : 28,
                             "radio" : 0,
                             "start" : 0,
                             "wireless" : 2
                           }
                         ]
                       }
                       """
        XCTAssertEqual(result, expected)
    }

    func testDecodeGwnResponse() throws {
        let json = """
                   {
                      "jsonrpc": "2.0",
                      "id": 4,
                      "result": [
                        0,
                        {
                          "section": "rule6"
                        }
                      ]
                   }
                   """.data(using: .utf8)!
        
        // when
        let response = try JSONDecoder().decode(GwnResponse.self, from: json)
        
        // then
        XCTAssertTrue(response.isSuccess)
    }
}

// MARK: - Console output

extension GwncliTests {
    func testBandwidthRulesFormatted() throws {
        // given
        let configResponse: [GwnConfigurationResponse] = try decode(resource: #function, to: [GwnConfigurationResponse].self)
        
        // when
        guard let sut = configResponse.first?.result.first?.bandwidthRulesFormatted(aliases: GwnContext.Aliases(aliasMap: [:])) else { XCTFail() ; return }
        
        // then - rules must appear properly formatted in the right order
        XCTAssertEqual(sut,
                       """
                       rule4\t[enabled] \tU: 123Kbps\tD:456Kbps\tmac: 00:11:22:33:44:55   \tSSID: ssid0 "Paul-Motz-19"
                       rule5\t[enabled] \tU: 123Kbps\tD:456Kbps\tmac: 00:11:22:33:44:55   \tSSID: ssid1 "Paul-Motz-34"
                       rule2\t[enabled] \tU: 96Kbps\tD:96Kbps\tmac: 6C:C4:D5:50:95:F1   \tSSID: ssid0 "Paul-Motz-19"
                       rule3\t[enabled] \tU: 96Kbps\tD:96Kbps\tmac: 6C:C4:D5:50:95:F1   \tSSID: ssid1 "Paul-Motz-34"
                       rule0\t[enabled] \tU: 96Kbps\tD:96Kbps\tmac: 9C:FC:28:D1:F7:20   \tSSID: ssid0 "Paul-Motz-19"
                       rule1\t[enabled] \tU: 96Kbps\tD:96Kbps\tmac: 9C:FC:28:D1:F7:20   \tSSID: ssid1 "Paul-Motz-34"
                       """
        )
    }
}

// MARK: - Aliases

extension GwncliTests {
    func testAliasPadding() throws {
        let sut = GwnContext.Aliases(aliasMap: [
            "6C:C4:D5:50:95:F1": "AppleCast",
            "9C:FC:28:D1:F7:20": "Another longish alias",
        ])
        
        XCTAssertEqual(sut.aliasFor(id: "6C:C4:D5:50:95:F1"), "6C:C4:D5:50:95:F1 (AppleCast)            ")
        XCTAssertEqual(sut.aliasFor(id: "9C:FC:28:D1:F7:20"), "9C:FC:28:D1:F7:20 (Another longish alias)")
        XCTAssertEqual(sut.aliasFor(id: "AA:BB:CC:DD:EE:FF"), "AA:BB:CC:DD:EE:FF                        ")
    }
}

// MARK: - MAC addresses

extension GwncliTests {
    func testMacAddressNormalization() {
        XCTAssertEqual(MacAddress.normalized("7235cf2ab237"), "72:35:CF:2A:B2:37")
        XCTAssertEqual(MacAddress.normalized("72:35:cf:2a:b2:37"), "72:35:CF:2A:B2:37")
        XCTAssertEqual(MacAddress.normalized("72-35-CF-2A-B2-37"), "72:35:CF:2A:B2:37")
        XCTAssertNil(MacAddress.normalized("7235cf2ab2"))
        XCTAssertNil(MacAddress.normalized("7235cf2ab23712"))
        XCTAssertNil(MacAddress.normalized("no mac address"))
        XCTAssertNil(MacAddress.normalized(""))
    }

    func testIsLocallyAdministered() {
        // randomized ("private") MACs have bit 1 of the first octet set
        XCTAssertTrue(MacAddress.isLocallyAdministered("F2:BA:30:1D:B4:43"))
        XCTAssertTrue(MacAddress.isLocallyAdministered("7a523defb445"))
        XCTAssertTrue(MacAddress.isLocallyAdministered("02:00:00:00:00:01"))
        // universally administered (vendor assigned) MACs
        XCTAssertFalse(MacAddress.isLocallyAdministered("6C:4A:85:45:B5:F9"))
        XCTAssertFalse(MacAddress.isLocallyAdministered("00:11:22:33:44:55"))
        XCTAssertFalse(MacAddress.isLocallyAdministered("9427701800df"))
        // unparseable input must never be throttled
        XCTAssertFalse(MacAddress.isLocallyAdministered("garbage"))
    }
}

// MARK: - Throttle candidate selection

extension GwncliTests {

    private func client(mac: String, ssid: String = "MyWifi", hostname: String = "") -> GwnClient {
        GwnClient(wired: 0,
                  online: 1,
                  associatedAp: "c074ad000001",
                  clientMac: mac,
                  ssid: ssid,
                  clientIpv4: "192.168.7.55",
                  hostname: hostname,
                  os: "",
                  lastSeen: 1784490717)
    }

    private func rule(name: String, mac: String, ssidId: String = "ssid0") -> BandwidthRule {
        BandwidthRule(anonymous: false,
                      ruletype: "bwctrl-rule",
                      name: name,
                      index: 30,
                      id: mac,
                      enabled: "1",
                      idType: "mac",
                      urate: "512Kbps",
                      drate: "1Mbps",
                      ssidId: ssidId)
    }

    func testClientsNeedingThrottleSelectsOnlyRandomizedMacs() throws {
        // given - one randomized, one vendor assigned MAC
        let clients = [client(mac: "7235cf2ab237", hostname: "iPhone"),
                       client(mac: "9427701800df", hostname: "dishwasher")]

        // when
        let sut = try GWN.clientsNeedingThrottle(clients: clients,
                                                 existingRules: [],
                                                 ssidIdsByName: ["MyWifi": "ssid0"],
                                                 ssidOverride: nil)

        // then
        XCTAssertEqual(sut, [.init(mac: "72:35:CF:2A:B2:37", hostname: "iPhone", ssidId: "ssid0")])
    }

    func testClientsNeedingThrottleSkipsAlreadyThrottledMacs() throws {
        // given - the rule stores the MAC colon-separated and uppercased, the client list bare and lowercased.
        // The rule points to another SSID, which must not matter: one rule per MAC is enough.
        let clients = [client(mac: "7235cf2ab237")]
        let rules = [rule(name: "rule0", mac: "72:35:CF:2A:B2:37", ssidId: "ssid1")]

        // when
        let sut = try GWN.clientsNeedingThrottle(clients: clients,
                                                 existingRules: rules,
                                                 ssidIdsByName: ["MyWifi": "ssid0"],
                                                 ssidOverride: nil)

        // then
        XCTAssertEqual(sut, [])
    }

    func testClientsNeedingThrottleDeduplicatesClients() throws {
        // given - the same client reported on both radios
        let clients = [client(mac: "7235cf2ab237"), client(mac: "72:35:CF:2A:B2:37")]

        // when
        let sut = try GWN.clientsNeedingThrottle(clients: clients,
                                                 existingRules: [],
                                                 ssidIdsByName: ["MyWifi": "ssid0"],
                                                 ssidOverride: nil)

        // then
        XCTAssertEqual(sut.count, 1)
    }

    func testClientsNeedingThrottleSsidOverride() throws {
        // given - a client on an SSID that is not in the configuration
        let clients = [client(mac: "7235cf2ab237", ssid: "GuestWifi")]

        // when - without an override the SSID cannot be resolved
        XCTAssertThrowsError(try GWN.clientsNeedingThrottle(clients: clients,
                                                            existingRules: [],
                                                            ssidIdsByName: ["MyWifi": "ssid0"],
                                                            ssidOverride: nil))

        // then - the override wins
        let sut = try GWN.clientsNeedingThrottle(clients: clients,
                                                 existingRules: [],
                                                 ssidIdsByName: ["MyWifi": "ssid0"],
                                                 ssidOverride: "ssid1")
        XCTAssertEqual(sut, [.init(mac: "72:35:CF:2A:B2:37", hostname: "", ssidId: "ssid1")])
    }

    func testParseAge() throws {
        XCTAssertEqual(try Gwncli.parseAge("30m"), 30 * 60)
        XCTAssertEqual(try Gwncli.parseAge("12h"), 12 * 3600)
        XCTAssertEqual(try Gwncli.parseAge("7d"), 7 * 86400)
        XCTAssertThrowsError(try Gwncli.parseAge("7"))
        XCTAssertThrowsError(try Gwncli.parseAge("d"))
        XCTAssertThrowsError(try Gwncli.parseAge("-1d"))
        XCTAssertThrowsError(try Gwncli.parseAge("7w"))
        XCTAssertThrowsError(try Gwncli.parseAge(""))
    }

    func testFormattedAge() {
        XCTAssertEqual(GWN.formattedAge(90 * 60), "90 minutes")
        XCTAssertEqual(GWN.formattedAge(12 * 3600), "12 hours")
        XCTAssertEqual(GWN.formattedAge(9 * 86400), "9 days")
    }

    func testRulesNeedingCleanup() {
        let now = 1784490717
        let maxAge: TimeInterval = 7 * 86400
        let staleSeen = now - 8 * 86400
        let recentSeen = now - 3600

        func offlineClient(mac: String, lastSeen: Int) -> GwnClient {
            GwnClient(wired: 0, online: 0, associatedAp: "c074ad000001", clientMac: mac,
                      ssid: "MyWifi", clientIpv4: "", hostname: "", os: "", lastSeen: lastSeen)
        }

        let rules = [rule(name: "rule0", mac: "72:35:CF:2A:B2:37"),  // LA, vanished -> delete
                     rule(name: "rule1", mac: "66:AD:65:4A:68:D9"),  // LA, stale -> delete
                     rule(name: "rule2", mac: "7A:52:3D:EF:B4:45"),  // LA, recently seen -> keep
                     rule(name: "rule3", mac: "AE:44:41:DB:7F:02"),  // LA, online -> keep
                     rule(name: "rule4", mac: "62:03:10:D3:D6:92"),  // LA, vanished but aliased -> keep
                     rule(name: "rule5", mac: "9C:FC:28:D1:F7:20")]  // vendor MAC, vanished -> keep
        let clients = [offlineClient(mac: "66ad654a68d9", lastSeen: staleSeen),
                       // same MAC on a second radio, still stale
                       offlineClient(mac: "66:AD:65:4A:68:D9", lastSeen: staleSeen - 100),
                       offlineClient(mac: "7a523defb445", lastSeen: recentSeen),
                       // online beats an old last_seen
                       GwnClient(wired: 0, online: 1, associatedAp: "c074ad000001", clientMac: "ae4441db7f02",
                                 ssid: "MyWifi", clientIpv4: "", hostname: "", os: "", lastSeen: staleSeen)]

        // when
        let sut = GWN.rulesNeedingCleanup(rules: rules,
                                          clients: clients,
                                          aliasedMacs: ["62:03:10:D3:D6:92"],
                                          now: now,
                                          maxAge: maxAge)

        // then
        XCTAssertEqual(sut, [.init(ruleName: "rule0", mac: "72:35:CF:2A:B2:37", reason: "not in the client list anymore"),
                             .init(ruleName: "rule1", mac: "66:AD:65:4A:68:D9", reason: "last seen 8 days ago")])
    }

    func testNextRuleNamesForBatch() {
        // given - rule9 and rule10 to guard against the lexicographic sorting trap ("rule9" > "rule10")
        let rules = [rule(name: "rule9", mac: "00:11:22:33:44:55"),
                     rule(name: "rule10", mac: "00:11:22:33:44:66")]

        // then
        XCTAssertEqual(GWN.nextRuleNames(existingRules: rules, count: 2), ["rule11", "rule12"])
        XCTAssertEqual(GWN.nextRuleNames(existingRules: [], count: 2), ["rule0", "rule1"])
        XCTAssertEqual(GWN.nextRuleNames(existingRules: rules, count: 0), [])
    }
}

// MARK: - Helpers

extension GwncliTests {
    
    func decode<T: Decodable>(resource: String, to type: T.Type) throws -> T {
        return try JSONDecoder().decode(T.self, from: data(resource: resource))
    }
    
    func data(resource: String) throws -> Data {
        // Bundle.module.url(forResource:withExtension:) doesn't handle filenames with parentheses well,
        // and the bundle structure differs between Xcode and command line swift test.
        // Try both possible locations:
        
        // Path for Xcode
        let xcodeURL = Bundle.module.bundleURL.appendingPathComponent("Contents/Resources/Resources/\(resource).json")
        if FileManager.default.fileExists(atPath: xcodeURL.path) {
            return try Data(contentsOf: xcodeURL)
        }
        
        // Path for command line swift test
        let cliURL = Bundle.module.bundleURL.appendingPathComponent("Resources/\(resource).json")
        if FileManager.default.fileExists(atPath: cliURL.path) {
            return try Data(contentsOf: cliURL)
        }
        
        throw NSError(domain: "TestError", code: 1, 
                     userInfo: [NSLocalizedDescriptionKey: "Resource \(resource).json not found at \(xcodeURL.path) or \(cliURL.path)"])
    }
}
