//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class LanguageExtensionTests: XCTestCase {
    func testPointsUseEnglishScoringForEnglishDictionaries() {
        XCTAssertEqual(Language.englishGB.points(for: "quiz"), 22)
        XCTAssertEqual(Language.englishUS.points(for: "quiz"), 22)
    }

    func testPointsUseLanguageSpecificScoring() {
        XCTAssertEqual(Language.french.points(for: "quiz"), 20)
        XCTAssertEqual(Language.polish.points(for: "język"), 13)
    }

    func testPointsPrecomposeCanonicalCharactersWhenNeeded() {
        let frenchComposed = "àâäçéèêëîïôùûüÿ"
        let frenchDecomposed = "a\u{0300}a\u{0302}a\u{0308}c\u{0327}e\u{0301}e\u{0300}e\u{0302}e\u{0308}i\u{0302}i\u{0308}o\u{0302}u\u{0300}u\u{0302}u\u{0308}y\u{0308}"
        XCTAssertEqual(Language.french.points(for: frenchDecomposed), Language.french.points(for: frenchComposed))

        let polishComposed = "ąćęńóśźż"
        let polishDecomposed = "a\u{0328}c\u{0301}e\u{0328}n\u{0301}o\u{0301}s\u{0301}z\u{0301}z\u{0307}"
        XCTAssertEqual(Language.polish.points(for: polishDecomposed), Language.polish.points(for: polishComposed))
    }

    func testPointsIgnoreUnsupportedCharacters() {
        XCTAssertEqual(Language.englishGB.points(for: "a?1"), 1)
    }
}
