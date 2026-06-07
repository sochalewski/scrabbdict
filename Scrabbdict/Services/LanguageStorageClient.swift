//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import Foundation

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
            else { return .englishUS }
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

private let storageKey = "dictionaryLang"
