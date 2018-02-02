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
    
    var language: Language?
    private let queue = DispatchQueue(label: "pl.sochalewski.Scrabbdict.realm.queue", qos: .userInitiated)
    private let configuration = Realm.Configuration(fileURL: Bundle.main.url(forResource: "Database", withExtension: "realm"), readOnly: true)
    
    func check(word: String, completion: @escaping ((Result) -> ())) {
        guard let language = language else { completion(.notExists); return }
        
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
        guard let language = language else { completion(nil); return }
        let letters = language.shouldRemoveDiacritics ? letters.folding(options: .diacriticInsensitive, locale: nil) : letters
        
        queue.async {
            let realm = try! Realm(configuration: self.configuration)
            let words = self.words(from: realm)
            guard words.count > letters.count else { completion(nil); return }
            
            let permutes = letters.lowercased()
                .map { String($0) }
                .permute()
            
            var dividedPermutes = (0...letters.count).map { _ in [String]() }
            
            permutes.forEach { permute in
                dividedPermutes[permute.count].append(permute)
            }
            
            let result = dividedPermutes
                .filter { !$0.isEmpty }
                .map { permute -> LazyMapRandomAccessCollection<Results<StringObject>, String> in
                    let predicate = NSPredicate(format: "%K IN %@", "value", permute)
                    
                    return words[permute.first!.count]
                        .filter(predicate)
                        .map { $0.value }
                }
                .flatMap { $0 }
                .mapToWords(language: language)
            
            Answers.logCustomEvent(withName: "Tiles", customAttributes: ["language" : language.name])
            
            completion(result)
        }
    }
    
    func regex(phrase: String, completion: @escaping (([Word]?) -> ())) {
        guard let language = language else { completion(nil); return }
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
}
