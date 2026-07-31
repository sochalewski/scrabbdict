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
    @Dependency(\.crashlyticsClient) var crashlytics
    @Dependency(\.languageStorage.current) var currentLanguage

    private var dawg: DAWG?
    private var language: Language?

    func check(word: String) async throws(ValidatorError) -> ValidatorResult {
        let (language, dawg) = try validatorDependencies()
        guard word.isLengthValid else { return .invalid }

        let normalizedWord = normalized(word, language: language)
        let exists = dawg.contains(normalizedWord)

        analytics.logWordChecked(language, exists)

        return exists ? .valid(points: language.points(for: normalizedWord)) : .invalid
    }

    func words(from letters: String) async throws(ValidatorError) -> [Word] {
        let (language, dawg) = try validatorDependencies()
        guard letters.isLengthValid else { return [] }

        let normalizedLetters = normalized(letters, language: language)
        let result = dawg.words(from: normalizedLetters)
            .mapToWords(language: language)

        analytics.logTilesSearch(language)

        return result
    }

    func regex(phrase: String) async throws(ValidatorError) -> [Word] {
        let (language, dawg) = try validatorDependencies()
        guard phrase.isLengthValid else { return [] }

        let normalizedPhrase = normalized(phrase, language: language)
        let result = dawg.words(matching: normalizedPhrase)
            .mapToWords(language: language)

        analytics.logRegexSearch(language)

        return result
    }

    private func loadDAWG(language: Language) -> DAWG? {
        do {
            return try DAWG(language: language)
        } catch {
            crashlytics.log("DAWG initialization failed for \(language.rawValue): \(String(describing: error))")
            return nil
        }
    }

    private func validatorDependencies() throws(ValidatorError) -> (Language, DAWG) {
        let currentLanguage = currentLanguage()

        if language != currentLanguage {
            language = currentLanguage
            dawg = loadDAWG(language: currentLanguage)
        } else if dawg == nil {
            dawg = loadDAWG(language: currentLanguage)
        }

        guard let dawg else { throw .dictionaryUnavailable }
        return (currentLanguage, dawg)
    }

    private func normalized(_ input: String, language: Language) -> String {
        let precomposed = input.precomposedStringWithCanonicalMapping
        let normalized = if let locale = language.diacriticInsensitiveLocale {
            precomposed.folding(options: .diacriticInsensitive, locale: locale)
        } else {
            precomposed
        }
        return normalized.lowercased()
    }
}
