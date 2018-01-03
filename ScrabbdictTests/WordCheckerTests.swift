//
//  WordCheckerTests.swift
//  ScrabbdictTests
//
//  Created by Piotr Sochalewski on 03.01.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import XCTest
@testable import Scrabbdict

final class WordCheckerTests: XCTestCase {
    
    private let sut = WordChecker()
    
    override func setUp() {
        super.setUp()
        
        sut.language = .englishGB
    }
    
    func testCheckWord() {
        let resultThatShouldExist = sut.check(word: "pizza")
        switch resultThatShouldExist {
        case .exists(let points):
            XCTAssert(points == 25)
        case .notExists:
            XCTFail()
        }
        
        let resultThatShouldNotExist = sut.check(word: "pizzapie")
        switch resultThatShouldNotExist {
        case .exists:
            XCTFail()
        case .notExists:
            XCTAssert(true)
        }
    }
    
    func testWordsFromLetters() {
        let words = sut.words(from: "pizza")!
        let expectedWords = ["pizza", "ziz", "zip", "zap", "za", "pia", "pa", "pi", "ai"]
        
        words.forEach { word in
            if !expectedWords.contains(word.string) {
                XCTFail()
            }
        }
        
        XCTAssert(expectedWords.count == words.count)
    }
    
    func testRegexFromPhrase() {
        let words = sut.regex(from: "piz??")!
        let expectedWords = ["pizza", "pized", "pizes"]
        
        words.forEach { word in
            if !expectedWords.contains(word.string) {
                XCTFail()
            }
        }
        
        XCTAssert(expectedWords.count == words.count)
    }
    
    func testLowerAndUppercaseCharacters() {
        XCTAssert(sut.check(word: "pizza") == sut.check(word: "PiZZa"))
        XCTAssert(sut.check(word: "pizzapie") == sut.check(word: "pIZzapIe"))
        
        XCTAssert(sut.words(from: "pizza")! == sut.words(from: "pIZZa")!)
        
        XCTAssert(sut.words(from: "piz??")! == sut.words(from: "PiZ??")!)
    }
    
    func testMultipartDictionaries() {
        XCTAssertFalse(sut.isMultipartDictionarySwapRequired(for: "shorten"))
        XCTAssertFalse(sut.isMultipartDictionarySwapRequired(for: "averylongenglish"))
        
        sut.language = .polish
        XCTAssertFalse(sut.isMultipartDictionarySwapRequired(for: "krotkipl"))
        XCTAssertTrue(sut.isMultipartDictionarySwapRequired(for: "dlugieslowopol"))
    }
}
