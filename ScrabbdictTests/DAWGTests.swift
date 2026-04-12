//
//  DAWGTests.swift
//  ScrabbdictTests
//
//  Created by Piotr Sochalewski on 11.04.2026.
//  Copyright © 2026 Piotr Sochalewski. All rights reserved.
//

import XCTest
@testable import Scrabbdict

final class DAWGTests: XCTestCase {

    func testContainsExistingWord() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishGB))

        XCTAssertTrue(dawg.contains("pizza"))
    }

    func testDoesNotContainMissingWord() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishGB))

        XCTAssertFalse(dawg.contains("pizzapie"))
    }

    func testWordsFromLettersWithRepeatedLetters() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishGB))

        let words = dawg.words(from: "pizza")

        XCTAssertTrue(words.contains("pizza"))
        XCTAssertTrue(words.contains("ziz"))
        XCTAssertTrue(words.contains("zip"))
        XCTAssertTrue(words.contains("zap"))
    }

    func testWordsFromLettersHonorsMinimumLength() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishGB))

        let words = dawg.words(from: "pizza", minLength: 4)

        XCTAssertTrue(words.allSatisfy { $0.count >= 4 })
        XCTAssertTrue(words.contains("pizza"))
    }

    func testWordsMatchingPattern() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishGB))

        let words = dawg.words(matching: "piz??").sorted()

        XCTAssertEqual(words, ["pized", "pizes", "pizza"])
    }
}
