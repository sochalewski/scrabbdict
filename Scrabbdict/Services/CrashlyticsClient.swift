//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import FirebaseCrashlytics
import Foundation

struct CrashlyticsClient: Sendable {
    var record: @Sendable (any Error) -> Void
}

extension CrashlyticsClient: DependencyKey {
    static let liveValue = Self(
        record: { error in
            Crashlytics.crashlytics().record(error: error)
        }
    )

    static let testValue = Self(
        record: unimplemented("\(Self.self).record")
    )

    static let previewValue = Self(
        record: { _ in }
    )
}

extension DependencyValues {
    var crashlyticsClient: CrashlyticsClient {
        get { self[CrashlyticsClient.self] }
        set { self[CrashlyticsClient.self] = newValue }
    }
}
