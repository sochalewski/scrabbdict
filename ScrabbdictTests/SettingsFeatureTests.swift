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
    func testLanguageSelected() async {
        let store = TestStore(initialState: SettingsFeature.State(selectedLanguage: .englishUS)) {
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
            $0.languageStorage.current = { .englishUS }
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
