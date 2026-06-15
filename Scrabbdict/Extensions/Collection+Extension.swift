//
//  Scrabbdict
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension [String] {
    func mapToWords(language: Language) -> [Word] {
        map { Word(string: $0, points: language.points(for: $0)) }
            .sorted {
                if $0.points == $1.points {
                    $0.string < $1.string
                } else {
                    $0.points > $1.points
                }
            }
    }
}
