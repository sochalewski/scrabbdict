//
//  Validator.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import Foundation
import Crashlytics
import RealmSwift

enum Result<T> {
    case success(T)
    case error(ValidatorError)
}

enum ValidatorError: Error {
    case tooManyLetters
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .tooManyLetters: return "You've typed more letters than tiles you've got. Choose STANDARD or create a shorter query to proceed."
        case .unknown: return "Something went wrong."
        }
    }
}

enum ValidatorResult: Equatable {
    case exists(points: Int)
    case notExists
}

struct Word: Equatable {
    let string: String
    let points: Int
}

final class Validator {
    
    var language: Language? {
        didSet { reloadTrie() }
    }
    private let queue = DispatchQueue(label: "pl.sochalewski.Scrabbdict.realm.queue", qos: .userInitiated)
    private let configuration = Realm.Configuration(fileURL: Bundle.main.url(forResource: "Database", withExtension: "realm"), readOnly: true)
    private var trie: Trie? {
        didSet {
            queue.async { self.isReloadingTrie = false }
        }
    }
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
    private var wordsFromLettersCompletion: ((Result<[Word]>) -> ())?
    
    func check(word: String, completion: @escaping ((Result<ValidatorResult>) -> ())) {
        guard let language = language else { completion(.error(.unknown)); return }
        guard word.isLengthValid else { completion(.success(.notExists)); return }
        
        let word = language.shouldRemoveDiacritics ? word.folding(options: .diacriticInsensitive, locale: nil) : word
        
        queue.async {
            let words = self.words()
            let predicate = NSPredicate(format: "%K == %@", "value", word.lowercased())
            let exists = !words[word.count].filter(predicate).isEmpty
            
            Answers.logCustomEvent(withName: "Word check", customAttributes: ["language" : language.name, "exists" : exists ? "yes" : "no"])
            
            completion(.success(exists ? .exists(points: language.points(for: word)) : .notExists))
        }
    }
    
    func words(from letters: String, completion: @escaping ((Result<[Word]>) -> ())) {
        guard let language = language else { completion(.error(.unknown)); return }
        guard letters.count <= String.maximumTrieWordLength else { completion(.error(.tooManyLetters)); return }
        guard letters.isLengthValid else { completion(.success([])); return }
        
        let letters = language.shouldRemoveDiacritics ? letters.folding(options: .diacriticInsensitive, locale: nil) : letters
        
        queue.async {
            if self.isReloadingTrie {
                self.isAwaitingForWordsFromLetters = true
                self.wordsFromLettersPhrase = letters
                self.wordsFromLettersCompletion = completion
                return
            }
            
            guard let trie = self.trie else { completion(.error(.unknown)); return }
            
            let permutes = letters.lowercased()
                .map { String($0) }
                .permute()
            
            let result = permutes
                .filter { trie.contains($0) }
                .mapToWords(language: language)
            
            Answers.logCustomEvent(withName: "Tiles", customAttributes: ["language" : language.name])
            
            completion(.success(result))
        }
    }
    
    func regex(phrase: String, completion: @escaping ((Result<[Word]>) -> ())) {
        guard let language = language else { completion(.error(.unknown)); return }
        guard phrase.isLengthValid else { completion(.success([])); return }
        
        let phrase = language.shouldRemoveDiacritics ? phrase.folding(options: .diacriticInsensitive, locale: nil) : phrase
        
        queue.async {
            let words = self.words()
            let predicate = NSPredicate(format: "%K LIKE %@", "value", phrase.lowercased())
            let result = words[phrase.count]
                .filter(predicate)
                .map { $0.value }
                .mapToWords(language: language)
            
            Answers.logCustomEvent(withName: "Regex", customAttributes: ["language" : language.name])
            
            completion(.success(result))
        }
    }
    
    private func words() -> [List<StringObject>] {
        let realm = try! Realm(configuration: self.configuration)
        let predicate = NSPredicate(format: "%K == %@", "_language", language!.rawValue)
        return realm.objects(Vocabulary.self).filter(predicate).first!.words
    }
    
    private func reloadTrie() {
        queue.async {
            self.isReloadingTrie = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                let words = self.words()
                    .prefix(String.maximumTrieWordLength + 1)
                    .flatMap { $0.map { $0.value } }

                self.trie = Trie(words)
            }
        }
    }
}
