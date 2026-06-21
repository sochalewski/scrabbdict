//
//  Scrabbdict
//  Copyright © 2017 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import Foundation

enum ValidatorError: Error, Hashable {
    case dictionaryUnavailable

    var description: LocalizedStringResource {
        switch self {
        case .dictionaryUnavailable:
            .errorDictionaryUnavailable
        }
    }
}

extension ValidatorError: LocalizedError {
    var errorDescription: String? {
        String(localized: description)
    }
}

enum ValidatorResult: Hashable, Sendable {
    case valid(points: Int)
    case invalid
}

actor Validator {
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.languageStorage.current) var currentLanguage

    private var dawg: DAWG?
    private var language: Language?

    func check(word: String) async throws(ValidatorError) -> ValidatorResult {
        let (language, dawg) = try validatorDependencies()
        guard word.isLengthValid else { return .invalid }

        let normalizedWord = language.shouldRemoveDiacritics ? word.folding(options: .diacriticInsensitive, locale: nil) : word
        let exists = dawg.contains(normalizedWord.lowercased())

        analytics.logWordChecked(language, exists)

        return exists ? .valid(points: language.points(for: normalizedWord)) : .invalid
    }

    func words(from letters: String) async throws(ValidatorError) -> [Word] {
        let (language, dawg) = try validatorDependencies()
        guard letters.isLengthValid else { return [] }

        let normalizedLetters = language.shouldRemoveDiacritics ? letters.folding(options: .diacriticInsensitive, locale: nil) : letters
        let result = dawg.words(from: normalizedLetters.lowercased())
            .mapToWords(language: language)

        analytics.logTilesSearch(language)

        return result
    }

    func regex(phrase: String) async throws(ValidatorError) -> [Word] {
        let (language, dawg) = try validatorDependencies()
        guard phrase.isLengthValid else { return [] }

        let normalizedPhrase = language.shouldRemoveDiacritics ? phrase.folding(options: .diacriticInsensitive, locale: nil) : phrase
        let result = dawg.words(matching: normalizedPhrase.lowercased())
            .mapToWords(language: language)

        analytics.logRegexSearch(language)

        return result
    }

    private func validatorDependencies() throws(ValidatorError) -> (Language, DAWG) {
        let currentLanguage = currentLanguage()

        if language != currentLanguage {
            language = currentLanguage
            dawg = .init(language: currentLanguage)
        } else if dawg == nil {
            dawg = .init(language: currentLanguage)
        }

        guard let dawg else { throw .dictionaryUnavailable }
        return (currentLanguage, dawg)
    }
}
