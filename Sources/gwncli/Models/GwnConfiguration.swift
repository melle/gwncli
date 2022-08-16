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
