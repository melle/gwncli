// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

struct SsidConfig: Decodable {
    public let anonymous: Bool
    public let type: String
    public let name: String
    public let index: Int
    public let id: String
    public let enable: String
    public let ssid: String
    public let ssidHidden: String
    public let clientIPAssignment: String
    public let portalEnable: String
    public let enableSchedule: String
    public let encryption: String
    public let wpaKeyMode: String
    public let wpaEncryption: String
    public let wpaKey: String
    public let bridgeEnable: String
    public let macFiltering: String
    public let isolation: String
    public let dtimPeriod: String
    public let bms: String
    public let mcastToUcast: String
    public let wifi80211k: String
    public let wifi80211v: String
    public let proxyarp: String
    public let uapsd: String
    public let voiceEnterprise: String
    public let wifi80211r: String
    public let staIdleTimeout: String
    public let bintval: String
    public let rssiEnable: String
    public let ratelimitEnable: String
    public let minirate: String
    
    enum CodingKeys: String, CodingKey {
        case anonymous = ".anonymous"
        case type = ".type"
        case name = ".name"
        case index = ".index"
        case id = "id"
        case enable = "enable"
        case ssid = "ssid"
        case ssidHidden = "ssid_hidden"
        case clientIPAssignment = "ClientIPAssignment"
        case portalEnable = "portal_enable"
        case enableSchedule = "enable_schedule"
        case encryption = "encryption"
        case wpaKeyMode = "wpa_key_mode"
        case wpaEncryption = "wpa_encryption"
        case wpaKey = "wpa_key"
        case bridgeEnable = "bridge_enable"
        case macFiltering = "mac_filtering"
        case isolation = "isolation"
        case dtimPeriod = "dtim_period"
        case bms = "bms"
        case mcastToUcast = "mcast_to_ucast"
        case wifi80211k = "11K"
        case wifi80211v = "11V"
        case proxyarp = "proxyarp"
        case uapsd = "uapsd"
        case voiceEnterprise = "voice_enterprise"
        case wifi80211r = "11R"
        case staIdleTimeout = "sta_idle_timeout"
        case bintval = "bintval"
        case rssiEnable = "rssi_enable"
        case ratelimitEnable = "ratelimit_enable"
        case minirate = "minirate"
    }
}
