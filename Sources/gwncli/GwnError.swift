// Copyright © 2022 Thomas Mellenthin (privat). All rights reserved.

import Foundation

enum GwnError: Error {
    case networkError(Error)
    case emptyLoginResponse
    case freeForm(String)
}
