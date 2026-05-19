//
//  Language.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import Foundation

enum Language: String, CaseIterable, CustomStringConvertible {
    /// CSW24 (Collins Scrabble Words)
    case englishGB = "en_GB_sowpods"
    /// NWL2023 (NASPA Word List)
    case englishUS = "en_US_twl"
    /// ODS 9 (L'Officiel du Scrabble)
    case french = "fr_ODS"
    /// sjp-20260401
    case polish = "pl_PL"
    
    static var current: Language {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "dictionaryLang"), let language = Language(rawValue: rawValue) else { return .englishUS }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "dictionaryLang")
            UserDefaults.standard.synchronize()
        }
    }
    
    var shouldRemoveDiacritics: Bool {
        return self == .french
    }
    
    var name: String {
        switch self {
        case .englishGB: return "English SOWPODS"
        case .englishUS: return "English TWL"
        case .polish: return "Polish"
        case .french: return "French"
        }
    }
    
    var description: String {
        switch self {
        case .englishGB:
            return "English word list used in tournament Scrabble™ in most countries except the USA, Thailand and Canada\n\nNumber of words: 280,887"
        case .englishUS:
            return "Official Tournament and Club Word List\nEnglish official word authority for tournament Scrabble™ in the USA, Canada and Thailand\n\nNumber of words: 196,601"
        case .polish:
            return "Polish open dictionary by sjp.pl (CC BY 4.0)\n\nNumber of words: 3,238,764"
        case .french:
            return "The official word list for Francophone Scrabble™ based on L'Officiel de jeu Scrabble ODS9\n\nNumber of words: 407,128"
        }
    }
}
