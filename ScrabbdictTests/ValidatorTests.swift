//
//  ValidatorTests.swift
//  ScrabbdictTests
//
//  Created by Piotr Sochalewski on 03.01.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import XCTest
@testable import Scrabbdict

final class ValidatorTests: XCTestCase {
    
    private var sut: Validator!
    
    override func setUp() {
        super.setUp()
        
        sut = Validator()
        sut.language = .englishGB
    }
    
    override func tearDown() {
        super.tearDown()
        
        sut = nil
    }
    
    func testCheckValidWord() {
        let expectation = XCTestExpectation(description: "Closure for check(word:)")
        
        sut.check(word: "pizza") { result in
            switch result {
            case .success(let result):
                switch result {
                case .exists(let points):
                    XCTAssert(points == 25)
                case .notExists:
                    XCTFail()
                }
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCheckInvalidWord() {
        let expectation = XCTestExpectation(description: "Closure for check(word:)")
        
        sut.check(word: "pizzapie") { result in
            switch result {
            case .success(let result):
                switch result {
                case .exists:
                    XCTFail()
                case .notExists:
                    XCTAssert(true)
                }
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }
    
    func testWordsFromLetters() {
        let expectation = XCTestExpectation(description: "Closure for words(from:)")

        let expectedWords = ["pizza", "ziz", "zip", "zap", "za", "pia", "pa", "pi", "ai"]

        sut.words(from: "pizza") { result in
            switch result {
            case .success(let words):
                XCTAssert(expectedWords.count == words.count)
                words.forEach { word in
                    if !expectedWords.contains(word.string) {
                        XCTFail()
                    }
                }
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 20.0)
    }
    
    func testRegexFromPhrase() {
        let expectation = XCTestExpectation(description: "Closure for regex(phrase:)")

        let expectedWords = ["pizza", "pized", "pizes"]

        sut.regex(phrase: "piz??") { result in
            switch result {
            case .success(let words):
                XCTAssert(expectedWords.count == words.count)
                words.forEach { word in
                    if !expectedWords.contains(word.string) {
                        XCTFail()
                    }
                }
            case .error:
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 20.0)
    }
    
    func testLowerAndUppercaseCharacters() {
        let expectation1 = XCTestExpectation(description: "Closure 1")
        let expectation2 = XCTestExpectation(description: "Closure 2")
        let expectation3 = XCTestExpectation(description: "Closure 3")
        let expectation4 = XCTestExpectation(description: "Closure 4")

        sut.check(word: "pizza") { result1 in
            switch result1 {
            case .success(let result1):
                self.sut.check(word: "PiZZa") { result2 in
                    switch result2 {
                    case .success(let result2):
                        XCTAssert(result1 == result2)
                    case .error:
                        XCTFail()
                    }
                    expectation1.fulfill()
                }
            case .error:
                XCTFail()
            }
        }
        
        sut.check(word: "pizzapie") { result1 in
            switch result1 {
            case .success(let result1):
                self.sut.check(word: "pIZzapIe") { result2 in
                    switch result2 {
                    case .success(let result2):
                        XCTAssert(result1 == result2)
                    case .error:
                        XCTFail()
                    }
                    expectation2.fulfill()
                }
            case .error:
                XCTFail()
            }
        }
        
        sut.words(from: "pizzapie") { result1 in
            switch result1 {
            case .success(let words1):
                self.sut.words(from: "pIZzapIe") { result2 in
                    switch result2 {
                    case .success(let words2):
                        XCTAssertFalse(words1.isEmpty)
                        XCTAssert(words1 == words2)
                    case .error:
                        XCTFail()
                    }
                    expectation3.fulfill()
                }
            case .error:
                XCTFail()
            }
        }
        
        sut.regex(phrase: "piz??") { result1 in
            switch result1 {
            case .success(let result1):
                self.sut.regex(phrase: "PiZ??") { result2 in
                    switch result2 {
                    case .success(let result2):
                        XCTAssertFalse(result1.isEmpty)
                        XCTAssert(result1 == result2)
                    case .error:
                        XCTFail()
                    }
                    expectation4.fulfill()
                }
            case .error:
                XCTFail()
            }
        }
        
        wait(for: [expectation1, expectation2, expectation3, expectation4], timeout: 60.0)
    }
    
    func testErrors() {
        let expectation = XCTestExpectation(description: "Error when words(from:) with more than eight letters")

        sut.words(from: "abcdefghi") { result in
            switch result {
            case .success:
                XCTFail()
            case .error(let error):
                XCTAssert(error == .tooManyLetters)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRemoveDiacritics() {
        sut.language = .french
        
        let expectation = XCTestExpectation(description: "Closure for check(word:) with a French diacritic word")
        
        sut.check(word: "même") { result1 in
            switch result1 {
            case .success(let result1):
                self.sut.check(word: "meme") { result2 in
                    switch result2 {
                    case .success(let result2):
                        XCTAssert(result1 == result2)
                    case .error:
                        XCTFail()
                    }
                    expectation.fulfill()
                }
            case .error(let error):
                XCTAssert(error == .tooManyLetters)
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}
