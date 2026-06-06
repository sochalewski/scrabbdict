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

    var title: LocalizedStringResource {
        switch self {
        case .auto: .searchModeAutoTitle
        case .check: .searchModeCheckTitle
        case .rack: .searchModeRackTitle
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .auto: .searchModeAutoDescription
        case .check: .searchModeCheckDescription
        case .rack: .searchModeRackDescription
        }
    }

    var accessibilityDescription: String {
        String(localized: description)
            .replacingOccurrences(of: "?", with: String(localized: .searchModeQuestionMark))
    }

    var name: String {
        switch self {
        case .auto: "auto"
        case .check: "check"
        case .rack: "rack"
        }
    }
}
