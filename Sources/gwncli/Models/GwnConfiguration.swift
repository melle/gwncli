// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

// JSON response when querying the configuration
struct GwnConfigurationResponse: Decodable {
    public let jsonrpc: String
    public let id: Int
    @LossyCodableList public var result: [GwnConfiguration]
}

struct GwnConfiguration: Decodable {
    public let values: Dictionary<String, GwnConfigEntry>
    
    enum CodingKeys: String, CodingKey {
        case values
    }
}

extension GwnConfiguration {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: GwnConfiguration.CodingKeys.self)
        let values = try container.decode(Dictionary<String, GwnConfigEntry>.self, forKey: .values)
        self = .init(values: values)
    }
}

extension GwnConfiguration {
    /// Returns all config entries that represent a bandwidth rule.
    public var bandwidthRules: [BandwidthRule] {
        self.values.values.compactMap{ $0.rule }
    }

    /// Returns all config entries that represent an SSID definition
    public var ssids: [SsidConfig] {
        self.values.values.compactMap{ $0.ssid }
    }

    public var nextBandwidthRuleName: String {
        guard let lastRule = bandwidthRules
            .sorted(by: { $0.name < $1.name })
            .last?
            .name else {
            // no rules defined, define the first one
            return "rule0"
        }
        
        let indexString = lastRule[String.Index(utf16Offset: 4, in: lastRule)...]
        guard var index = Int(indexString) else {
            return "rule0"
        }
        index += 1
        
        return "rule\(index)"
    }
    
    /// Return the SSID string for the give ID or the ID as fallback.
    public func ssidStringFor(id: String) -> String {
        ssids.first { $0.id == id }?.ssid ?? id
    }

    /// Lists all bandwidth rules properly formatted for console output
    public var bandwidthRulesFormatted: String {
        bandwidthRules
            .sorted(by: { lhs, rhs in
                (lhs.id, lhs.ssidId) < (rhs.id, rhs.ssidId)
            })
            .map { $0.description(humanReadableSsid: ssidStringFor(id: $0.ssidId )) }
            .joined(separator: "\n")
    }
}
