//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class LanguageExtensionTests: XCTestCase {
    func testPointsUseEnglishScoringForEnglishDictionaries() {
        XCTAssertEqual(Language.englishCSW.points(for: "quiz"), 22)
        XCTAssertEqual(Language.englishNWL.points(for: "quiz"), 22)
        XCTAssertEqual(Language.englishWOW.points(for: "quiz"), 22)
    }

    func testPointsUseLanguageSpecificScoring() {
        XCTAssertEqual(Language.french.points(for: "quiz"), 20)
        XCTAssertEqual(Language.polish.points(for: "język"), 13)
    }

    func testPointsIgnoreUnsupportedCharacters() {
        XCTAssertEqual(Language.englishCSW.points(for: "a?1😀"), 1)
    }
}
