// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

// JSON response when querying the configuration
struct GrandstreamConfigurationResponse: Decodable {
    public let jsonrpc: String
    public let id: Int
    @LossyCodableList public var result: [GrandstreamConfiguration]
}

struct GrandstreamConfiguration: Decodable {
    public let values: Dictionary<String, GrandstreamConfigEntry>
    
    enum CodingKeys: String, CodingKey {
        case values
    }
}

extension GrandstreamConfiguration {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: GrandstreamConfiguration.CodingKeys.self)
        let values = try container.decode(Dictionary<String, GrandstreamConfigEntry>.self, forKey: .values)
        self = .init(values: values)
    }
}

extension GrandstreamConfiguration {
    /// Returns all config entries that represent a bandwidth rule.
    public var bandwidthRules: [BandwidthRule] {
        self.values.values.compactMap{ $0.rule }
    }
    
    /// Lists all bandwidth rules properly formatted for console outpu
    public var bandwidthRulesFormatted: String {
        bandwidthRules
            .sorted(by: { lhs, rhs in
                (lhs.id, lhs.ssid) < (rhs.id, rhs.ssid)
            })
            .map { $0.description}
            .joined(separator: "\n")
    }
}
