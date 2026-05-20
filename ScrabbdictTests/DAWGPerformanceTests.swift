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
        .polish: 3_238_764
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
    private let iterationCount = 1_000

    func testLoadDAWGEnglishGBPerformance() throws {
        try measureLoad(language: .englishGB)
    }

    func testLoadDAWGEnglishUSPerformance() throws {
        try measureLoad(language: .englishUS)
    }

    func testLoadDAWGFrenchPerformance() throws {
        try measureLoad(language: .french)
    }

    func testLoadDAWGPolishPerformance() throws {
        try measureLoad(language: .polish)
    }

    func testWordsFromDAWGEnglishGBPerformance() throws {
        try measureWordsFrom(language: .englishGB)
    }

    func testWordsFromDAWGEnglishUSPerformance() throws {
        try measureWordsFrom(language: .englishUS)
    }

    func testWordsFromDAWGFrenchPerformance() throws {
        try measureWordsFrom(language: .french)
    }

    func testWordsFromDAWGPolishPerformance() throws {
        try measureWordsFrom(language: .polish)
    }

    func testPatternDAWGEnglishGBPerformance() throws {
        try measurePattern(language: .englishGB)
    }

    func testPatternDAWGEnglishUSPerformance() throws {
        try measurePattern(language: .englishUS)
    }

    func testPatternDAWGFrenchPerformance() throws {
        try measurePattern(language: .french)
    }

    func testPatternDAWGPolishPerformance() throws {
        try measurePattern(language: .polish)
    }

    private func measureLoad(language: Language) throws {
        var wordCount = 0

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: singleIterationOptions()) {
            wordCount = DAWG(language: language)!.count
        }

        XCTAssertEqual(wordCount, wordCountsByLanguage[language])
    }

    private func measureWordsFrom(language: Language) throws {
        let dawg = try XCTUnwrap(DAWG(language: language))
        let query = queriesByLanguage[language]!
        var resultCount = 0

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: repeatedOptions()) {
            for _ in 0..<iterationCount {
                resultCount += dawg.words(from: query).count
            }
        }

        XCTAssertGreaterThan(resultCount, 0)
    }

    private func measurePattern(language: Language) throws {
        let dawg = try XCTUnwrap(DAWG(language: language))
        let pattern = patternsByLanguage[language]!
        var resultCount = 0

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: repeatedOptions()) {
            for _ in 0..<iterationCount {
                resultCount += dawg.words(matching: pattern).count
            }
        }

        XCTAssertGreaterThan(resultCount, 0)
    }

    private func singleIterationOptions() -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        return options
    }

    private func repeatedOptions() -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        return options
    }
}
