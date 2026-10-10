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

    func testLanguageSelectedPersistsLanguageAndSendsDelegate() async {
        let storedLanguages = LockIsolated<[Language]>([])
        let loggedLanguages = LockIsolated<[Language]>([])
        let store = TestStore(initialState: SettingsFeature.State(selectedLanguage: .englishNWL)) {
            SettingsFeature()
        } withDependencies: {
            $0.analyticsClient.logLanguageChanged = { language in
                loggedLanguages.withValue { $0.append(language) }
            }
            $0.languageStorage.setCurrent = { language in
                storedLanguages.withValue { $0.append(language) }
            }
        }

        await store.send(.view(.languageSelected(.polish))) {
            $0.selectedLanguage = .polish
        }
        await store.receive(.delegate(.languageUpdated))
        XCTAssertEqual(storedLanguages.value, [.polish])
        XCTAssertEqual(loggedLanguages.value, [.polish])
    }

    func testSelectingCurrentLanguageDoesNothing() async {
        let store = TestStore(initialState: SettingsFeature.State(selectedLanguage: .french)) {
            SettingsFeature()
        }

        await store.send(.view(.languageSelected(.french)))
    }

    func testCloseDismisses() async {
        let dismissCallsCount = LockIsolated(0)
        let store = TestStore(initialState: SettingsFeature.State(selectedLanguage: .french)) {
            SettingsFeature()
        } withDependencies: {
            $0.dismiss = .init {
                dismissCallsCount.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.closeButtonTapped))
        XCTAssertEqual(dismissCallsCount.value, 1)
    }

    func testLoadedReadsLanguageAndAnalyticsConsent() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.analyticsConsentStorage.current = { .granted }
            $0.languageStorage.current = { .polish }
        }

        await store.send(.view(.loaded)) {
            $0.selectedLanguage = .polish
            $0.isAnalyticsEnabled = true
        }
    }

    func testLoadedTreatsMissingAnalyticsConsentAsDisabled() async {
        let store = TestStore(initialState: SettingsFeature.State(isAnalyticsEnabled: true)) {
            SettingsFeature()
        } withDependencies: {
            $0.analyticsConsentStorage.current = { nil }
            $0.languageStorage.current = { .englishNWL }
        }

        await store.send(.view(.loaded)) {
            $0.isAnalyticsEnabled = false
        }
    }

    func testAnalyticsToggledAppliesConsentImmediately() async {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.analyticsConsentStorage.setCurrent = { consent in
                events.withValue { $0.append("store.\(consent)") }
            }
            $0.analyticsClient.applyConsent = { consent in
                events.withValue { $0.append("apply.\(consent)") }
            }
        }

        await store.send(.view(.analyticsToggled(true))) {
            $0.isAnalyticsEnabled = true
        }
        await store.send(.view(.analyticsToggled(false))) {
            $0.isAnalyticsEnabled = false
        }
        XCTAssertEqual(events.value, ["store.granted", "apply.granted", "store.denied", "apply.denied"])
    }

    func testPrivacyPolicyTappedLogsEvent() async {
        let loggedEventsCount = LockIsolated(0)
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.analyticsClient.logPrivacyPolicyOpened = {
                loggedEventsCount.withValue { $0 += 1 }
            }
        }

        await store.send(.view(.privacyPolicyTapped))
        XCTAssertEqual(loggedEventsCount.value, 1)
    }
}
