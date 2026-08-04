//
//  Scrabbdict
//  Copyright © 2017 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

enum Language: String, CaseIterable, Hashable, Sendable {
    /// CSW24 (Collins Scrabble Words)
    case englishCSW = "en_GB_CSW"
    /// NWL2023 (NASPA Word List)
    case englishNWL = "en_US_NWL"
    /// WOW24 (WGPO Official Words)
    case englishWOW = "en_WOW"
    /// ODS 9 (L'Officiel du Scrabble)
    case french = "fr_ODS"
    /// OSPS Update 52 (Oficjalny słownik polskiego scrabblisty)
    case polish = "pl_OSPS"

    /// The locale used to remove diacritics from user input before DAWG lookup; `nil` preserves them.
    var diacriticInsensitiveLocale: Locale? {
        switch self {
        case .french: .init(identifier: "fr_FR")
        default: nil
        }
    }

    init?(rawValue: String) {
        let components = rawValue
            .split { $0 == "_" || $0 == "-" }
            .map { $0.lowercased() }

        switch components.first {
        case "en":
            switch components.dropFirst().first {
            case "gb": self = .englishCSW
            case "us": self = .englishNWL
            case "wow": self = .englishWOW
            default: return nil
            }
        case "fr":
            self = .french
        case "pl":
            self = .polish
        default:
            return nil
        }
    }
}
