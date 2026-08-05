//
//  Scrabbdict
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension [String] {
    /// Maps DAWG-ordered strings to words ordered by descending score while preserving the encoded alphabet order for ties.
    func mapToWords(language: Language) -> [Word] {
        var words = map { Word(string: $0, points: language.points(for: $0)) }
        words.sort { $0.points > $1.points }
        return words
    }
}
