//
//  Scrabbdict
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

extension Language {
    private enum Constants {
        static let englishLetterPoints: [Character: Int] = ["a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1, "j": 8, "k": 5, "l": 1, "m": 3, "n": 1, "o": 1, "p": 3, "q": 10, "r": 1, "s": 1, "t": 1, "u": 1, "v": 4, "w": 4, "x": 8, "y": 4, "z": 10]
        static let frenchLetterPoints: [Character: Int] = ["a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1, "j": 8, "k": 10, "l": 1, "m": 2, "n": 1, "o": 1, "p": 3, "q": 8, "r": 1, "s": 1, "t": 1, "u": 1, "v": 4, "w": 10, "x": 10, "y": 10, "z": 10]
        static let polishLetterPoints: [Character: Int] = ["a": 1, "ą": 5, "b": 3, "c": 2, "ć": 6, "d": 2, "e": 1, "ę": 5, "f": 5, "g": 3, "h": 3, "i": 1, "j": 3, "k": 2, "l": 2, "ł": 3, "m": 2, "n": 1, "ń": 7, "o": 1, "ó": 5, "p": 2, "r": 1, "s": 1, "ś": 5, "t": 2, "u": 3, "w": 1, "y": 2, "z": 1, "ź": 9, "ż": 5]

        static let englishScalarPoints = scalarPoints(from: englishLetterPoints)
        static let frenchScalarPoints = scalarPoints(from: frenchLetterPoints)
        static let polishScalarPoints = scalarPoints(from: polishLetterPoints)

        static func scalarPoints(from letterPoints: [Character: Int]) -> [UInt16: Int] {
            Dictionary(uniqueKeysWithValues: letterPoints.compactMap { character, points in
                guard
                    let scalar = character.unicodeScalars.first,
                    let scalarKey = UInt16(exactly: scalar.value)
                else {
                    return nil
                }

                return (scalarKey, points)
            })
        }
    }

    private var scalarPoints: [UInt16: Int] {
        switch self {
        case .englishNWL, .englishCSW, .englishWOW: Constants.englishScalarPoints
        case .french: Constants.frenchScalarPoints
        case .polish: Constants.polishScalarPoints
        }
    }

    func points(for word: String) -> Int {
        let scalarPoints = scalarPoints
        var points = 0

        for scalar in word.unicodeScalars {
            guard let scalarKey = UInt16(exactly: scalar.value) else { continue }
            points += scalarPoints[scalarKey] ?? 0
        }

        return points
    }
}
