//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import Sharing
import XCTest
@testable import Scrabbdict

final class AnalyticsConsentStorageClientTests: XCTestCase {
    func testUsesDefaultAppStorage() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let client = AnalyticsConsentStorageClient.liveValue

            XCTAssertNil(client.current())

            client.setCurrent(.granted)
            XCTAssertEqual(client.current(), .granted)

            client.setCurrent(.denied)
            XCTAssertEqual(client.current(), .denied)
        }
    }

    func testTreatsInvalidStoredValueAsUndecided() {
        let appStorage = UserDefaults.inMemory
        appStorage.set("maybe", forKey: "analyticsConsent")

        withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            XCTAssertNil(AnalyticsConsentStorageClient.liveValue.current())
        }
    }
}
