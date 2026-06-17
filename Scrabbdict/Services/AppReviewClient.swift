//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import Foundation
import Sharing

struct AppReviewClient: Sendable {
    /// Requests an App Store review only after the review cooldown has passed.
    ///
    /// The first call stores the current date and does not ask for a review, so new users are not prompted immediately.
    var requestReviewIfAppropriate: @MainActor @Sendable () -> Void

    /// Performs the actual SwiftUI review request.
    ///
    /// Override this with `@Environment(\.requestReview)` when constructing the app's store.
    var requestReview: @MainActor @Sendable () -> Void
}

extension AppReviewClient: DependencyKey {
    static let liveValue = Self(
        requestReviewIfAppropriate: {
            @Dependency(\.appReviewClient.requestReview) var requestReview
            @Dependency(\.defaultAppStorage) var appStorage
            @Dependency(\.date.now) var now

            guard let lastRequestDate = appStorage.object(forKey: storageKey) as? Date else {
                appStorage.set(now, forKey: storageKey)
                return
            }

            guard now.timeIntervalSince(lastRequestDate) >= appReviewMinimumRequestInterval else {
                return
            }

            appStorage.set(now, forKey: storageKey)
            requestReview()
        },
        requestReview: {}
    )

    static let testValue = Self(
        requestReviewIfAppropriate: unimplemented("\(Self.self).requestReviewIfAppropriate"),
        requestReview: unimplemented("\(Self.self).requestReview")
    )

    static let previewValue = Self(
        requestReviewIfAppropriate: {},
        requestReview: {}
    )
}

extension DependencyValues {
    var appReviewClient: AppReviewClient {
        get { self[AppReviewClient.self] }
        set { self[AppReviewClient.self] = newValue }
    }
}

private let storageKey = "lastReviewRequestDate"
private let appReviewMinimumRequestInterval: TimeInterval = 60 * 24 * 60 * 60
