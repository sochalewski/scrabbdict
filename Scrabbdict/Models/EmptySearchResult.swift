//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

enum EmptySearchResult: Hashable, Sendable {
    case pattern
    case rack

    var title: LocalizedStringResource {
        switch self {
        case .pattern: .emptyResultPatternTitle
        case .rack: .emptyResultRackTitle
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .pattern: .emptyResultPatternMessage
        case .rack: .emptyResultRackMessage
        }
    }
}
