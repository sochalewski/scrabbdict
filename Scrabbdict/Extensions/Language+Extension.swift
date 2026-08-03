//
//  Scrabbdict
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

extension Language {
    private enum Constants {
        static let englishPointsByScalar = pointsByScalar(from: ["a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1, "j": 8, "k": 5, "l": 1, "m": 3, "n": 1, "o": 1, "p": 3, "q": 10, "r": 1, "s": 1, "t": 1, "u": 1, "v": 4, "w": 4, "x": 8, "y": 4, "z": 10])
        static let frenchPointsByScalar = pointsByScalar(from: ["a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1, "j": 8, "k": 10, "l": 1, "m": 2, "n": 1, "o": 1, "p": 3, "q": 8, "r": 1, "s": 1, "t": 1, "u": 1, "v": 4, "w": 10, "x": 10, "y": 10, "z": 10])
        static let polishPointsByScalar = pointsByScalar(from: ["a": 1, "ą": 5, "b": 3, "c": 2, "ć": 6, "d": 2, "e": 1, "ę": 5, "f": 5, "g": 3, "h": 3, "i": 1, "j": 3, "k": 2, "l": 2, "ł": 3, "m": 2, "n": 1, "ń": 7, "o": 1, "ó": 5, "p": 2, "r": 1, "s": 1, "ś": 5, "t": 2, "u": 3, "w": 1, "y": 2, "z": 1, "ź": 9, "ż": 5])

        static func pointsByScalar(from letterPoints: [Character: UInt8]) -> [UInt8] {
            guard let maximumScalar = letterPoints.keys.compactMap({ $0.unicodeScalars.first?.value }).max() else {
                return []
            }

            var pointsByScalar = [UInt8](repeating: 0, count: Int(maximumScalar) + 1)
            for (character, points) in letterPoints {
                guard let scalar = character.unicodeScalars.first else { continue }
                pointsByScalar[Int(scalar.value)] = points
            }
            return pointsByScalar
        }
    }

    private var pointsByScalar: [UInt8] {
        switch self {
        case .englishNWL, .englishCSW, .englishWOW: Constants.englishPointsByScalar
        case .french: Constants.frenchPointsByScalar
        case .polish: Constants.polishPointsByScalar
        }
    }

    func points(for word: String) -> Int {
        let pointsByScalar = pointsByScalar
        var points = 0

        for scalar in word.unicodeScalars {
            let scalarIndex = Int(scalar.value)
            guard scalarIndex < pointsByScalar.count else { continue }
            points += Int(pointsByScalar[scalarIndex])
        }

        return points
    }
}
