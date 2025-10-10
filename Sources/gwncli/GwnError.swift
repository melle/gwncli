// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

enum GwnError: Error, Sendable {
    case networkError(_ error: Error, file: String = #file, line: Int = #line)
    case emptyLoginResponse
    case ruleNotFound(String)
    case freeForm(String)
    
    var underlyingError: Error? {
        if case let .networkError(err, _, _) = self {
            return err
        }
        return nil
    }
}
