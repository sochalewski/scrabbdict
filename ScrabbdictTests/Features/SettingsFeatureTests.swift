//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import XCTest
@testable import Scrabbdict

@MainActor
final class SettingsFeatureTests: XCTestCase {
    func testLanguageRawValueInitializerSupportsCurrentValues() {
        XCTAssertEqual(Language(rawValue: "en_GB_CSW"), .englishCSW)
        XCTAssertEqual(Language(rawValue: "en_US_NWL"), .englishNWL)
        XCTAssertEqual(Language(rawValue: "en_WOW"), .englishWOW)
        XCTAssertEqual(Language(rawValue: "fr_ODS"), .french)
        XCTAssertEqual(Language(rawValue: "pl_OSPS"), .polish)
    }

    func testLanguageRawValueInitializerSupportsLegacyAndLocaleValues() {
        XCTAssertEqual(Language(rawValue: "en_GB_sowpods"), .englishCSW)
        XCTAssertEqual(Language(rawValue: "en_US_twl"), .englishNWL)
        XCTAssertEqual(Language(rawValue: "en_wow"), .englishWOW)
        XCTAssertEqual(Language(rawValue: "en_GB"), .englishCSW)
        XCTAssertEqual(Language(rawValue: "en-US"), .englishNWL)
        XCTAssertEqual(Language(rawValue: "fr"), .french)
        XCTAssertEqual(Language(rawValue: "pl_PL"), .polish)
        XCTAssertEqual(Language(rawValue: "pl"), .polish)
    }

    func testLanguageRawValueInitializerRejectsAmbiguousValues() {
        XCTAssertNil(Language(rawValue: "en"))
        XCTAssertNil(Language(rawValue: "en_CA"))
        XCTAssertNil(Language(rawValue: "de_DE"))
        XCTAssertNil(Language(rawValue: ""))
    }

    func testLanguageSelected() async {
        let store = TestStore(initialState: SettingsFeature.State(selectedLanguage: .englishNWL)) {
            SettingsFeature()
        }

        await store.send(.view(.languageSelected(.polish))) {
            $0.selectedLanguage = .polish
        }
    }

    func testCancelDismisses() async {
        let dismissCallsCount = LockIsolated(0)
        let store = TestStore(initialState: SettingsFeature.State(selectedLanguage: .french)) {
            SettingsFeature()
        } withDependencies: {
            $0.dismiss = .init {
                dismissCallsCount.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.cancelButtonTapped))
        XCTAssertEqual(dismissCallsCount.value, 1)
    }

    func testSavePersistsLanguageAndSendsDelegateWhenChanged() async {
        let dismissCallsCount = LockIsolated(0)
        let store = TestStore(initialState: SettingsFeature.State(selectedLanguage: .french)) {
            SettingsFeature()
        } withDependencies: {
            $0.analyticsClient.logLanguageChanged = { language in
                XCTAssertEqual(language, .french)
            }
            $0.languageStorage.current = { .englishNWL }
            $0.languageStorage.setCurrent = { language in
                XCTAssertEqual(language, .french)
            }
            $0.dismiss = .init {
                dismissCallsCount.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(.delegate(.languageUpdated))
        XCTAssertEqual(dismissCallsCount.value, 1)
    }

    func testSaveDismissesWithoutAnalyticsOrDelegateWhenLanguageDidNotChange() async {
        let dismissCallsCount = LockIsolated(0)
        let store = TestStore(initialState: SettingsFeature.State(selectedLanguage: .french)) {
            SettingsFeature()
        } withDependencies: {
            $0.analyticsClient.logLanguageChanged = { _ in
                XCTFail("Analytics should not be logged when language did not change.")
            }
            $0.languageStorage.current = { .french }
            $0.languageStorage.setCurrent = { language in
                XCTAssertEqual(language, .french)
            }
            $0.dismiss = .init {
                dismissCallsCount.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.saveButtonTapped))
        XCTAssertEqual(dismissCallsCount.value, 1)
    }
}
