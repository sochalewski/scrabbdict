//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class CollectionExtensionTests: XCTestCase {
    func testMapToWordsSortsByPointsDescendingThenStringAscending() {
        let words = ["aa", "ba", "quiz", "ab"].mapToWords(language: .englishCSW)

        XCTAssertEqual(words, [
            Word(string: "quiz", points: 22),
            Word(string: "ab", points: 4),
            Word(string: "ba", points: 4),
            Word(string: "aa", points: 2)
        ])
    }
}
