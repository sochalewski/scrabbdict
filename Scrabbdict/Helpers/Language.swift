//
//  Language.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import Foundation

enum Language: String, CustomStringConvertible {
    case englishGB = "en_GB_sowpods"
    case englishUS = "en_US_twl"
    case polish = "pl_PL"
    case french = "fr_ODS6"
    
    static let allValues: [Language] = [.englishGB, .englishUS, .french, .polish]
    
    static var current: Language {
        get {
            guard let language = UserDefaults.standard.string(forKey: "dictionaryLang") else { return .englishUS }
            return Language(rawValue: language)!
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
            return "English word list used in tournament Scrabble™ in most countries except the USA, Thailand and Canada\n\nNumber of words: 267,751"
        case .englishUS:
            return "Official Tournament and Club Word List\nEnglish official word authority for tournament Scrabble™ in the USA, Canada and Thailand\n\nNumber of words: 178,691"
        case .polish:
            return "Polish open dictionary by sjp.pl (CC BY 4.0).\n\nNumber of words: 2,964,259"
        case .french:
            return "The official word list for Francophone Scrabble™ based on L'Officiel de jeu Scrabble OSD6\n\nNumber of words: 386,264"
        }
    }
}
