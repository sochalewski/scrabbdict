//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

final class DAWG: @unchecked Sendable {
    private static let wildcardKey = UInt16.max

    let count: Int

    /// Maps an alphabet key, in localized traversal order for generator-produced DAWGs, to its UTF-8 bytes
    /// packed little-endian in the low 24 bits, with the byte count in the high 8 bits.
    private let scalarUTF8ByKey: [UInt32]
    /// Maps a Unicode scalar to its alphabet key; `.max` marks scalars outside the alphabet.
    private let keyByScalar: [UInt16]
    /// Maps an alphabet key to its root-edge offset; `.max` marks keys absent from the root.
    private let rootEdgeOffsetByKey: [UInt16]
    /// Packed edges as described by ``DAWGFormat``, read in place from `data`.
    private let edges: UnsafeRawBufferPointer
    /// Owns the memory-mapped file or copied bytes backing `edges`.
    private let data: NSData

    convenience init(language: Language, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: language.rawValue, withExtension: "dawg") else {
            throw DAWGError.resourceUnavailable
        }

        try self.init(url: url)
    }

    /// Loads a trusted generator-produced DAWG without revalidating its ordering invariants.
    convenience init(url: URL) throws {
        try self.init(data: NSData(contentsOf: url, options: .alwaysMapped), validatesEdges: false)
    }

    convenience init(data: Data, validatesEdges: Bool) throws {
        try self.init(data: NSData(data: data), validatesEdges: validatesEdges)
    }

    private init(data: NSData, validatesEdges: Bool) throws {
        guard data.length >= DAWGFormat.headerSize else { throw DAWGError.invalidHeader }
        let buffer = UnsafeRawBufferPointer(start: data.bytes, count: data.length)

        let magic = buffer.readLittleEndianUInt32(at: 0)
        let version = buffer.readLittleEndianUInt32(at: 4)
        let wordCount = buffer.readLittleEndianUInt32(at: 8)
        let edgeCount = Int(buffer.readLittleEndianUInt32(at: 12))
        let alphabetCount = Int(buffer.readLittleEndianUInt32(at: 16))

        guard magic == DAWGFormat.magic, version == DAWGFormat.version else { throw DAWGError.invalidHeader }
        guard alphabetCount <= Int(UInt8.max) + 1 else { throw DAWGError.invalidAlphabet }

        let alphabetOffset = DAWGFormat.headerSize
        let edgesOffset = alphabetOffset + alphabetCount * MemoryLayout<UInt16>.size
        let expectedSize = edgesOffset + edgeCount * DAWGFormat.edgeSize
        guard buffer.count == expectedSize else { throw DAWGError.invalidSize }

        let alphabet = (0..<alphabetCount).map { index in
            buffer.readLittleEndianUInt16(at: alphabetOffset + index * MemoryLayout<UInt16>.size)
        }

        var scalarUTF8ByKey = [UInt32]()
        scalarUTF8ByKey.reserveCapacity(alphabet.count)
        for value in alphabet {
            guard let scalar = Unicode.Scalar(value) else { throw DAWGError.invalidAlphabet }
            var packed: UInt32 = 0
            var byteCount: UInt32 = 0
            for byte in UTF8.encode(scalar).unsafelyUnwrapped {
                packed |= UInt32(byte) << (byteCount * 8)
                byteCount += 1
            }
            scalarUTF8ByKey.append(packed | byteCount << 24)
        }

        let edges = UnsafeRawBufferPointer(rebasing: buffer[edgesOffset...])

        if validatesEdges {
            try Self.validateEdges(edges, alphabetCount: alphabet.count)
        }

        var keyByScalar = [UInt16](repeating: .max, count: Int(alphabet.max() ?? 0) + 1)
        for (index, scalar) in alphabet.enumerated() {
            keyByScalar[Int(scalar)] = UInt16(index)
        }

        var rootEdgeOffsetByKey = [UInt16](repeating: .max, count: alphabet.count)
        if !edges.isEmpty {
            var edgeIndex = 0
            while true {
                let edge = edges.edge(at: edgeIndex)
                let key = UInt16(edge >> DAWGFormat.edgeKeyShift)
                rootEdgeOffsetByKey[Int(key)] = UInt16(edgeIndex)
                if edge & DAWGFormat.edgeLastFlag != 0 {
                    break
                }
                edgeIndex += 1
            }
        }

        self.count = Int(wordCount)
        self.scalarUTF8ByKey = scalarUTF8ByKey
        self.keyByScalar = keyByScalar
        self.rootEdgeOffsetByKey = rootEdgeOffsetByKey
        self.edges = edges
        self.data = data
    }

    func contains(_ word: String) -> Bool {
        guard !edges.isEmpty else { return false }

        var scalars = word.unicodeScalars.makeIterator()
        guard
            let firstScalar = scalars.next(),
            let scalarKey = UInt16(exactly: firstScalar.value),
            let firstKey = key(for: scalarKey),
            let rootEdge = rootEdge(for: firstKey)
        else { return false }

        var isWord = rootEdge & DAWGFormat.edgeWordFlag != 0
        var firstEdge = rootEdge & DAWGFormat.edgeTargetMask

        while let scalar = scalars.next() {
            guard
                firstEdge != 0,
                let scalarKey = UInt16(exactly: scalar.value),
                let key = key(for: scalarKey),
                let edge = edge(for: key, startingAt: firstEdge)
            else { return false }

            isWord = edge & DAWGFormat.edgeWordFlag != 0
            firstEdge = edge & DAWGFormat.edgeTargetMask
        }

        return isWord
    }

    /// Returns constructible words in the dictionary's encoded alphabet order.
    func words(from letters: String, minLength: Int = 2) -> [String] {
        guard !letters.isEmpty, !edges.isEmpty else { return [] }

        var availableLetters = LetterCounter(letters, alphabetCount: scalarUTF8ByKey.count, keyForScalar: key)
        guard !availableLetters.isEmpty else { return [] }

        var currentWord = [UInt16]()
        currentWord.reserveCapacity(letters.unicodeScalars.count)

        var result = [String]()
        collectWords(fromEdgesAt: 0, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
        return result
    }

    /// Returns words matching the pattern in the dictionary's encoded alphabet order.
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

    private func key(for scalar: UInt16) -> UInt16? {
        guard Int(scalar) < keyByScalar.count else { return nil }

        let key = keyByScalar[Int(scalar)]
        return key == .max ? nil : key
    }

    private func rootEdge(for key: UInt16) -> UInt32? {
        let offset = rootEdgeOffsetByKey[Int(key)]
        return offset == .max ? nil : edges.edge(at: Int(offset))
    }

    private func string(from keys: [UInt16]) -> String {
        var byteCount = 0
        for key in keys {
            byteCount &+= Int(scalarUTF8ByKey[Int(key)] >> 24)
        }

        return String(unsafeUninitializedCapacity: byteCount) { buffer in
            var offset = 0
            for key in keys {
                var encoded = scalarUTF8ByKey[Int(key)]
                for _ in 0..<Int(encoded >> 24) {
                    buffer[offset] = UInt8(truncatingIfNeeded: encoded)
                    encoded >>= 8
                    offset &+= 1
                }
            }
            return offset
        }
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
            let edge = edges.edge(at: edgeIndex)
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
                let edge = edges.edge(at: edgeIndex)
                descend(along: edge, matching: pattern, patternIndex: patternIndex, currentWord: &currentWord, result: &result)

                if edge & DAWGFormat.edgeLastFlag != 0 {
                    break
                }
                edgeIndex += 1
            }
        } else {
            let edge = firstEdge == 0
                ? rootEdge(for: patternKey)
                : edge(for: patternKey, startingAt: firstEdge)
            if let edge {
                descend(along: edge, matching: pattern, patternIndex: patternIndex, currentWord: &currentWord, result: &result)
            }
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
            let edge = edges.edge(at: edgeIndex)
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
    static func validateEdges(_ edges: UnsafeRawBufferPointer, alphabetCount: Int) throws(DAWGError) {
        let edgeCount = edges.count / DAWGFormat.edgeSize
        var previousEdgeKey: UInt16 = 0
        var isWithinNodeBlock = false

        for index in 0..<edgeCount {
            let edge = edges.edge(at: index)
            let edgeKey = UInt16(edge >> DAWGFormat.edgeKeyShift)
            guard
                Int(edge & DAWGFormat.edgeTargetMask) < edgeCount,
                Int(edgeKey) < alphabetCount,
                // Edge lookup relies on keys sorted ascending within a node block.
                !isWithinNodeBlock || edgeKey > previousEdgeKey
            else { throw DAWGError.invalidEdges }

            previousEdgeKey = edgeKey
            isWithinNodeBlock = edge & DAWGFormat.edgeLastFlag == 0
        }
        if !edges.isEmpty {
            guard edges.edge(at: edgeCount - 1) & DAWGFormat.edgeLastFlag != 0 else { throw DAWGError.invalidEdges }
        }
    }
}

private enum DAWGError: Error, Hashable {
    case resourceUnavailable
    case invalidHeader
    case invalidAlphabet
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

    /// Unchecked in optimized builds: trusted files and validated data never address edges outside the table.
    func edge(at index: Int) -> UInt32 {
        UInt32(littleEndian: baseAddress.unsafelyUnwrapped.loadUnaligned(fromByteOffset: index &* DAWGFormat.edgeSize, as: UInt32.self))
    }
}
