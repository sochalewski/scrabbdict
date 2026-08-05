//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import XCTest
@testable import Scrabbdict

final class DAWGBuilderTests: XCTestCase {
    func testGeneratedDataCanBeReadByDAWG() throws {
        let words = ["tar", "a", "cat", "ant", "bar", "rat", "an", "bat"]

        let data = try DAWGBuilder(words: words, locale: .init(identifier: "en")).data()
        let dawg = try DAWG(data: data, validatesEdges: true)

        XCTAssertEqual(dawg.count, words.count)

        words.forEach { word in
            XCTAssertTrue(dawg.contains(word), "Expected generated DAWG to contain \(word).")
        }

        XCTAssertFalse(dawg.contains("at"))
        XCTAssertFalse(dawg.contains("bats"))
        XCTAssertEqual(dawg.words(matching: "?at"), ["bat", "cat", "rat"])
        XCTAssertEqual(dawg.words(from: "trab", minLength: 3), ["bar", "bat", "rat", "tar"])
    }

    func testGeneratedDataDeduplicatesDuplicateWords() throws {
        let data = try DAWGBuilder(words: ["ant", "ant", "ant"], locale: .init(identifier: "en")).data()
        let dawg = try DAWG(data: data, validatesEdges: true)

        XCTAssertEqual(dawg.count, 1)
        XCTAssertTrue(dawg.contains("ant"))
    }

    func testGeneratedDataOrdersUnsortedWordsUsingLocaleAlphabet() throws {
        let polishAlphabet = "aąbcćdeęfghijklłmnńoóprsśtuwyzźż".map(String.init)
        let data = try DAWGBuilder(words: Array(polishAlphabet.reversed()), locale: .init(identifier: "pl")).data()
        let dawg = try DAWG(data: data, validatesEdges: true)

        XCTAssertEqual(dawg.words(matching: "?"), polishAlphabet)
    }

    func testGeneratedDataRejectsUnsupportedScalars() {
        XCTAssertThrowsError(try DAWGBuilder(words: ["😀"], locale: .init(identifier: "en")).data()) { error in
            guard case DAWGBuilderError.unsupportedScalar(128_512) = error else {
                return XCTFail("Expected unsupported scalar error, got \(error).")
            }
        }
    }
}
