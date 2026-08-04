//
//  Scrabbdict
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension [String] {
    /// Maps DAWG-ordered strings to words ordered by descending score, using Polish alphabetical order for Polish ties.
    func mapToWords(language: Language) -> [Word] {
        assert(indices.dropFirst().allSatisfy { self[$0 - 1] <= self[$0] })

        var words = map { Word(string: $0, points: language.points(for: $0)) }
        if let rankByScalar = language.rankByScalar {
            words.sort {
                if $0.points != $1.points {
                    return $0.points > $1.points
                }
                return language.alphabeticallyPrecedes(
                    $0.string,
                    $1.string,
                    rankByScalar: rankByScalar
                )
            }
        } else {
            words.sort { $0.points > $1.points }
        }
        return words
    }
}
