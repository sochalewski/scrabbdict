//
//  Scrabbdict
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension [String] {
    /// Maps lexicographically sorted strings to words ordered by descending score, preserving input order for ties.
    func mapToWords(language: Language) -> [Word] {
        assert(indices.dropFirst().allSatisfy { self[$0 - 1] <= self[$0] })

        var words = map { Word(string: $0, points: language.points(for: $0)) }
        words.sort { $0.points > $1.points }
        return words
    }
}
