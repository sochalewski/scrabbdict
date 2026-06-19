//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

final class DAWG: Sendable {
    private static let wildcardKey = UInt16.max

    let count: Int

    private let alphabet: [UInt16]
    /// Maps a Unicode scalar to its alphabet key; `.max` marks scalars outside the alphabet.
    private let keyByScalar: [UInt16]
    /// Packed edges as described by ``DAWGFormat``.
    private let edges: [UInt32]

    convenience init?(language: Language, bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: language.rawValue, withExtension: "dawg") else {
            return nil
        }

        do {
            try self.init(url: url)
        } catch {
            return nil
        }
    }

    convenience init(url: URL) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        try self.init(data: data, validatesEdges: false)
    }

    init(data: Data, validatesEdges: Bool) throws {
        let (wordCount, alphabet, edges) = try data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) throws -> (Int, [UInt16], [UInt32]) in
            guard buffer.count >= DAWGFormat.headerSize else { throw DAWGError.invalidHeader }

            let magic = buffer.readLittleEndianUInt32(at: 0)
            let version = buffer.readLittleEndianUInt32(at: 4)
            let wordCount = buffer.readLittleEndianUInt32(at: 8)
            let edgeCount = Int(buffer.readLittleEndianUInt32(at: 12))
            let alphabetCount = Int(buffer.readLittleEndianUInt32(at: 16))

            guard magic == DAWGFormat.magic, version == DAWGFormat.version else { throw DAWGError.invalidHeader }

            let alphabetOffset = DAWGFormat.headerSize
            let edgesOffset = alphabetOffset + alphabetCount * MemoryLayout<UInt16>.size
            let expectedSize = edgesOffset + edgeCount * DAWGFormat.edgeSize
            guard buffer.count == expectedSize else { throw DAWGError.invalidSize }

            let alphabet = (0..<alphabetCount).map { index in
                buffer.readLittleEndianUInt16(at: alphabetOffset + index * MemoryLayout<UInt16>.size)
            }

            let edges = [UInt32](unsafeUninitializedCapacity: edgeCount) { destination, initializedCount in
                for index in 0..<edgeCount {
                    destination[index] = buffer.readLittleEndianUInt32(at: edgesOffset + index * DAWGFormat.edgeSize)
                }
                initializedCount = edgeCount
            }

            if validatesEdges {
                try Self.validateEdges(edges, alphabetCount: alphabet.count)
            }

            return (Int(wordCount), alphabet, edges)
        }

        var keyByScalar = [UInt16](repeating: .max, count: Int(alphabet.max() ?? 0) + 1)
        for (index, scalar) in alphabet.enumerated() {
            keyByScalar[Int(scalar)] = UInt16(index)
        }

        self.count = wordCount
        self.alphabet = alphabet
        self.keyByScalar = keyByScalar
        self.edges = edges
    }

    func contains(_ word: String) -> Bool {
        guard !edges.isEmpty else { return false }

        var firstEdge: UInt32 = 0
        var hasOutgoingEdges = true
        var isWord = false

        for scalar in word.unicodeScalars {
            guard
                hasOutgoingEdges,
                let scalarKey = UInt16(exactly: scalar.value),
                let key = key(for: scalarKey),
                let edge = edge(for: key, startingAt: firstEdge)
            else { return false }

            isWord = edge & DAWGFormat.edgeWordFlag != 0
            firstEdge = edge & DAWGFormat.edgeTargetMask
            hasOutgoingEdges = firstEdge != 0
        }

        return isWord
    }

    func words(from letters: String, minLength: Int = 2) -> [String] {
        guard !letters.isEmpty, !edges.isEmpty else { return [] }

        var availableLetters = LetterCounter(letters, alphabetCount: alphabet.count, keyForScalar: key)
        guard !availableLetters.isEmpty else { return [] }

        var currentWord = [UInt16]()
        currentWord.reserveCapacity(letters.unicodeScalars.count)

        var result = [String]()
        collectWords(fromEdgesAt: 0, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
        return result
    }

    func words(matching pattern: String) -> [String] {
        guard !pattern.isEmpty, !edges.isEmpty else { return [] }

        var patternKeys = [UInt16]()
        patternKeys.reserveCapacity(pattern.unicodeScalars.count)

        for scalar in pattern.unicodeScalars {
            guard let scalarKey = UInt16(exactly: scalar.value) else { return [] }
            if scalarKey == UInt16(UnicodeScalar("?").value) {
                patternKeys.append(Self.wildcardKey)
            } else if let key = key(for: scalarKey) {
                patternKeys.append(key)
            } else {
                return []
            }
        }

        var currentWord = [UInt16]()
        currentWord.reserveCapacity(patternKeys.count)

        var result = [String]()
        collectWords(matching: patternKeys, patternIndex: 0, edgesAt: 0, currentWord: &currentWord, result: &result)
        return result
    }

    private func scalar(for key: UInt16) -> UInt16 {
        alphabet[Int(key)]
    }

    private func key(for scalar: UInt16) -> UInt16? {
        guard Int(scalar) < keyByScalar.count else { return nil }

        let key = keyByScalar[Int(scalar)]
        return key == .max ? nil : key
    }

    private func string(from keys: [UInt16]) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(keys.count)

        for key in keys {
            scalars.append(UnicodeScalar(scalar(for: key))!)
        }

        return String(scalars)
    }

    private func collectWords(
        fromEdgesAt firstEdge: UInt32,
        using availableLetters: inout LetterCounter,
        minLength: Int,
        currentWord: inout [UInt16],
        result: inout [String]
    ) {
        var edgeIndex = Int(firstEdge)

        while true {
            let edge = edges[edgeIndex]
            let key = UInt16(edge >> DAWGFormat.edgeKeyShift)

            if availableLetters.consume(key) {
                currentWord.append(key)

                if edge & DAWGFormat.edgeWordFlag != 0, currentWord.count >= minLength {
                    result.append(string(from: currentWord))
                }

                let target = edge & DAWGFormat.edgeTargetMask
                if target != 0 {
                    collectWords(fromEdgesAt: target, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
                }

                currentWord.removeLast()
                availableLetters.restore(key)
            }

            if edge & DAWGFormat.edgeLastFlag != 0 {
                break
            }
            edgeIndex += 1
        }
    }

    private func collectWords(
        matching pattern: [UInt16],
        patternIndex: Int,
        edgesAt firstEdge: UInt32,
        currentWord: inout [UInt16],
        result: inout [String]
    ) {
        let patternKey = pattern[patternIndex]

        if patternKey == Self.wildcardKey {
            var edgeIndex = Int(firstEdge)

            while true {
                let edge = edges[edgeIndex]
                descend(along: edge, matching: pattern, patternIndex: patternIndex, currentWord: &currentWord, result: &result)

                if edge & DAWGFormat.edgeLastFlag != 0 {
                    break
                }
                edgeIndex += 1
            }
        } else if let edge = edge(for: patternKey, startingAt: firstEdge) {
            descend(along: edge, matching: pattern, patternIndex: patternIndex, currentWord: &currentWord, result: &result)
        }
    }

    private func descend(
        along edge: UInt32,
        matching pattern: [UInt16],
        patternIndex: Int,
        currentWord: inout [UInt16],
        result: inout [String]
    ) {
        currentWord.append(UInt16(edge >> DAWGFormat.edgeKeyShift))

        if patternIndex == pattern.count - 1 {
            if edge & DAWGFormat.edgeWordFlag != 0 {
                result.append(string(from: currentWord))
            }
        } else {
            let target = edge & DAWGFormat.edgeTargetMask
            if target != 0 {
                collectWords(matching: pattern, patternIndex: patternIndex + 1, edgesAt: target, currentWord: &currentWord, result: &result)
            }
        }

        currentWord.removeLast()
    }

    private func edge(for key: UInt16, startingAt firstEdge: UInt32) -> UInt32? {
        var edgeIndex = Int(firstEdge)

        while true {
            let edge = edges[edgeIndex]
            let edgeKey = UInt16(edge >> DAWGFormat.edgeKeyShift)
            if edgeKey == key {
                return edge
            }
            if edgeKey > key {
                break
            }
            if edge & DAWGFormat.edgeLastFlag != 0 {
                break
            }
            edgeIndex += 1
        }

        return nil
    }
}

