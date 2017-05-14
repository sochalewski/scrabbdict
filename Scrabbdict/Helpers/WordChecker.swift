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
    private var dictionaryTrie: Trie?
    private var dictionaryFileURL: URL?
    
    func check(word: String) -> Result {
        guard let language = language else { return Result.notExists }
        
        let word = language.shouldRemoveDiacritics ? word.folding(options: .diacriticInsensitive, locale: nil) : word
        
        if isMultipartDictionarySwapRequired(for: word) {
            updateDictionary(multipartIndex: word.characters.count)
        }
        
        let exists = dictionaryTrie?.contains(word.lowercased()) ?? false
        
        return exists ? Result.exists(points: language.points(for: word)) : Result.notExists
    }
    
    func words(from letters: String) -> [Word]? {
        guard let language = language else { return nil }
        let letters = language.shouldRemoveDiacritics ? letters.folding(options: .diacriticInsensitive, locale: nil) : letters
        
        if isMultipartDictionarySwapRequired(for: letters) {
            updateDictionary(multipartIndex: letters.characters.count)
        }
        guard let dictionaryTrie = dictionaryTrie else { return nil }
        let words = permute(list: letters.characters.map { String($0).lowercased() }).filter { dictionaryTrie.contains($0) }
        
        return words
            .map { Word(string: $0, points: language.points(for: $0)) }
            .sorted { $0.points > $1.points }
    }
    
    func regex(from phrase: String) -> [Word]? {
        guard let language = language else { return nil }
        
        if isMultipartDictionarySwapRequired(for: phrase) {
            updateDictionary(multipartIndex: phrase.characters.count)
        }
        return dictionaryTrie?
            .findPattern(phrase.lowercased())
            .map { Word(string: $0, points: language.points(for: $0)) }
            .sorted { $0.points > $1.points }
    }
    
    private func isMultipartDictionarySwapRequired(for word: String) -> Bool {
        guard let language = language, let dictionaryFileURL = dictionaryFileURL else { return false }
        
        return language.isMultipartFile && dictionaryFileURL != language.fileURL(multipartIndex: word.characters.count)
    }
    
    private func updateDictionary(multipartIndex: Int? = nil) {
        dictionaryFileURL = language?.fileURL(multipartIndex: multipartIndex)
        guard let url = dictionaryFileURL, let words = try? String(contentsOf: url, encoding: .utf8) else { dictionaryTrie = nil; return }
        let dictionary = words.components(separatedBy: .whitespacesAndNewlines)
        dictionaryTrie = Trie(dictionary)
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
