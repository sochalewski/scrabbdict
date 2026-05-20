//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import Foundation

struct SearchModeStorageClient: Sendable {
    var current: @Sendable () -> SearchMode
    var setCurrent: @Sendable (SearchMode) -> Void
}

extension SearchModeStorageClient: DependencyKey {
    static let liveValue = Self(
        current: {
            let rawValue = UserDefaults.standard.integer(forKey: storageKey)
            return SearchMode(rawValue: rawValue) ?? .auto
        },
        setCurrent: { searchMode in
            UserDefaults.standard.set(searchMode.rawValue, forKey: storageKey)
        }
    )

    static let testValue = Self(
        current: unimplemented("\(Self.self).current", placeholder: .auto),
        setCurrent: unimplemented("\(Self.self).setCurrent")
    )

    static let previewValue = Self(
        current: { .auto },
        setCurrent: { _ in }
    )
}

extension DependencyValues {
    var searchModeStorage: SearchModeStorageClient {
        get { self[SearchModeStorageClient.self] }
        set { self[SearchModeStorageClient.self] = newValue }
    }
}

private let storageKey = "searchMode"
