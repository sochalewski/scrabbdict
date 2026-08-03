//
//  DAWGPerformance
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

enum BenchmarkOperation: String {
    case load
    case contains
    case words
    case pattern
}

struct BenchmarkWorkload {
    let name: String
    let language: Language
    let operation: BenchmarkOperation
    let query: String
    let pilotOperations: Int
}

let benchmarkWorkloads = [
    BenchmarkWorkload(name: "testLoadEnglishCSW", language: .englishCSW, operation: .load, query: "", pilotOperations: 100),
    BenchmarkWorkload(name: "testLoadEnglishNWL", language: .englishNWL, operation: .load, query: "", pilotOperations: 100),
    BenchmarkWorkload(name: "testLoadEnglishWOW", language: .englishWOW, operation: .load, query: "", pilotOperations: 100),
    BenchmarkWorkload(name: "testLoadFrench", language: .french, operation: .load, query: "", pilotOperations: 100),
    BenchmarkWorkload(name: "testLoadPolish", language: .polish, operation: .load, query: "", pilotOperations: 100),
    BenchmarkWorkload(name: "testContainsEnglishCSW", language: .englishCSW, operation: .contains, query: "pizzapie", pilotOperations: 100_000),
    BenchmarkWorkload(name: "testContainsEnglishNWL", language: .englishNWL, operation: .contains, query: "pizzapie", pilotOperations: 100_000),
    BenchmarkWorkload(name: "testContainsEnglishWOW", language: .englishWOW, operation: .contains, query: "pizzapie", pilotOperations: 100_000),
    BenchmarkWorkload(name: "testContainsFrench", language: .french, operation: .contains, query: "mangeurs", pilotOperations: 100_000),
    BenchmarkWorkload(name: "testContainsPolish", language: .polish, operation: .contains, query: "kotkami", pilotOperations: 100_000),
    BenchmarkWorkload(name: "testWordsEnglishCSW", language: .englishCSW, operation: .words, query: "pizzapie", pilotOperations: 500),
    BenchmarkWorkload(name: "testWordsEnglishNWL", language: .englishNWL, operation: .words, query: "pizzapie", pilotOperations: 500),
    BenchmarkWorkload(name: "testWordsEnglishWOW", language: .englishWOW, operation: .words, query: "pizzapie", pilotOperations: 500),
    BenchmarkWorkload(name: "testWordsFrench", language: .french, operation: .words, query: "mangeurs", pilotOperations: 500),
    BenchmarkWorkload(name: "testWordsPolish", language: .polish, operation: .words, query: "kotkami", pilotOperations: 500),
    BenchmarkWorkload(name: "testPatternEnglishCSW", language: .englishCSW, operation: .pattern, query: "piz??", pilotOperations: 3_000),
    BenchmarkWorkload(name: "testPatternEnglishNWL", language: .englishNWL, operation: .pattern, query: "piz??", pilotOperations: 3_000),
    BenchmarkWorkload(name: "testPatternEnglishWOW", language: .englishWOW, operation: .pattern, query: "piz??", pilotOperations: 3_000),
    BenchmarkWorkload(name: "testPatternFrench", language: .french, operation: .pattern, query: "mang???", pilotOperations: 3_000),
    BenchmarkWorkload(name: "testPatternPolish", language: .polish, operation: .pattern, query: "kot???", pilotOperations: 3_000)
]
