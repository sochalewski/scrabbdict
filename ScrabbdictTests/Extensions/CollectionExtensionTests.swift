//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class CollectionExtensionTests: XCTestCase {
    func testMapToWordsSortsByPointsDescendingAndPreservesAlphabeticalTies() {
        let words = ["aa", "ab", "ba", "quiz"].mapToWords(language: .englishCSW)

        XCTAssertEqual(words, [
            Word(string: "quiz", points: 22),
            Word(string: "ab", points: 4),
            Word(string: "ba", points: 4),
            Word(string: "aa", points: 2)
        ])
    }

    func testMapToWordsPreservesAlphabeticalOrderAcrossLargeEqualPointGroups() {
        let strings =
            Array(repeating: "ab", count: 128)
                + Array(repeating: "ba", count: 128)
                + Array(repeating: "z", count: 128)

        let words = strings.mapToWords(language: .englishCSW)

        XCTAssertEqual(words, Array(repeating: Word(string: "z", points: 10), count: 128)
            + Array(repeating: Word(string: "ab", points: 4), count: 128)
            + Array(repeating: Word(string: "ba", points: 4), count: 128))
    }
}
