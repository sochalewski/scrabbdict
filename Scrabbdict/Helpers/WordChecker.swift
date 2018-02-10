//
//  WordChecker.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import Foundation
import Crashlytics
import RealmSwift

enum Result: Equatable {
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
        case .exists(let points): return "The word exists and is worth \(points) points."
        case .notExists: return "That is not a valid word"
        }
    }
    
    static func ==(lhs: Result, rhs: Result) -> Bool {
        switch (lhs, rhs) {
        case (.exists(let points1), .exists(let points2)): return points1 == points2
        case (.notExists, .notExists): return true
        default: return false
        }
    }
}

struct Word: Equatable {
    let string: String
    let points: Int

    static func ==(lhs: Word, rhs: Word) -> Bool {
        return lhs.string == rhs.string && lhs.points == rhs.points
    }
}

final class WordChecker {
    
    var language: Language? {
        didSet { reloadTrie() }
    }
    private let queue = DispatchQueue(label: "pl.sochalewski.Scrabbdict.realm.queue", qos: .userInitiated)
    private let configuration = Realm.Configuration(fileURL: Bundle.main.url(forResource: "Database", withExtension: "realm"), readOnly: true)
    private var trie: Trie?
    private var isReloadingTrie = false {
        didSet {
            if isAwaitingForWordsFromLetters {
                if let wordsFromLettersPhrase = wordsFromLettersPhrase, let wordsFromLettersCompletion = wordsFromLettersCompletion {
                    words(from: wordsFromLettersPhrase, completion: wordsFromLettersCompletion)
                }
            }
            isAwaitingForWordsFromLetters = false
            wordsFromLettersPhrase = nil
            wordsFromLettersCompletion = nil
        }
    }
    private var isAwaitingForWordsFromLetters = false
    private var wordsFromLettersPhrase: String?
    private var wordsFromLettersCompletion: (([Word]?) -> ())?
    
    func check(word: String, completion: @escaping ((Result) -> ())) {
        guard let language = language, word.isLengthValid else { completion(.notExists); return }
        
        let word = language.shouldRemoveDiacritics ? word.folding(options: .diacriticInsensitive, locale: nil) : word
        
        queue.async {
            let realm = try! Realm(configuration: self.configuration)
            let words = self.words(from: realm)
            guard words.count > word.count && word.count >= 2 else { completion(.notExists); return }
            let predicate = NSPredicate(format: "%K == %@", "value", word.lowercased())
            let exists = !words[word.count].filter(predicate).isEmpty
            
            Answers.logCustomEvent(withName: "Word check", customAttributes: ["language" : language.name, "exists" : exists ? "yes" : "no"])
            
            completion(exists ? .exists(points: language.points(for: word)) : .notExists)
        }
    }
    
    func words(from letters: String, completion: @escaping (([Word]?) -> ())) {
        guard let language = language, letters.isLengthValid else { completion(nil); return }
        let letters = language.shouldRemoveDiacritics ? letters.folding(options: .diacriticInsensitive, locale: nil) : letters
        
        queue.async {
            if self.isReloadingTrie {
                self.isAwaitingForWordsFromLetters = true
                self.wordsFromLettersPhrase = letters
                self.wordsFromLettersCompletion = completion
                return
            }
            
            guard let trie = self.trie else { completion(nil); return }
            
            let permutes = letters.lowercased()
                .map { String($0) }
                .permute()
            
            let result = permutes
                .filter { trie.contains($0) }
                .mapToWords(language: language)
            
            Answers.logCustomEvent(withName: "Tiles", customAttributes: ["language" : language.name])
            
            completion(result)
        }
    }
    
    func regex(phrase: String, completion: @escaping (([Word]?) -> ())) {
        guard let language = language, phrase.isLengthValid else { completion(nil); return }
        let phrase = language.shouldRemoveDiacritics ? phrase.folding(options: .diacriticInsensitive, locale: nil) : phrase
        
        queue.async {
            let realm = try! Realm(configuration: self.configuration)
            let words = self.words(from: realm)
            guard words.count > phrase.count else { completion(nil); return }
            let predicate = NSPredicate(format: "%K LIKE %@", "value", phrase.lowercased())
            let result = words[phrase.count]
                .filter(predicate)
                .map { $0.value }
                .mapToWords(language: language)
            
            Answers.logCustomEvent(withName: "Regex", customAttributes: ["language" : language.name])
            
            completion(result)
        }
    }
    
    private func words(from realm: Realm) -> [List<StringObject>] {
        let predicate = NSPredicate(format: "%K == %@", "_language", language!.rawValue)
        return realm.objects(Vocabulary.self).filter(predicate).first!.words
    }
    
    private func reloadTrie() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let language = self.language else { return }
            self.isReloadingTrie = true
            guard let words = try? String(contentsOf: language.shortWordsURL) else { self.isReloadingTrie = false; return }
            self.trie = Trie(words.components(separatedBy: .newlines))
            self.isReloadingTrie = false
        }
    }
}
