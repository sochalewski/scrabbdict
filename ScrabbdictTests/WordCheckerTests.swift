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
    
    private var sut: WordChecker!
    
    override func setUp() {
        super.setUp()
        
        sut = WordChecker()
        sut.language = .englishGB
    }
    
    override func tearDown() {
        super.tearDown()
        
        sut = nil
    }
    
    func testCheckValidWord() {
        let exceptation = XCTestExpectation(description: "Closure for check(word:)")
        
        sut.check(word: "pizza") { result in
            switch result {
            case .exists(let points):
                XCTAssert(points == 25)
            case .notExists:
                XCTFail()
            }
            
            exceptation.fulfill()
        }
        
        wait(for: [exceptation], timeout: 10.0)
    }
    
    func testCheckInvalidWord() {
        let exceptation = XCTestExpectation(description: "Closure for check(word:)")
        
        sut.check(word: "pizzapie") { result in
            switch result {
            case .exists:
                XCTFail()
            case .notExists:
                XCTAssert(true)
            }
            
            exceptation.fulfill()
        }

        wait(for: [exceptation], timeout: 10.0)
    }
    
    func testWordsFromLetters() {
        let exceptation = XCTestExpectation(description: "Closure for words(from:)")

        let expectedWords = ["pizza", "ziz", "zip", "zap", "za", "pia", "pa", "pi", "ai"]

        sut.words(from: "pizza") { words in
            XCTAssert(expectedWords.count == words!.count)
            words!.forEach { word in
                if !expectedWords.contains(word.string) {
                    XCTFail()
                }
            }
            
            exceptation.fulfill()
        }
        
        wait(for: [exceptation], timeout: 20.0)
    }
    
    func testRegexFromPhrase() {
        let exceptation = XCTestExpectation(description: "Closure for regex(phrase:)")

        let expectedWords = ["pizza", "pized", "pizes"]

        sut.regex(phrase: "piz??") { words in
            XCTAssert(expectedWords.count == words!.count)
            words!.forEach { word in
                if !expectedWords.contains(word.string) {
                    XCTFail()
                }
            }
            
            exceptation.fulfill()
        }
        
        wait(for: [exceptation], timeout: 20.0)
    }
    
    func testLowerAndUppercaseCharacters() {
        let exceptation1 = XCTestExpectation(description: "Closure 1")
        let exceptation2 = XCTestExpectation(description: "Closure 2")
        let exceptation3 = XCTestExpectation(description: "Closure 3")
        let exceptation4 = XCTestExpectation(description: "Closure 4")

        sut.check(word: "pizza") { result1 in
            self.sut.check(word: "PiZZa") { result2 in
                XCTAssert(result1 == result2)
                exceptation1.fulfill()
            }
        }
        
        sut.check(word: "pizzapie") { result1 in
            self.sut.check(word: "pIZzapIe") { result2 in
                XCTAssert(result1 == result2)
                exceptation2.fulfill()
            }
        }
        
        sut.words(from: "pizzapie") { result1 in
            self.sut.words(from: "pIZzapIe") { result2 in
                XCTAssert(result1! == result2!)
                exceptation3.fulfill()
            }
        }
        
        sut.regex(phrase: "piz??") { result1 in
            self.sut.regex(phrase: "PiZ??") { result2 in
                XCTAssert(result1! == result2!)
                exceptation4.fulfill()
            }
        }
        
        wait(for: [exceptation1, exceptation2, exceptation3, exceptation4], timeout: 60.0)
    }
}
