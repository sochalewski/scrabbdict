//
//  Collection+Extension.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 02.02.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import Foundation

extension Array where Element == String {
    func mapToWords(language: Language) -> [Word] {
        guard !isEmpty else { return [] }
        
        return map { Word(string: $0, points: language.points(for: $0)) }
            .sorted {
                if $0.points == $1.points {
                    return $0.string < $1.string
                } else {
                    return $0.points > $1.points
                }
        }
    }
}
