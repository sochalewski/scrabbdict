//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class DAWGTests: XCTestCase {
    // MARK: - Integration smoke tests using bundled dictionaries

    func testContainsExistingWord() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishCSW))

        XCTAssertTrue(dawg.contains("pizza"))
    }

    func testDoesNotContainMissingWord() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishCSW))

        XCTAssertFalse(dawg.contains("pizzapie"))
    }

    func testWordsFromLettersWithRepeatedLetters() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishCSW))

        let words = dawg.words(from: "pizza")

        XCTAssertTrue(words.contains("pizza"))
        XCTAssertTrue(words.contains("ziz"))
        XCTAssertTrue(words.contains("zip"))
        XCTAssertTrue(words.contains("zap"))
    }

    func testWordsFromLettersHonorsMinimumLength() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishCSW))

        let words = dawg.words(from: "pizza", minLength: 4)

        XCTAssertTrue(words.allSatisfy { $0.count >= 4 })
        XCTAssertTrue(words.contains("pizza"))
    }

    func testWordsMatchingPattern() throws {
        let dawg = try XCTUnwrap(DAWG(language: .englishCSW))

        let words = dawg.words(matching: "piz??").sorted()

        XCTAssertEqual(words, ["pized", "pizes", "pizza"])
    }

    func testBundledDictionariesHaveValidEdges() throws {
        for language in Language.allCases {
            let url = try XCTUnwrap(
                Bundle.main.url(forResource: language.rawValue, withExtension: "dawg"),
                "Missing bundled DAWG for \(language.rawValue)."
            )
            let data = try Data(contentsOf: url, options: .mappedIfSafe)

            XCTAssertNoThrow(
                try DAWG(data: data, validatesEdges: true),
                "Bundled DAWG has invalid edges: \(language.rawValue)."
            )
        }
    }

    // MARK: - Unit tests using controlled DAWG data

    // MARK: Contains

    func testContainsControlledWordsAndRejectsMissingWords() throws {
        let dawg = try makeTestDAWG(words: ["an", "ant", "bat"])

        XCTAssertTrue(dawg.contains("an"))
        XCTAssertTrue(dawg.contains("ant"))
        XCTAssertTrue(dawg.contains("bat"))
        XCTAssertFalse(dawg.contains("a"))
        XCTAssertFalse(dawg.contains("ants"))
        XCTAssertFalse(dawg.contains("cat"))
    }

    func testContainsReturnsFalseForUnsupportedScalars() throws {
        let dawg = try makeTestDAWG(words: ["an", "ant"])

        XCTAssertFalse(dawg.contains("😀"))
    }

    // MARK: Words from letters

    func testWordsFromLettersHonorsAvailableLetterCountsWithControlledData() throws {
        let dawg = try makeTestDAWG(words: ["ab", "abb", "abc", "ba"])

        XCTAssertEqual(dawg.words(from: "ab").sorted(), ["ab", "ba"])
    }

    func testWordsFromLettersHonorsMinimumLengthWithControlledData() throws {
        let dawg = try makeTestDAWG(words: ["an", "ant", "tan"])

        XCTAssertEqual(dawg.words(from: "tan", minLength: 3).sorted(), ["ant", "tan"])
    }

    func testWordsFromLettersReturnsEmptyForEmptyOrUnsupportedLetters() throws {
        let dawg = try makeTestDAWG(words: ["ab", "ba"])

        XCTAssertEqual(dawg.words(from: ""), [])
        XCTAssertEqual(dawg.words(from: "😀"), [])
    }

    // MARK: Words matching pattern

    func testWordsMatchingExactPattern() throws {
        let dawg = try makeTestDAWG(words: ["bat", "cat", "rat", "tar", "tea", "ted"])

        XCTAssertEqual(dawg.words(matching: "bat"), ["bat"])
    }

    func testWordsMatchingWildcardAtDifferentPositions() throws {
        let dawg = try makeTestDAWG(words: ["bat", "cat", "rat", "tar", "tea", "ted"])

        XCTAssertEqual(dawg.words(matching: "?at").sorted(), ["bat", "cat", "rat"])
        XCTAssertEqual(dawg.words(matching: "t?r").sorted(), ["tar"])
        XCTAssertEqual(dawg.words(matching: "te?").sorted(), ["tea", "ted"])
    }

    func testWordsMatchingReturnsEmptyForUnsupportedPatterns() throws {
        let dawg = try makeTestDAWG(words: ["bat", "cat", "rat"])

        XCTAssertEqual(dawg.words(matching: ""), [])
        XCTAssertEqual(dawg.words(matching: "bats"), [])
        XCTAssertEqual(dawg.words(matching: "z??"), [])
        XCTAssertEqual(dawg.words(matching: "😀"), [])
    }

    // MARK: Binary format validation

    func testRejectsInvalidMagic() {
        let data = makeDAWGData(magic: 0)

        XCTAssertThrowsError(try DAWG(data: data, validatesEdges: true))
    }

    func testRejectsUnsupportedVersion() {
        let data = makeDAWGData(version: 0)

        XCTAssertThrowsError(try DAWG(data: data, validatesEdges: true))
    }

    func testRejectsInvalidSize() {
        var data = makeDAWGData()
        data.removeLast()

        XCTAssertThrowsError(try DAWG(data: data, validatesEdges: true))
    }

    func testRejectsEdgeTargetOutsideEdgeTable() {
        let data = makeDAWGData(edges: [
            packedEdge(keyIndex: 0, target: 1, isWord: true, isLast: true)
        ])

        XCTAssertThrowsError(try DAWG(data: data, validatesEdges: true))
    }

    func testRejectsEdgeKeyOutsideAlphabet() {
        let data = makeDAWGData(edges: [
            packedEdge(keyIndex: 1, target: 0, isWord: true, isLast: true)
        ])

        XCTAssertThrowsError(try DAWG(data: data, validatesEdges: true))
    }

    func testRejectsUnsortedEdgesWithinNodeBlock() {
        let data = makeDAWGData(
            alphabet: ["a", "b"],
            edges: [
                packedEdge(keyIndex: 1, target: 0, isWord: true, isLast: false),
                packedEdge(keyIndex: 0, target: 0, isWord: true, isLast: true)
            ]
        )

        XCTAssertThrowsError(try DAWG(data: data, validatesEdges: true))
    }

    func testRejectsEdgeTableWithoutLastFlag() {
        let data = makeDAWGData(edges: [
            packedEdge(keyIndex: 0, target: 0, isWord: true, isLast: false)
        ])

        XCTAssertThrowsError(try DAWG(data: data, validatesEdges: true))
    }
}

