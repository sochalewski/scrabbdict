//
//  Scrabbdict
//  Copyright © 2018 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension Language {
    private enum Constants {
        static let englishLetterPoints: [Character: UInt8] = [
            "a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1, "j": 8, "k": 5, "l": 1, "m": 3, "n": 1, "o": 1, "p": 3, "q": 10, "r": 1, "s": 1, "t": 1, "u": 1, "v": 4, "w": 4, "x": 8, "y": 4, "z": 10
        ]
        static let frenchLetterPoints: [Character: UInt8] = [
            "a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2, "h": 4, "i": 1, "j": 8, "k": 10, "l": 1, "m": 2, "n": 1, "o": 1, "p": 3, "q": 8, "r": 1, "s": 1, "t": 1, "u": 1, "v": 4, "w": 10, "x": 10, "y": 10, "z": 10
        ]
        static let polishLetterPoints: [Character: UInt8] = [
            "a": 1, "ą": 5, "b": 3, "c": 2, "ć": 6, "d": 2, "e": 1, "ę": 5, "f": 5, "g": 3, "h": 3, "i": 1, "j": 3, "k": 2, "l": 2, "ł": 3, "m": 2, "n": 1, "ń": 7, "o": 1, "ó": 5, "p": 2, "r": 1, "s": 1, "ś": 5, "t": 2, "u": 3, "w": 1, "y": 2, "z": 1, "ź": 9, "ż": 5
        ]

        static let englishPointsByScalar = pointsByScalar(from: englishLetterPoints)
        static let frenchPointsByScalar = pointsByScalar(from: frenchLetterPoints)
        static let polishPointsByScalar = pointsByScalar(from: polishLetterPoints)
        static let polishRankByScalar = rankByScalar(
            from: polishLetterPoints,
            locale: .init(identifier: "pl_PL")
        )

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

        static func rankByScalar(
            from letterPoints: [Character: UInt8],
            locale: Locale?
        ) -> [UInt8] {
            guard let locale else {
                preconditionFailure("Alphabetical sorting locale is required")
            }

            let orderedScalars = letterPoints.keys.compactMap(\.unicodeScalars.first).sorted {
                String($0).compare(String($1), options: [], range: nil, locale: locale) == .orderedAscending
            }
            guard let maximumScalar = orderedScalars.map(\.value).max() else { return [] }

            var rankByScalar = [UInt8](repeating: .max, count: Int(maximumScalar) + 1)
            for (rank, scalar) in orderedScalars.enumerated() {
                rankByScalar[Int(scalar.value)] = UInt8(rank)
            }
            return rankByScalar
        }
    }

    var rankByScalar: [UInt8]? {
        switch self {
        case .polish: Constants.polishRankByScalar
        default: nil
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

    func alphabeticallyPrecedes(
        _ lhs: String,
        _ rhs: String,
        rankByScalar: [UInt8]
    ) -> Bool {
        var lhsScalars = lhs.unicodeScalars.makeIterator()
        var rhsScalars = rhs.unicodeScalars.makeIterator()

        while let lhsScalar = lhsScalars.next() {
            guard let rhsScalar = rhsScalars.next() else { return false }

            let lhsRank = alphabetRank(for: lhsScalar, rankByScalar: rankByScalar)
            let rhsRank = alphabetRank(for: rhsScalar, rankByScalar: rankByScalar)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
        }

        return rhsScalars.next() != nil
    }

    private func alphabetRank(
        for scalar: Unicode.Scalar,
        rankByScalar: [UInt8]
    ) -> UInt32 {
        let index = Int(scalar.value)
        guard
            index < rankByScalar.count,
            rankByScalar[index] != .max
        else {
            assertionFailure("Unsupported dictionary scalar: \(scalar)")
            return scalar.value
        }

        return UInt32(rankByScalar[index])
    }
}
