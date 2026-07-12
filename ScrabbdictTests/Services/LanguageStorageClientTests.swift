//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import Sharing
import XCTest
@testable import Scrabbdict

final class LanguageStorageClientTests: XCTestCase {
    func testUsesDefaultAppStorage() {
        withDependencies {
            $0.defaultAppStorage = .inMemory
            $0.locale = Locale(identifier: "fr_FR")
        } operation: {
            let client = LanguageStorageClient.liveValue

            XCTAssertEqual(client.current(), .french)

            client.setCurrent(.polish)
            XCTAssertEqual(client.current(), .polish)
        }
    }

    func testFallsBackToCurrentLanguageWhenStoredLanguageIsInvalid() {
        let appStorage = UserDefaults.inMemory
        appStorage.set("de_DE", forKey: "dictionaryLang")

        withDependencies {
            $0.defaultAppStorage = appStorage
            $0.locale = Locale(identifier: "pl_PL")
        } operation: {
            let client = LanguageStorageClient.liveValue

            XCTAssertEqual(client.current(), .polish)
        }
    }

    func testFallsBackToPreferredLanguageForLocaleWhenNoLanguageIsStored() {
        let cases: [(localeIdentifier: String, language: Language)] = [
            ("en_US", .englishNWL),
            ("en_CA", .englishNWL),
            ("en", .englishCSW),
            ("en_GB", .englishCSW),
            ("en_AU", .englishCSW),
            ("fr_FR", .french),
            ("fr_CA", .french),
            ("pl_PL", .polish),
            ("de_DE", .englishCSW)
        ]

        for testCase in cases {
            withDependencies {
                $0.defaultAppStorage = .inMemory
                $0.locale = Locale(identifier: testCase.localeIdentifier)
            } operation: {
                let client = LanguageStorageClient.liveValue

                XCTAssertEqual(
                    client.current(),
                    testCase.language,
                    "Expected \(testCase.language) for \(testCase.localeIdentifier)."
                )
            }
        }
    }
}