private func makeTestDAWG(words: [String]) throws -> DAWG {
    try DAWG(data: DAWGBuilder(words: words.sorted()).data(), validatesEdges: true)
}

private func makeDAWGData(
    magic: UInt32 = DAWGFormat.magic,
    version: UInt32 = DAWGFormat.version,
    wordCount: UInt32 = 1,
    alphabet: [UnicodeScalar] = ["a"],
    edges: [UInt32] = [packedEdge(keyIndex: 0, target: 0, isWord: true, isLast: true)]
) -> Data {
    var data = Data()
    data.appendLittleEndianUInt32(magic)
    data.appendLittleEndianUInt32(version)
    data.appendLittleEndianUInt32(wordCount)
    data.appendLittleEndianUInt32(UInt32(edges.count))
    data.appendLittleEndianUInt32(UInt32(alphabet.count))
    alphabet.forEach { data.appendLittleEndianUInt16(UInt16($0.value)) }
    edges.forEach { data.appendLittleEndianUInt32($0) }
    return data
}

private func packedEdge(
    keyIndex: UInt32,
    target: UInt32,
    isWord: Bool,
    isLast: Bool
) -> UInt32 {
    var edge = target
    if isWord {
        edge |= DAWGFormat.edgeWordFlag
    }
    if isLast {
        edge |= DAWGFormat.edgeLastFlag
    }
    edge |= keyIndex << DAWGFormat.edgeKeyShift
    return edge
}
