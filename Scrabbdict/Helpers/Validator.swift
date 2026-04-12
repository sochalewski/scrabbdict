//
//  Validator.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 03.05.2017.
//  Copyright © 2017 Piotr Sochalewski. All rights reserved.
//

import Foundation
import FirebaseAnalytics

enum ValidatorError: Error {
    case unknown
    
    var localizedDescription: String {
        switch self {
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
        didSet { reloadDAWG() }
    }
    private let queue = DispatchQueue(label: "pl.sochalewski.Scrabbdict.dawg.queue", qos: .userInitiated)
    private var dawg: DAWG?
    
    func check(word: String, completion: @escaping ((Result<ValidatorResult, ValidatorError>) -> ())) {
        guard let language = language else { completion(.failure(.unknown)); return }
        guard word.isLengthValid else { completion(.success(.notExists)); return }
        
        let word = language.shouldRemoveDiacritics ? word.folding(options: .diacriticInsensitive, locale: nil) : word
        
        queue.async {
            guard let dawg = self.dawg else { completion(.failure(.unknown)); return }

            let exists = dawg.contains(word.lowercased())
            
            Analytics.logEvent("word_check", parameters: ["language" : language.name, "exists" : exists ? "yes" : "no"])
            
            completion(.success(exists ? .exists(points: language.points(for: word)) : .notExists))
        }
    }
    
    func words(from letters: String, completion: @escaping ((Result<[Word], ValidatorError>) -> ())) {
        guard let language = language else { completion(.failure(.unknown)); return }
        guard letters.isLengthValid else { completion(.success([])); return }
        
        let letters = language.shouldRemoveDiacritics ? letters.folding(options: .diacriticInsensitive, locale: nil) : letters
        
        queue.async {
            guard let dawg = self.dawg else { completion(.failure(.unknown)); return }
            
            let result = dawg.words(from: letters.lowercased())
                .mapToWords(language: language)
            
            Analytics.logEvent("tiles", parameters: ["language" : language.name])
            
            completion(.success(result))
        }
    }
    
    func regex(phrase: String, completion: @escaping ((Result<[Word], ValidatorError>) -> ())) {
        guard let language = language else { completion(.failure(.unknown)); return }
        guard phrase.isLengthValid else { completion(.success([])); return }
        
        let phrase = language.shouldRemoveDiacritics ? phrase.folding(options: .diacriticInsensitive, locale: nil) : phrase
        
        queue.async {
            guard let dawg = self.dawg else { completion(.failure(.unknown)); return }

            let result = dawg.words(matching: phrase.lowercased())
                .mapToWords(language: language)
            
            Analytics.logEvent("regex", parameters: ["language" : language.name])
            
            completion(.success(result))
        }
    }
    
    private func reloadDAWG() {
        queue.async {
            guard let language = self.language else { return }
            self.dawg = DAWG(language: language)
        }
    }
}
