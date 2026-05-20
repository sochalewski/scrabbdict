//
//  Scrabbdict
//  Copyright © 2017 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

enum Language: String, CaseIterable, CustomStringConvertible, Sendable {
    /// CSW24 (Collins Scrabble Words)
    case englishGB = "en_GB_sowpods"
    /// NWL2023 (NASPA Word List)
    case englishUS = "en_US_twl"
    /// ODS 9 (L'Officiel du Scrabble)
    case french = "fr_ODS"
    /// sjp-20260401
    case polish = "pl_PL"

    var shouldRemoveDiacritics: Bool {
        self == .french
    }

    var name: String {
        switch self {
        case .englishGB: "English SOWPODS"
        case .englishUS: "English TWL"
        case .polish: "Polish"
        case .french: "French"
        }
    }

    var description: String {
        switch self {
        case .englishGB:
            "English word list used for tournament Scrabble™ in most countries except the USA, Thailand, and Canada\n\nNumber of words: 280,887"
        case .englishUS:
            "Official Tournament and Club Word List\nOfficial English word authority for tournament Scrabble™ in the USA, Canada, and Thailand\n\nNumber of words: 196,601"
        case .polish:
            "Polish open dictionary by sjp.pl (CC BY 4.0)\n\nNumber of words: 3,238,764"
        case .french:
            "The official word list for Francophone Scrabble™ based on L'Officiel de jeu Scrabble ODS9\n\nNumber of words: 407,128"
        }
    }
}