private extension DAWG {
    static func validateEdges(_ edges: [UInt32], alphabetCount: Int) throws {
        var previousEdgeKey: UInt16 = 0
        var isWithinNodeBlock = false

        for edge in edges {
            let edgeKey = UInt16(edge >> DAWGFormat.edgeKeyShift)
            guard
                Int(edge & DAWGFormat.edgeTargetMask) < edges.count,
                Int(edgeKey) < alphabetCount,
                // Edge lookup relies on keys sorted ascending within a node block.
                !isWithinNodeBlock || edgeKey > previousEdgeKey
            else { throw DAWGError.invalidEdges }

            previousEdgeKey = edgeKey
            isWithinNodeBlock = edge & DAWGFormat.edgeLastFlag == 0
        }
        if let lastEdge = edges.last {
            guard lastEdge & DAWGFormat.edgeLastFlag != 0 else { throw DAWGError.invalidEdges }
        }
    }
}

private enum DAWGError: Error {
    case invalidHeader
    case invalidSize
    case invalidEdges
}

private struct LetterCounter: Sendable {
    private var counts: [UInt8]
    private var hasLetters = false

    var isEmpty: Bool {
        !hasLetters
    }

    init(_ letters: String, alphabetCount: Int, keyForScalar: (UInt16) -> UInt16?) {
        self.counts = [UInt8](repeating: 0, count: alphabetCount)

        for scalar in letters.unicodeScalars {
            guard
                let scalarKey = UInt16(exactly: scalar.value),
                let key = keyForScalar(scalarKey)
            else { continue }

            counts[Int(key)] += 1
            self.hasLetters = true
        }
    }

    mutating func consume(_ key: UInt16) -> Bool {
        let index = Int(key)
        guard counts[index] > 0 else { return false }

        counts[index] -= 1
        return true
    }

    mutating func restore(_ key: UInt16) {
        counts[Int(key)] += 1
    }
}

private extension UnsafeRawBufferPointer {
    func readLittleEndianUInt16(at offset: Int) -> UInt16 {
        UInt16(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt16.self))
    }

    func readLittleEndianUInt32(at offset: Int) -> UInt32 {
        UInt32(littleEndian: loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }
}
