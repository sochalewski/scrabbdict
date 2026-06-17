//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import Sharing
import XCTest
@testable import Scrabbdict

final class SearchModeStorageClientTests: XCTestCase {
    func testUsesDefaultAppStorage() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let client = SearchModeStorageClient.liveValue

            XCTAssertEqual(client.current(), .auto)

            client.setCurrent(.rack)
            XCTAssertEqual(client.current(), .rack)
        }
    }

    func testFallsBackToAutoWhenStoredSearchModeIsInvalid() {
        let appStorage = UserDefaults.inMemory
        appStorage.set(999, forKey: "searchMode")

        withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            let client = SearchModeStorageClient.liveValue

            XCTAssertEqual(client.current(), .auto)
        }
    }
}
