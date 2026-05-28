//
//  Scrabbdict
//  Copyright © 2017 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

enum Language: String, CaseIterable, Sendable {
    /// CSW24 (Collins Scrabble Words)
    case englishGB = "en_GB_csw"
    /// NWL2023 (NASPA Word List)
    case englishUS = "en_US_nwl"
    /// ODS 9 (L'Officiel du Scrabble)
    case french = "fr_ODS"
    /// OSPS Update 52 (Oficjalny słownik polskiego scrabblisty)
    case polish = "pl_OSPS"

    var shouldRemoveDiacritics: Bool {
        self == .french
    }

    var name: LocalizedStringResource {
        switch self {
        case .englishGB: .languageEnglishGbName
        case .englishUS: .languageEnglishUsName
        case .polish: .languagePolishName
        case .french: .languageFrenchName
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .englishGB: .languageEnglishGbDescription
        case .englishUS: .languageEnglishUsDescription
        case .polish: .languagePolishDescription
        case .french: .languageFrenchDescription
        }
    }

    var wordCount: Int {
        switch self {
        case .englishGB: 280_887
        case .englishUS: 196_601
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
            case "gb": self = .englishGB
            case "us": self = .englishUS
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
