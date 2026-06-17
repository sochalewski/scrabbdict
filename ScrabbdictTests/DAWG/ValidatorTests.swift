//
//  ScrabbdictTests
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Dependencies
import XCTest
@testable import Scrabbdict

private enum AnalyticsEvent: Equatable {
    case regexSearch(Language)
    case tilesSearch(Language)
    case wordChecked(Language, exists: Bool)
}

private final class AnalyticsEventRecorder: @unchecked Sendable {
    private let events = LockIsolated([AnalyticsEvent]())

    var recordedEvents: [AnalyticsEvent] {
        events.value
    }

    func analyticsClient() -> AnalyticsClient {
        AnalyticsClient(
            logLanguageChanged: { _ in },
            logModeChanged: { _ in },
            logRegexSearch: { [self] language in
                append(.regexSearch(language))
            },
            logTilesSearch: { [self] language in
                append(.tilesSearch(language))
            },
            logWordChecked: { [self] language, exists in
                append(.wordChecked(language, exists: exists))
            }
        )
    }

    private func append(_ event: AnalyticsEvent) {
        events.withValue {
            $0.append(event)
        }
    }
}

private final class CurrentLanguageHolder: @unchecked Sendable {
    private let language: LockIsolated<Language>

    var current: Language {
        language.value
    }

    init(_ language: Language) {
        self.language = LockIsolated(language)
    }

    func set(_ language: Language) {
        self.language.setValue(language)
    }
}

final class ValidatorTests: XCTestCase {
    private var sut: Validator!
    private var currentLanguage: CurrentLanguageHolder!

    override func setUp() {
        super.setUp()

        currentLanguage = CurrentLanguageHolder(.englishGB)
        sut = withDependencies {
            $0.analyticsClient = AnalyticsClient(
                logLanguageChanged: { _ in },
                logModeChanged: { _ in },
                logRegexSearch: { _ in },
                logTilesSearch: { _ in },
                logWordChecked: { _, _ in }
            )
            $0.languageStorage.current = { [currentLanguage] in
                currentLanguage!.current
            }
        } operation: {
            Validator()
        }
    }

    override func tearDown() {
        super.tearDown()

        sut = nil
        currentLanguage = nil
    }

    func testCheckValidWord() async throws {
        switch try await sut.check(word: "pizza") {
        case let .valid(points):
            XCTAssertEqual(points, 25)
        case .invalid:
            XCTFail()
        }
    }

    func testCheckInvalidWord() async throws {
        switch try await sut.check(word: "pizzapie") {
        case .invalid:
            XCTAssert(true)
        case .valid:
            XCTFail()
        }
    }

    func testWordsFromLetters() async throws {
        let expectedWords = ["pizza", "ziz", "zip", "zap", "za", "pia", "pa", "pi", "ai"]
        let words = try await sut.words(from: "pizza")

        XCTAssertEqual(expectedWords.count, words.count)
        words.forEach { word in
            if !expectedWords.contains(word.string) {
                XCTFail()
            }
        }
    }

    func testRegexFromPhrase() async throws {
        let expectedWords = ["pizza", "pized", "pizes"]
        let words = try await sut.regex(phrase: "piz??")

        XCTAssertEqual(expectedWords.count, words.count)
        words.forEach { word in
            if !expectedWords.contains(word.string) {
                XCTFail()
            }
        }
    }

    func testLowerAndUppercaseCharacters() async throws {
        let lowercaseValidResult = try await sut.check(word: "pizza")
        let uppercaseValidResult = try await sut.check(word: "PiZZa")
        XCTAssertEqual(lowercaseValidResult, uppercaseValidResult)

        let lowercaseInvalidResult = try await sut.check(word: "pizzapie")
        let uppercaseInvalidResult = try await sut.check(word: "pIZzapIe")
        XCTAssertEqual(lowercaseInvalidResult, uppercaseInvalidResult)

        let words1 = try await sut.words(from: "pizzapie")
        let words2 = try await sut.words(from: "pIZzapIe")
        XCTAssertFalse(words1.isEmpty)
        XCTAssertEqual(words1, words2)

        let result1 = try await sut.regex(phrase: "piz??")
        let result2 = try await sut.regex(phrase: "PiZ??")
        XCTAssertFalse(result1.isEmpty)
        XCTAssertEqual(result1, result2)
    }

    func testRemoveDiacritics() async throws {
        currentLanguage.set(.french)

        let resultWithDiacritic = try await sut.check(word: "même")
        let resultWithoutDiacritic = try await sut.check(word: "meme")
        XCTAssertEqual(resultWithDiacritic, resultWithoutDiacritic)
    }

    func testInvalidLengthInputsReturnWithoutLoggingAnalytics() async throws {
        let analytics = AnalyticsEventRecorder()
        sut = withDependencies {
            $0.analyticsClient = analytics.analyticsClient()
            $0.languageStorage.current = { .englishGB }
        } operation: {
            Validator()
        }

        let shortWordCheck = try await sut.check(word: "a")
        let longWordCheck = try await sut.check(word: String(repeating: "a", count: 16))
        let shortLettersWords = try await sut.words(from: "a")
        let longLettersWords = try await sut.words(from: String(repeating: "a", count: 16))
        let shortPatternWords = try await sut.regex(phrase: "a")
        let longPatternWords = try await sut.regex(phrase: String(repeating: "a", count: 16))

        XCTAssertEqual(shortWordCheck, .invalid)
        XCTAssertEqual(longWordCheck, .invalid)
        XCTAssertEqual(shortLettersWords, [])
        XCTAssertEqual(longLettersWords, [])
        XCTAssertEqual(shortPatternWords, [])
        XCTAssertEqual(longPatternWords, [])
        XCTAssertEqual(analytics.recordedEvents, [])
    }

    func testChangingLanguageReloadsDictionaryAndUsesNewScoring() async throws {
        _ = try await sut.check(word: "pizza")
        currentLanguage.set(.polish)

        switch try await sut.check(word: "język") {
        case let .valid(points):
            XCTAssertEqual(points, 13)
        case .invalid:
            XCTFail()
        }
    }

    func testCheckLogsAnalyticsWithResult() async throws {
        let analytics = AnalyticsEventRecorder()
        sut = withDependencies {
            $0.analyticsClient = analytics.analyticsClient()
            $0.languageStorage.current = { .englishGB }
        } operation: {
            Validator()
        }

        _ = try await sut.check(word: "pizza")
        _ = try await sut.check(word: "pizzapie")

        XCTAssertEqual(analytics.recordedEvents, [
            .wordChecked(.englishGB, exists: true),
            .wordChecked(.englishGB, exists: false)
        ])
    }

    func testWordsAndRegexLogAnalytics() async throws {
        let analytics = AnalyticsEventRecorder()
        sut = withDependencies {
            $0.analyticsClient = analytics.analyticsClient()
            $0.languageStorage.current = { .englishGB }
        } operation: {
            Validator()
        }

        _ = try await sut.words(from: "pizza")
        _ = try await sut.regex(phrase: "piz??")

        XCTAssertEqual(analytics.recordedEvents, [
            .tilesSearch(.englishGB),
            .regexSearch(.englishGB)
        ])
    }
}
