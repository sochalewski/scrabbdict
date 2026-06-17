//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import Sharing
import XCTest
@testable import Scrabbdict

@MainActor
final class AppReviewClientTests: XCTestCase {
    func testRequestReviewIfAppropriateStoresDateWithoutRequestingWhenNoPreviousRequestExists() {
        let appStorage = UserDefaults.inMemory
        let now = Date(timeIntervalSince1970: 0)
        let requestReviewCallsCount = LockIsolated(0)

        withDependencies {
            $0.appReviewClient = .liveValue
            $0.appReviewClient.requestReview = {
                requestReviewCallsCount.withValue { $0 += 1 }
            }
            $0.defaultAppStorage = appStorage
            $0.date.now = now
        } operation: {
            @Dependency(\.appReviewClient.requestReviewIfAppropriate) var requestReviewIfAppropriate
            requestReviewIfAppropriate()
        }

        XCTAssertEqual(requestReviewCallsCount.value, 0)
        XCTAssertEqual(appStorage.object(forKey: "lastReviewRequestDate") as? Date, now)
    }

    func testRequestReviewIfAppropriateSkipsRequestBeforeSixtyDaysPass() {
        let appStorage = UserDefaults.inMemory
        let lastRequestDate = Date(timeIntervalSince1970: 0)
        let now = lastRequestDate.addingTimeInterval(5_184_000 - 1)
        appStorage.set(lastRequestDate, forKey: "lastReviewRequestDate")
        let requestReviewCallsCount = LockIsolated(0)

        withDependencies {
            $0.appReviewClient = .liveValue
            $0.appReviewClient.requestReview = {
                requestReviewCallsCount.withValue { $0 += 1 }
            }
            $0.defaultAppStorage = appStorage
            $0.date.now = now
        } operation: {
            @Dependency(\.appReviewClient.requestReviewIfAppropriate) var requestReviewIfAppropriate
            requestReviewIfAppropriate()
        }

        XCTAssertEqual(requestReviewCallsCount.value, 0)
        XCTAssertEqual(appStorage.object(forKey: "lastReviewRequestDate") as? Date, lastRequestDate)
    }

    func testRequestReviewIfAppropriateRequestsWhenSixtyDaysPass() {
        let appStorage = UserDefaults.inMemory
        let lastRequestDate = Date(timeIntervalSince1970: 0)
        let now = lastRequestDate.addingTimeInterval(5_184_000)
        appStorage.set(lastRequestDate, forKey: "lastReviewRequestDate")
        let requestReviewCallsCount = LockIsolated(0)

        withDependencies {
            $0.appReviewClient = .liveValue
            $0.appReviewClient.requestReview = {
                requestReviewCallsCount.withValue { $0 += 1 }
            }
            $0.defaultAppStorage = appStorage
            $0.date.now = now
        } operation: {
            @Dependency(\.appReviewClient.requestReviewIfAppropriate) var requestReviewIfAppropriate
            requestReviewIfAppropriate()
        }

        XCTAssertEqual(requestReviewCallsCount.value, 1)
        XCTAssertEqual(appStorage.object(forKey: "lastReviewRequestDate") as? Date, now)
    }
}
