//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

enum SearchMode: Int, CaseIterable, Hashable, Sendable {
    case auto = 0
    case check = 1
    case rack = 2

    var title: String {
        switch self {
        case .auto: "Auto"
        case .check: "Check"
        case .rack: "Rack"
        }
    }

    var description: String {
        switch self {
        case .auto: "Checks exact words, or treats ? as a one-letter wildcard."
        case .check: "Only checks whether the exact entered word is valid."
        case .rack: "Finds words from entered letters, or treats ? as a one-letter wildcard."
        }
    }
}
