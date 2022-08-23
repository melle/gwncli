// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

struct BandwidthRule: Decodable {
    let anonymous: Bool
    let ruletype: String
    let name: String
    let index: Int
    let id: String
    let enabled: String
    let idType: String
    let urate: String
    let drate: String
    let ssidId: String
    
    enum CodingKeys: String, CodingKey {
        case anonymous = ".anonymous"
        case ruletype = ".type"
        case name = ".name"
        case index = ".index"
        case id
        case enabled
        case idType = "type"
        case urate
        case drate
        case ssidId = "ssid_id"
    }
}

extension BandwidthRule: CustomStringConvertible {
    var description: String {
        "\(name)\t\((enabled == "1" ? "[enabled] " : "[disabled]"))\tU: \(urate)\tD:\(drate)\t\(idType)\t\(id)\tSSID: \(ssidId)"
    }
    
    func description(humanReadableSsid: String, aliases: GwnContext.Aliases) -> String {
        let idAndAlias = aliases.aliasFor(id: id)
        return "\(name)\t\((enabled == "1" ? "[enabled] " : "[disabled]"))\tU: \(urate)\tD:\(drate)\t\(idType): \(idAndAlias)\tSSID: \(ssidId) \"\(humanReadableSsid)\""
    }
}
