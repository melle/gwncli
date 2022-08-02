// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

/// Ignores invalid elements when decoding instead of failing entirely.
/// From https://www.swiftbysundell.com/articles/ignoring-invalid-json-elements-codable/
@propertyWrapper
struct LossyCodableList<Element> {
    var elements: [Element]
    
    var wrappedValue: [Element] {
        get { elements }
        set { elements = newValue }
    }
}

extension LossyCodableList: Decodable where Element: Decodable {
    private struct ElementWrapper: Decodable {
        var element: Element?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            element = try? container.decode(Element.self)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let wrappers = try container.decode([ElementWrapper].self)
        elements = wrappers.compactMap(\.element)
    }
}
