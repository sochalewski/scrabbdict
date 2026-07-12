//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class DAWGPerformanceTests: XCTestCase {
    private let wordCountsByLanguage: [Language: Int] = [
        .englishNWL: 196_601,
        .englishCSW: 280_887,
        .englishWOW: 195_383,
        .french: 407_128,
        .polish: 2_901_474
    ]
    private let queriesByLanguage: [Language: String] = [
        .englishNWL: "pizzapie",
        .englishCSW: "pizzapie",
        .englishWOW: "pizzapie",
        .french: "mangeurs",
        .polish: "kotkami"
    ]
    private let patternsByLanguage: [Language: String] = [
        .englishNWL: "piz??",
        .englishCSW: "piz??",
        .englishWOW: "piz??",
        .french: "mang???",
        .polish: "kot???"
    ]
    private let lookupCountPerMeasurement = 1_000

    func testLoadEnglishCSW() throws {
        try measureLoad(language: .englishCSW)
    }

    func testLoadEnglishNWL() throws {
        try measureLoad(language: .englishNWL)
    }

    func testLoadEnglishWOW() throws {
        try measureLoad(language: .englishWOW)
    }

    func testLoadFrench() throws {
        try measureLoad(language: .french)
    }

    func testLoadPolish() throws {
        try measureLoad(language: .polish)
    }

    func testContainsEnglishCSW() throws {
        try measureContains(language: .englishCSW)
    }

    func testContainsEnglishNWL() throws {
        try measureContains(language: .englishNWL)
    }

    func testContainsEnglishWOW() throws {
        try measureContains(language: .englishWOW)
    }

    func testContainsFrench() throws {
        try measureContains(language: .french)
    }

    func testContainsPolish() throws {
        try measureContains(language: .polish)
    }

    func testWordsFromEnglishCSW() throws {
        try measureWordsFrom(language: .englishCSW)
    }

    func testWordsFromEnglishNWL() throws {
        try measureWordsFrom(language: .englishNWL)
    }

    func testWordsFromEnglishWOW() throws {
        try measureWordsFrom(language: .englishWOW)
    }

    func testWordsFromFrench() throws {
        try measureWordsFrom(language: .french)
    }

    func testWordsFromPolish() throws {
        try measureWordsFrom(language: .polish)
    }

    func testPatternEnglishCSW() throws {
        try measurePattern(language: .englishCSW)
    }

    func testPatternEnglishNWL() throws {
        try measurePattern(language: .englishNWL)
    }

    func testPatternEnglishWOW() throws {
        try measurePattern(language: .englishWOW)
    }

    func testPatternFrench() throws {
        try measurePattern(language: .french)
    }

    func testPatternPolish() throws {
        try measurePattern(language: .polish)
    }

    private func measureLoad(language: Language) throws {
        var wordCount = 0

        measure(metrics: [XCTClockMetric()], options: repeatedOptions()) {
            wordCount = DAWG(language: language)!.count
        }

        XCTAssertEqual(wordCount, wordCountsByLanguage[language])
    }

    private func measureContains(language: Language) throws {
        let dawg = try XCTUnwrap(DAWG(language: language))
        let query = queriesByLanguage[language]!
        var resultCount = 0

        measure(metrics: [XCTClockMetric()], options: repeatedOptions()) {
            for _ in 0..<lookupCountPerMeasurement {
                resultCount += dawg.contains(query) ? 1 : 0
            }
        }
    }

    private func measureWordsFrom(language: Language) throws {
        let dawg = try XCTUnwrap(DAWG(language: language))
        let query = queriesByLanguage[language]!
        var resultCount = 0

        measure(metrics: [XCTClockMetric()], options: repeatedOptions()) {
            for _ in 0..<lookupCountPerMeasurement {
                resultCount += dawg.words(from: query).count
            }
        }
    }

    private func measurePattern(language: Language) throws {
        let dawg = try XCTUnwrap(DAWG(language: language))
        let pattern = patternsByLanguage[language]!
        var resultCount = 0

        measure(metrics: [XCTClockMetric()], options: repeatedOptions()) {
            for _ in 0..<lookupCountPerMeasurement {
                resultCount += dawg.words(matching: pattern).count
            }
        }
    }

    private func repeatedOptions() -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        return options
    }
}
