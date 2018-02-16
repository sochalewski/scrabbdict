//
//  Collection+Extension.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 02.02.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import Foundation

extension Array where Element == String {
    private func permute(fromList: [String], toList: [String], minStringLen: Int, set: inout Set<String>) {
        if toList.count >= minStringLen {
            set.insert(toList.joined())
        }
        guard !fromList.isEmpty else { return }
        for (index, item) in fromList.enumerated() {
            var newFrom = fromList
            newFrom.remove(at: index)
            permute(fromList: newFrom, toList: toList + [item], minStringLen: minStringLen, set: &set)
        }
    }
    
    /// Returns set of unique permutations of `self`.
    /// - parameter minStringLen: The minimum desired string length. Default is 2.
    func permute(minStringLen: Int = 2) -> Set<String> {
        var set = Set<String>()
        permute(fromList: self, toList: [], minStringLen: minStringLen, set: &set)
        return set
    }
    
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
