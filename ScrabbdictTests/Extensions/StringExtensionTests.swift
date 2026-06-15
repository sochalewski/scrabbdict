//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class StringExtensionTests: XCTestCase {
    func testIsLengthValidAcceptsTwoToFifteenCharacters() {
        XCTAssertFalse("".isLengthValid)
        XCTAssertFalse("a".isLengthValid)
        XCTAssertTrue("ab".isLengthValid)
        XCTAssertTrue(String(repeating: "a", count: 15).isLengthValid)
        XCTAssertFalse(String(repeating: "a", count: 16).isLengthValid)
    }

    func testSanitizedWordQueryKeepsLettersAndQuestionMarks() {
        XCTAssertEqual("p1i-z😀?Za!".sanitizedWordQuery, "piz?Za")
        XCTAssertEqual("żółć?é1".sanitizedWordQuery, "żółć?é")
    }

    func testSanitizedWordQueryTruncatesToMaximumLength() {
        XCTAssertEqual("abcdefghijklmnop?".sanitizedWordQuery, "abcdefghijklmno")
    }

    func testWordQueryAccessibilityValueForWordIncludesOriginalTextAndSpelledLetters() {
        XCTAssertEqual("pizza".wordQueryAccessibilityValue, "pizza (P, I, Z, Z, A)")
    }

    func testWordQueryAccessibilityValueForUppercaseWordIncludesOriginalTextAndSpelledLetters() {
        XCTAssertEqual("PIZZA".wordQueryAccessibilityValue, "PIZZA (P, I, Z, Z, A)")
    }

    func testWordQueryAccessibilityValueForPatternSpellsQuestionMark() {
        let questionMark = String(localized: .searchModeQuestionMark)

        XCTAssertEqual("pi??a".wordQueryAccessibilityValue, "P, I, \(questionMark), \(questionMark), A")
    }

    func testWordQueryAccessibilityValueForEmptyStringReturnsEmptyString() {
        XCTAssertEqual("".wordQueryAccessibilityValue, "")
    }
}
