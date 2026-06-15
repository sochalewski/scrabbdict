//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import XCTest
@testable import Scrabbdict

final class LanguageStorageClientTests: XCTestCase {
    func testUsesDefaultAppStorage() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
        } operation: {
            let client = LanguageStorageClient.liveValue

            XCTAssertEqual(client.current(), .englishUS)

            client.setCurrent(.polish)
            XCTAssertEqual(client.current(), .polish)
        }
    }

    func testFallsBackToEnglishUSWhenStoredLanguageIsInvalid() {
        let appStorage = UserDefaults.inMemory
        appStorage.set("de_DE", forKey: "dictionaryLang")

        withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            let client = LanguageStorageClient.liveValue

            XCTAssertEqual(client.current(), .englishUS)
        }
    }
}
