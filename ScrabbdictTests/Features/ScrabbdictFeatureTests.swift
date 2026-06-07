//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import XCTest
@testable import Scrabbdict

@MainActor
final class ScrabbdictFeatureTests: XCTestCase {
    func testSettingsLoadsCurrentLanguage() async {
        let store = TestStore(initialState: ScrabbdictFeature.State()) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.languageStorage.current = { .polish }
        }

        await store.send(.view(.settingsButtonTapped)) {
            $0.destination = .settings(SettingsFeature.State())
        }
        await store.send(.destination(.presented(.settings(.view(.loaded))))) {
            $0.destination = .settings(SettingsFeature.State(selectedLanguage: .polish))
        }
    }

    func testClearButtonClearsQueryAndOutput() async {
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                query: "pizza",
                result: .valid(points: 7),
                emptyResult: .rack,
                words: [Word(string: "pizza", points: 25)]
            )
        ) {
            ScrabbdictFeature()
        }

        await store.send(.view(.clearButtonTapped)) {
            $0.emptyResult = nil
            $0.query = ""
            $0.result = nil
            $0.words = []
        }
    }

    func testFocusBindingAndDefocusActions() async {
        let store = TestStore(initialState: ScrabbdictFeature.State()) {
            ScrabbdictFeature()
        }

        await store.send(\.binding.isSearchFocused, true) {
            $0.isSearchFocused = true
        }
        await store.send(.view(.backgroundTapped)) {
            $0.isSearchFocused = false
        }
        await store.send(\.binding.isSearchFocused, true) {
            $0.isSearchFocused = true
        }
        await store.send(.view(.settingsButtonTapped)) {
            $0.isSearchFocused = false
            $0.destination = .settings(SettingsFeature.State())
        }
    }

    func testLoadedRestoresSearchMode() async {
        let store = TestStore(initialState: ScrabbdictFeature.State()) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.searchModeStorage.current = { .check }
        }

        await store.send(.view(.loaded)) {
            $0.searchMode = .check
        }
    }

    func testSearchModePickerTogglesAndSelectsMode() async {
        let savedSearchModes = LockIsolated([SearchMode]())
        let loggedSearchModes = LockIsolated([SearchMode]())
        let store = TestStore(initialState: ScrabbdictFeature.State(isSearchFocused: true)) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.analyticsClient.logModeChanged = { searchMode in
                loggedSearchModes.withValue {
                    $0.append(searchMode)
                }
            }
            $0.searchModeStorage.setCurrent = { searchMode in
                savedSearchModes.withValue {
                    $0.append(searchMode)
                }
            }
        }

        await store.send(.view(.searchModePickerTapped)) {
            $0.isSearchFocused = false
            $0.isSearchModePickerExpanded = true
        }
        await store.send(.view(.searchModeSelected(.rack))) {
            $0.searchMode = .rack
            $0.isSearchModePickerExpanded = false
        }
        XCTAssertEqual(savedSearchModes.value, [.rack])
        XCTAssertEqual(loggedSearchModes.value, [.rack])
    }

    func testSearchModeSelectionDoesNotLogAnalyticsWhenModeDidNotChange() async {
        let savedSearchModes = LockIsolated([SearchMode]())
        let store = TestStore(initialState: ScrabbdictFeature.State(searchMode: .rack)) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.analyticsClient.logModeChanged = { _ in
                XCTFail("Analytics should not be logged when search mode did not change.")
            }
            $0.searchModeStorage.setCurrent = { searchMode in
                savedSearchModes.withValue {
                    $0.append(searchMode)
                }
            }
        }

        await store.send(.view(.searchModeSelected(.rack)))
        XCTAssertEqual(savedSearchModes.value, [.rack])
    }

    func testSearchModeSelectionClearsOutput() async {
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                result: .valid(points: 7),
                emptyResult: .rack,
                search: .result(showsRackWordsButton: true),
                showsRackWordsButton: true,
                searchMode: .auto,
                isSearchModePickerExpanded: true,
                words: [Word(string: "pizza", points: 25)]
            )
        ) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.analyticsClient.logModeChanged = { searchMode in
                XCTAssertEqual(searchMode, .rack)
            }
            $0.searchModeStorage.setCurrent = { _ in }
        }

        await store.send(.view(.searchModeSelected(.rack))) {
            $0.emptyResult = nil
            $0.result = nil
            $0.search = nil
            $0.showsRackWordsButton = false
            $0.searchMode = .rack
            $0.isSearchModePickerExpanded = false
            $0.words = []
        }
    }

    func testSearchFocusCollapsesSearchModePicker() async {
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                isSearchModePickerExpanded: true
            )
        ) {
            ScrabbdictFeature()
        }

        await store.send(\.binding.isSearchFocused, true) {
            $0.isSearchFocused = true
            $0.isSearchModePickerExpanded = false
        }
    }

    func testQueryBindingWithSameTextDoesNotClearOutput() async {
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                query: "pizza",
                result: .valid(points: 7),
                emptyResult: .rack,
                words: [Word(string: "pizza", points: 25)]
            )
        ) {
            ScrabbdictFeature()
        }

        await store.send(\.binding.query, "pizza")
    }

    func testQueryBindingClearsOutput() async {
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                query: "pizza",
                result: .valid(points: 7),
                emptyResult: .rack,
                search: .result(showsRackWordsButton: true),
                showsRackWordsButton: true,
                words: [Word(string: "pizza", points: 25)]
            )
        ) {
            ScrabbdictFeature()
        }

        await store.send(\.binding.query, "pizz") {
            $0.emptyResult = nil
            $0.query = "pizz"
            $0.result = nil
            $0.search = nil
            $0.showsRackWordsButton = false
            $0.words = []
        }
    }

    func testQueryBindingCancelsInFlightSearch() async {
        let search = CancellableSearch<[Word]>(cancelledValue: [])
        let store = TestStore(initialState: ScrabbdictFeature.State(query: "piz??")) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.validatorClient.regex = { phrase async throws(ValidatorError) in
                XCTAssertEqual(phrase, "piz??")
                return await search.result()
            }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.search = .words
        }
        await search.waitUntilStarted()

        await store.send(\.binding.query, "piz?") {
            $0.query = "piz?"
            $0.search = nil
        }
        await search.waitUntilCancelled()
    }

    func testSearchWithoutBlankChecksWordOnly() async {
        let store = TestStore(initialState: ScrabbdictFeature.State(isSearchFocused: true, query: "pizza")) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.appReviewClient.requestReviewIfAppropriate = {}
            $0.continuousClock = ImmediateClock()
            $0.validatorClient.check = { word async throws(ValidatorError) in
                XCTAssertEqual(word, "pizza")
                return .valid(points: 25)
            }
            $0.validatorClient.words = { _ async throws(ValidatorError) in
                XCTFail("Rack words should not be loaded by the search button.")
                return []
            }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.isSearchFocused = false
            $0.search = .result(showsRackWordsButton: true)
            $0.showsRackWordsButton = true
        }
        await store.receive(.internal(.searchResponse(.checked(.valid(points: 25))))) {
            $0.search = nil
            $0.result = .valid(points: 25)
        }
    }

    func testWordCheckRequestsReviewIfAppropriateAfterTwoSeconds() async {
        let clock = TestClock()
        let requestReviewCallsCount = LockIsolated(0)
        let store = TestStore(initialState: ScrabbdictFeature.State(query: "pizza")) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.appReviewClient.requestReviewIfAppropriate = {
                requestReviewCallsCount.withValue { $0 += 1 }
            }
            $0.continuousClock = clock
            $0.validatorClient.check = { _ async throws(ValidatorError) in
                .valid(points: 25)
            }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.search = .result(showsRackWordsButton: true)
            $0.showsRackWordsButton = true
        }
        await store.receive(.internal(.searchResponse(.checked(.valid(points: 25))))) {
            $0.search = nil
            $0.result = .valid(points: 25)
        }

        XCTAssertEqual(requestReviewCallsCount.value, 0)
        await clock.advance(by: .seconds(2))
        XCTAssertEqual(requestReviewCallsCount.value, 1)
    }

    func testRackWordsButtonHidesResultAndMatchesRackWords() async {
        let words = [Word(string: "pizza", points: 25)]
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                query: "pizza",
                result: .valid(points: 25)
            )
        ) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.validatorClient.words = { letters async throws(ValidatorError) in
                XCTAssertEqual(letters, "pizza")
                return words
            }
        }

        await store.send(.view(.rackWordsButtonTapped)) {
            $0.result = nil
            $0.search = .words
        }
        await store.receive(.internal(.searchResponse(.matchedWords(words, emptyResult: .rack)))) {
            $0.search = nil
            $0.words = words
        }
    }

    func testSearchWithBlankMatchesRegexWords() async {
        let words = [Word(string: "pizza", points: 25)]
        let store = TestStore(initialState: ScrabbdictFeature.State(query: "piz??")) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.validatorClient.regex = { phrase async throws(ValidatorError) in
                XCTAssertEqual(phrase, "piz??")
                return words
            }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.search = .words
        }
        await store.receive(.internal(.searchResponse(.matchedWords(words, emptyResult: .pattern)))) {
            $0.search = nil
            $0.words = words
        }
    }

    func testCheckModeChecksQueryWithBlankInsteadOfPatternSearch() async {
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                query: "piz??",
                searchMode: .check
            )
        ) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.appReviewClient.requestReviewIfAppropriate = {}
            $0.continuousClock = ImmediateClock()
            $0.validatorClient.check = { word async throws(ValidatorError) in
                XCTAssertEqual(word, "piz??")
                return .invalid
            }
            $0.validatorClient.regex = { _ async throws(ValidatorError) in
                XCTFail("Check mode should not run pattern search.")
                return []
            }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.search = .result(showsRackWordsButton: false)
        }
        await store.receive(.internal(.searchResponse(.checked(.invalid)))) {
            $0.search = nil
            $0.result = .invalid
        }
    }

    func testRackModeSearchButtonMatchesRackWords() async {
        let words = [Word(string: "pizza", points: 25)]
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                query: "pizza",
                searchMode: .rack
            )
        ) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.validatorClient.words = { letters async throws(ValidatorError) in
                XCTAssertEqual(letters, "pizza")
                return words
            }
            $0.validatorClient.check = { _ async throws(ValidatorError) in
                XCTFail("Rack mode should not check a single word.")
                return .invalid
            }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.search = .words
        }
        await store.receive(.internal(.searchResponse(.matchedWords(words, emptyResult: .rack)))) {
            $0.search = nil
            $0.words = words
        }
    }

    func testRackModeWithBlankMatchesPatternWords() async {
        let words = [Word(string: "pizza", points: 25)]
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                query: "piz??",
                searchMode: .rack
            )
        ) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.validatorClient.regex = { pattern async throws(ValidatorError) in
                XCTAssertEqual(pattern, "piz??")
                return words
            }
            $0.validatorClient.words = { _ async throws(ValidatorError) in
                XCTFail("Rack mode should use pattern search when the query contains ?.")
                return []
            }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.search = .words
        }
        await store.receive(.internal(.searchResponse(.matchedWords(words, emptyResult: .pattern)))) {
            $0.search = nil
            $0.words = words
        }
    }

    func testRackWordsButtonShowsEmptyRackResultWhenNoWordsCanBeMade() async {
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                query: "pizza",
                result: .valid(points: 25)
            )
        ) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.validatorClient.words = { _ async throws(ValidatorError) in [] }
        }

        await store.send(.view(.rackWordsButtonTapped)) {
            $0.result = nil
            $0.search = .words
        }
        await store.receive(.internal(.searchResponse(.matchedWords([], emptyResult: .rack)))) {
            $0.emptyResult = .rack
            $0.search = nil
        }
    }

    func testSearchWithBlankShowsEmptyPatternResultWhenNoWordsMatch() async {
        let store = TestStore(initialState: ScrabbdictFeature.State(query: "piz??")) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.validatorClient.regex = { _ async throws(ValidatorError) in [] }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.search = .words
        }
        await store.receive(.internal(.searchResponse(.matchedWords([], emptyResult: .pattern)))) {
            $0.emptyResult = .pattern
            $0.search = nil
        }
    }

    func testSearchFailureShowsAlert() async {
        let recordedErrors = LockIsolated([ValidatorError]())
        let store = TestStore(initialState: ScrabbdictFeature.State(query: "pizza")) {
            ScrabbdictFeature()
        } withDependencies: {
            $0.crashlyticsClient.record = { error in
                guard let error = error as? ValidatorError else {
                    XCTFail("Expected ValidatorError to be recorded.")
                    return
                }
                recordedErrors.withValue {
                    $0.append(error)
                }
            }
            $0.validatorClient.check = { _ async throws(ValidatorError) in
                throw ValidatorError.dictionaryUnavailable
            }
        }

        await store.send(.view(.searchButtonTapped)) {
            $0.search = .result(showsRackWordsButton: true)
            $0.showsRackWordsButton = true
        }
        await store.receive(.internal(.searchResponse(.failed(.dictionaryUnavailable)))) {
            $0.search = nil
            $0.alert = ScrabbdictAlert(kind: .dictionaryUnavailable)
        }
        XCTAssertEqual(recordedErrors.value, [.dictionaryUnavailable])
    }

    func testLanguageUpdatedClearsOutput() async {
        let store = TestStore(
            initialState: ScrabbdictFeature.State(
                result: .valid(points: 7),
                emptyResult: .rack,
                words: [Word(string: "pizza", points: 25)]
            )
        ) {
            ScrabbdictFeature()
        }

        await store.send(.view(.settingsButtonTapped)) {
            $0.destination = .settings(SettingsFeature.State())
        }
        await store.send(.destination(.presented(.settings(.delegate(.languageUpdated))))) {
            $0.emptyResult = nil
            $0.result = nil
            $0.words = []
        }
    }
}

private final class CancellableSearch<Value>: @unchecked Sendable {
    private let isStarted = LockIsolated(false)
    private let isCancelled = LockIsolated(false)
    private let continuation = LockIsolated<CheckedContinuation<Value, Never>?>(nil)
    private let cancelledValue: Value

    init(cancelledValue: Value) {
        self.cancelledValue = cancelledValue
    }

    func result() async -> Value {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.isStarted.setValue(true)
                self.continuation.setValue(continuation)
            }
        } onCancel: {
            isCancelled.setValue(true)
            continuation.withValue {
                $0?.resume(returning: cancelledValue)
                $0 = nil
            }
        }
    }

    func waitUntilStarted() async {
        while !isStarted.value {
            await Task.yield()
        }
    }

    func waitUntilCancelled() async {
        while !isCancelled.value {
            await Task.yield()
        }
    }
}
