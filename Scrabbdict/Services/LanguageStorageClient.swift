//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import Foundation
import Sharing

struct LanguageStorageClient: Sendable {
    var current: @Sendable () -> Language
    var setCurrent: @Sendable (Language) -> Void
}

extension LanguageStorageClient: DependencyKey {
    static let liveValue = Self(
        current: {
            @Dependency(\.defaultAppStorage) var appStorage

            guard
                let rawValue = appStorage.string(forKey: storageKey),
                let language = Language(rawValue: rawValue)
            else { return .current }
            return language
        },
        setCurrent: { language in
            @Dependency(\.defaultAppStorage) var appStorage

            appStorage.set(language.rawValue, forKey: storageKey)
        }
    )

    static let testValue = Self(
        current: unimplemented("\(Self.self).current", placeholder: .englishUS),
        setCurrent: unimplemented("\(Self.self).setCurrent")
    )

    static let previewValue = Self(
        current: { .englishUS },
        setCurrent: { _ in }
    )
}

extension DependencyValues {
    var languageStorage: LanguageStorageClient {
        get { self[LanguageStorageClient.self] }
        set { self[LanguageStorageClient.self] = newValue }
    }
}

private extension Language {
    static var current: Self {
        @Dependency(\.locale) var locale

        switch locale.language.languageCode?.identifier.lowercased() {
        case "en":
            switch locale.language.region?.identifier.uppercased() {
            case "US", "CA": return .englishUS
            default: return .englishGB
            }
        case "fr": return .french
        case "pl": return .polish
        default: return .englishGB
        }
    }
}

private let storageKey = "dictionaryLang"
