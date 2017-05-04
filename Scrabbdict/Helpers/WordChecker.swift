//
//  WordChecker.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import Foundation

enum Result {
    case exists(points: Int)
    case notExists
    
    var title: String {
        switch self {
        case .exists: return "Hooray!"
        case .notExists: return "Oops!"
        }
    }
    
    var message: String {
        switch self {
        case .exists(let points): return "Word exists and is worth \(points) points."
        case .notExists: return "Word does not exist."
        }
    }
}

typealias Word = (string: String, points: Int)

final class WordChecker {
    
    var language: Language? {
        didSet {
            updateDictionary()
        }
    }
    private var dictionary: Set<String>?
    private var dictionaryFileURL: URL?
    
    func check(word: String) -> Result {
        guard let language = language else { return Result.notExists }
        
        let word = language.shouldRemoveDiacritics ? word.folding(options: .diacriticInsensitive, locale: nil) : word
        
        if isMultipartDictionarySwapRequired(for: word) {
            updateDictionary(multipartIndex: word.characters.count)
        }
        
        let exists = dictionary!.contains(word.lowercased())
        
        return exists ? Result.exists(points: language.points(for: word)) : Result.notExists
    }
    
    func words(from letters: String) -> [Word]? {
        guard let language = language else { return nil }
        let letters = language.shouldRemoveDiacritics ? letters.folding(options: .diacriticInsensitive, locale: nil) : letters
        
        if isMultipartDictionarySwapRequired(for: letters) {
            updateDictionary(multipartIndex: letters.characters.count)
        }
        guard let dictionary = dictionary else { return nil }
        let words = permute(list: letters.characters.map { String($0).lowercased() }).filter { dictionary.contains($0) }
        
        return words
            .map { Word(string: $0, points: language.points(for: $0)) }
            .sorted { $0.points > $1.points }
    }
    
    func regex(from phrase: String) -> [Word]? {
        let pattern = phrase.lowercased().scrabbleRegex
        guard let language = language, let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        if isMultipartDictionarySwapRequired(for: phrase) {
            updateDictionary(multipartIndex: phrase.characters.count)
        }
        
        return dictionary?
            .map { word in
                return regex.matches(in: word, options: [], range: NSRange(location: 0, length: word.characters.count)).map { (result: $0, word: word) }
            }
            .flatMap { $0 }
            .map { $0.word }
            .set
            .map { Word(string: $0, points: language.points(for: $0)) }
            .sorted { $0.points > $1.points }
    }
    
    private func isMultipartDictionarySwapRequired(for word: String) -> Bool {
        guard let language = language, let dictionaryFileURL = dictionaryFileURL else { return false }
        
        return language.isMultipartFile && dictionaryFileURL != language.fileURL(multipartIndex: word.characters.count)
    }
    
    private func updateDictionary(multipartIndex: Int? = nil) {
        dictionaryFileURL = language?.fileURL(multipartIndex: multipartIndex)
        guard let url = dictionaryFileURL, let words = try? String(contentsOf: url, encoding: .utf8) else { dictionary = nil; return }
        dictionary = Set(words.components(separatedBy: .whitespacesAndNewlines))
    }
    
    private func permute(list: [String], minimumStringLength: Int = 2) -> Set<String> {
        func permute(from fromList: [String], to toList: [String], minimumStringLength: Int, set: inout Set<String>) {
            if toList.count >= minimumStringLength {
                set.insert(toList.joined())
            }
            if !fromList.isEmpty {
                for (index, item) in fromList.enumerated() {
                    var newFrom = fromList
                    newFrom.remove(at: index)
                    permute(from: newFrom, to: toList + [item], minimumStringLength: minimumStringLength, set: &set)
                }
            }
        }
        
        var set = Set<String>()
        permute(from: list, to: [], minimumStringLength: minimumStringLength, set: &set)
        
        return set
    }
}

extension String {
    var scrabbleRegex: String {
        return "^\(replacingOccurrences(of: " ", with: ".").replacingOccurrences(of: "?", with: "."))$"
    }
}
