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

    var diacriticInsensitiveLocale: Locale? {
        switch self {
        case .french: .init(identifier: "fr_FR")
        default: nil
        }
    }

    var name: LocalizedStringResource {
        switch self {
        case .englishCSW: .languageEnglishCswName
        case .englishNWL: .languageEnglishNwlName
        case .englishWOW: .languageEnglishWowName
        case .polish: .languagePolishName
        case .french: .languageFrenchName
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .englishCSW: .languageEnglishCswDescription
        case .englishNWL: .languageEnglishNwlDescription
        case .englishWOW: .languageEnglishWowDescription
        case .polish: .languagePolishDescription
        case .french: .languageFrenchDescription
        }
    }

    var wordCount: Int {
        switch self {
        case .englishCSW: 280_887
        case .englishNWL: 196_601
        case .englishWOW: 195_383
        case .french: 407_128
        case .polish: 2_901_474
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
