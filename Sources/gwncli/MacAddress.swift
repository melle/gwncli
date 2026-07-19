// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

enum MacAddress {

    /// Normalizes a MAC address to the uppercased, colon-separated form used by bandwidth rules,
    /// i.e. "7235cf2ab237" or "72-35-cf-2a-b2-37" become "72:35:CF:2A:B2:37".
    /// Returns nil if the input does not contain exactly 12 hex digits.
    static func normalized(_ raw: String) -> String? {
        guard raw.allSatisfy({ $0.isHexDigit || $0 == ":" || $0 == "-" || $0 == "." }) else {
            return nil
        }
        let hexDigits = raw.filter(\.isHexDigit).uppercased()
        guard hexDigits.count == 12 else {
            return nil
        }
        var octets: [Substring] = []
        var index = hexDigits.startIndex
        while index < hexDigits.endIndex {
            let next = hexDigits.index(index, offsetBy: 2)
            octets.append(hexDigits[index..<next])
            index = next
        }
        return octets.joined(separator: ":")
    }

    /// True when bit 1 of the first octet is set - a locally administered address,
    /// used by iOS/Android for randomized ("private") MAC addresses.
    static func isLocallyAdministered(_ mac: String) -> Bool {
        guard let normalized = normalized(mac),
              let firstOctet = UInt8(normalized.prefix(2), radix: 16) else {
            return false
        }
        return firstOctet & 0x02 != 0
    }
}
