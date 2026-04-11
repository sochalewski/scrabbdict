//
//  TrieTests.swift
//  ScrabbdictTests
//
//  Created by Piotr Sochalewski on 11.04.2026.
//  Copyright © 2026 Piotr Sochalewski. All rights reserved.
//

import XCTest
@testable import Scrabbdict

final class TrieTests: XCTestCase {

    func testWordsFromLettersWithRepeatedLetters() {
        let trie = Trie(["aa", "ab", "aba", "baa", "bb", "cab"])

        let words = trie.words(from: "aab").sorted()

        XCTAssertEqual(words, ["aa", "ab", "aba", "baa"])
    }

    func testWordsFromLettersDoesNotReuseLettersMoreThanAvailable() {
        let trie = Trie(["aa", "ab", "abb", "ba", "bb"])

        let words = trie.words(from: "ab").sorted()

        XCTAssertEqual(words, ["ab", "ba"])
    }

    func testWordsFromLettersHonorsMinimumLength() {
        let trie = Trie(["a", "ab", "abc", "cab"])

        let words = trie.words(from: "abc", minLength: 3).sorted()

        XCTAssertEqual(words, ["abc", "cab"])
    }
}
