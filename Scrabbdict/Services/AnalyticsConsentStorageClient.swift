//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import Foundation
import Sharing

struct AnalyticsConsentStorageClient: Sendable {
    var current: @Sendable () -> AnalyticsConsent?
    var setCurrent: @Sendable (AnalyticsConsent) -> Void
}

extension AnalyticsConsentStorageClient: DependencyKey {
    static let liveValue = Self(
        current: {
            @Dependency(\.defaultAppStorage) var appStorage

            return appStorage.string(forKey: storageKey).flatMap(AnalyticsConsent.init(rawValue:))
        },
        setCurrent: { consent in
            @Dependency(\.defaultAppStorage) var appStorage

            appStorage.set(consent.rawValue, forKey: storageKey)
        }
    )

    static let testValue = Self(
        current: unimplemented("\(Self.self).current", placeholder: nil),
        setCurrent: unimplemented("\(Self.self).setCurrent")
    )

    static let previewValue = Self(
        current: { .granted },
        setCurrent: { _ in }
    )
}

extension DependencyValues {
    var analyticsConsentStorage: AnalyticsConsentStorageClient {
        get { self[AnalyticsConsentStorageClient.self] }
        set { self[AnalyticsConsentStorageClient.self] = newValue }
    }
}

private let storageKey = "analyticsConsent"
