//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import FirebaseCrashlytics
import Foundation

struct CrashlyticsClient: Sendable {
    var log: @Sendable (String) -> Void
    var record: @Sendable (any Error) -> Void
}

extension CrashlyticsClient: DependencyKey {
    static let liveValue = Self(
        log: { message in
            Crashlytics.crashlytics().log(message)
        },
        record: { error in
            Crashlytics.crashlytics().record(error: error)
        }
    )

    static let testValue = Self(
        log: unimplemented("\(Self.self).log"),
        record: unimplemented("\(Self.self).record")
    )

    static let previewValue = Self(
        log: { _ in },
        record: { _ in }
    )
}

extension DependencyValues {
    var crashlyticsClient: CrashlyticsClient {
        get { self[CrashlyticsClient.self] }
        set { self[CrashlyticsClient.self] = newValue }
    }
}
