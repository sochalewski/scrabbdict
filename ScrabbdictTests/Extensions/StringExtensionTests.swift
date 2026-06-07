//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class StringExtensionTests: XCTestCase {
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
