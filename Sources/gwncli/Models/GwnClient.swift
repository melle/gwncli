// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

// JSON response when querying controller.core.get_clients_count
struct GwnClientsCountResponse: Decodable, Sendable {
    public let jsonrpc: String
    public let id: Int
    @LossyCodableList public var result: [GwnClientsCount]
}

struct GwnClientsCount: Decodable, Sendable {
    public let count: Int
    public let online: Int
}

// JSON response when querying controller.core.get_clients_range
struct GwnClientsResponse: Decodable, Sendable {
    public let jsonrpc: String
    public let id: Int
    @LossyCodableList public var result: [GwnClientList]
}

struct GwnClientList: Decodable, Sendable {
    public let clients: [GwnClient]
    public let count: Int
    public let online: Int
}

struct GwnClient: Decodable, Sendable {
    public let wired: Int
    public let online: Int
    public let associatedAp: String
    /// Bare lowercase hex without separators, i.e. "7235cf2ab237"
    public let clientMac: String
    /// The SSID name (not the ssid-id), i.e. "MyWifi"
    public let ssid: String
    public let clientIpv4: String
    public let hostname: String
    public let os: String
    public let lastSeen: Int

    enum CodingKeys: String, CodingKey {
        case wired
        case online
        case associatedAp = "associated_ap"
        case clientMac = "client_mac"
        case ssid
        case clientIpv4 = "client_ipv4"
        case hostname
        case os
        case lastSeen = "last_seen"
    }
}
