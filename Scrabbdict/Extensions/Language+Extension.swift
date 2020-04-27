//
//  Language+Extension.swift
//  Scrabbdict
//
//  Created by Piotr Sochalewski on 02.02.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import TinySwift

extension Language {
    private var letterPoints: [Character: Int] {
        switch self {
        case .englishUS, .englishGB:
            return ["A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4, "I": 1, "J": 8, "K": 5, "L": 1, "M": 3, "N": 1, "O": 1, "P": 3, "Q": 10, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 4, "X": 8, "Y": 4, "Z": 10]
        case .polish:
            return ["A": 1, "Ą": 5, "B": 3, "C": 2, "Ć": 6, "D": 2, "E": 1, "Ę": 5, "F": 5, "G": 3, "H": 3, "I": 1, "J": 3, "K": 2, "L": 2, "Ł": 3, "M": 2, "N": 1, "Ń": 7, "O": 1, "Ó": 5, "P": 2, "R": 1, "S": 1, "Ś": 5, "T": 2, "U": 3, "V": 4, "W": 1, "X": 8, "Y": 2, "Z": 1, "Ź": 9, "Ż": 5]
        case .french:
            return ["A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4, "I": 1, "J": 8, "K": 10, "L": 1, "M": 2, "N": 1, "O": 1, "P": 3, "Q": 8, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 10, "X": 10, "Y": 10, "Z": 10]
        }
    }
    
    func points(for word: String) -> Int {
        return word.uppercased().compactMap({ letterPoints[$0] }).sum
    }
}
