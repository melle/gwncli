// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

enum GrandstreamConfigEntry: Decodable {
    case ssid(SsidConfig)
    case rule(BandwidthRule)
    case ignored(String)
    
    enum CodingKeys: String, CodingKey {
        case type = ".type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: GrandstreamConfigEntry.CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)
        switch typeString {
        case "bwctrl-rule":
            self = try .rule(BandwidthRule.init(from: decoder))
        case "additional_ssid":
            self = try .ssid(SsidConfig.init(from: decoder))
        default:
            self = .ignored(typeString)
        }
    }
}
