//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class DAWGPerformanceTests: XCTestCase {
    private let wordCountsByLanguage: [Language: Int] = [
        .englishUS: 196_601,
        .englishGB: 280_887,
        .french: 407_128,
        .polish: 2_901_474
    ]
    private let queriesByLanguage: [Language: String] = [
        .englishUS: "pizzapie",
        .englishGB: "pizzapie",
        .french: "mangeurs",
        .polish: "kotkami"
    ]
    private let patternsByLanguage: [Language: String] = [
        .englishUS: "piz??",
        .englishGB: "piz??",
        .french: "mang???",
        .polish: "kot???"
    ]
    private let lookupCountPerMeasurement = 1_000

    func testLoadEnglishGB() throws {
        try measureLoad(language: .englishGB)
    }

    func testLoadEnglishUS() throws {
        try measureLoad(language: .englishUS)
    }

    func testLoadFrench() throws {
        try measureLoad(language: .french)
    }

    func testLoadPolish() throws {
        try measureLoad(language: .polish)
    }

    func testContainsEnglishGB() throws {
        try measureContains(language: .englishGB)
    }

    func testContainsEnglishUS() throws {
        try measureContains(language: .englishUS)
    }

    func testContainsFrench() throws {
        try measureContains(language: .french)
    }

    func testContainsPolish() throws {
        try measureContains(language: .polish)
    }

    func testWordsFromEnglishGB() throws {
        try measureWordsFrom(language: .englishGB)
    }

    func testWordsFromEnglishUS() throws {
        try measureWordsFrom(language: .englishUS)
    }

    func testWordsFromFrench() throws {
        try measureWordsFrom(language: .french)
    }

    func testWordsFromPolish() throws {
        try measureWordsFrom(language: .polish)
    }

    func testPatternEnglishGB() throws {
        try measurePattern(language: .englishGB)
    }

    func testPatternEnglishUS() throws {
        try measurePattern(language: .englishUS)
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
