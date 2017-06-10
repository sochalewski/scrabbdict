//
//  Language.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import Foundation
import TinySwift

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
    
    var isMultipartFile: Bool {
        return self == .polish 
    }
    
    var multipartFileIndexes: CountableClosedRange<Int>? {
        return self == .polish ? 11...15 : nil
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
            return "Polish open dictionary created by sjp.pl.\nDue to number of words it can be slower than other dictionaries.\n\nNumber of words: ~2,825,542"
        case .french:
            return "The official word list for Francophone Scrabble™ based on L'Officiel de jeu Scrabble OSD6\n\nNumber of words: 386,264"
        }
    }
    
    private var fileName: String {
        return rawValue
    }
    
    private var letterPoints: [Character: Int] {
        switch self {
        case .englishUS, .englishGB:
            return ["A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4, "I": 1, "J": 8, "K": 5, "L": 1, "M": 3, "N": 1, "O": 1, "P": 3, "Q": 10, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 4, "X": 8, "Y": 4, "Z": 10]
        case .polish:
            return ["A": 1, "Ą": 5, "B": 3, "C": 2, "Ć": 6, "D": 2, "E": 1, "Ę": 5, "F": 5, "G": 3, "H": 3, "I": 1, "J": 3, "K": 2, "L": 2, "Ł": 3, "M": 2, "N": 1, "Ń": 7, "O": 1, "Ó": 5, "P": 2, "R": 1, "S": 1, "Ś": 5, "T": 2, "U": 3, "V": 4, "W": 1, "X": 8, "Y": 2, "Z": 1, "Ź": 9, "Ż": 5]
        case .french:
            return ["A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4, "I": 1, "J": 8, "K": 10, "L": 1, "M": 2, "N": 1, "O": 1, "P": 3, "Q": 8, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 10, "X": 10, "Y": 10, "Z": 10]
        }
    }
    
    func fileURL(multipartIndex: Int? = nil) -> URL? {
        var resource = fileName
        if let multipartFileIndexes = multipartFileIndexes, let multipartIndex = multipartIndex, multipartFileIndexes.contains(multipartIndex) {
            resource += "_\(multipartIndex)"
        }
        
        return Bundle.main.url(forResource: resource, withExtension: "txt")
    }
    
    func points(`for` word: String) -> Int {
        return word.uppercased().characters.flatMap({ letterPoints[$0] }).sum
    }
}
