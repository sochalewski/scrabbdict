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
    private let keyByScalar: [UInt16: UInt16]
    private let nodeFirstEdges: [UInt32]
    private let nodeEdgeCounts: [UInt16]
    private let wordNodes: BitSet
    private let edges: [DAWGEdge]

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
        try self.init(data: data)
    }

    init(data: Data) throws {
        guard data.count >= DAWGFormat.headerSize else { throw DAWGError.invalidHeader }

        let magic = data.readLittleEndianUInt32(at: 0)
        let version = data.readLittleEndianUInt32(at: 4)
        let wordCount = data.readLittleEndianUInt32(at: 8)
        let nodeCount = data.readLittleEndianUInt32(at: 12)
        let edgeCount = data.readLittleEndianUInt32(at: 16)
        let alphabetCount = data.readLittleEndianUInt32(at: 20)

        guard magic == DAWGFormat.magic, version == DAWGFormat.version else { throw DAWGError.invalidHeader }

        let alphabetOffset = DAWGFormat.headerSize
        let nodesOffset = alphabetOffset + Int(alphabetCount) * MemoryLayout<UInt16>.size
        let edgesOffset = nodesOffset + Int(nodeCount) * DAWGFormat.nodeSize
        let expectedSize = edgesOffset + Int(edgeCount) * DAWGFormat.edgeSize
        guard data.count == expectedSize else { throw DAWGError.invalidSize }

        let alphabet = (0..<Int(alphabetCount)).map { index in
            data.readLittleEndianUInt16(at: alphabetOffset + index * MemoryLayout<UInt16>.size)
        }
        let keyByScalar = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { index, scalar in
            (scalar, UInt16(index))
        })

        var nodeFirstEdges = [UInt32]()
        nodeFirstEdges.reserveCapacity(Int(nodeCount))

        var nodeEdgeCounts = [UInt16]()
        nodeEdgeCounts.reserveCapacity(Int(nodeCount))

        var wordNodes = BitSet(capacity: Int(nodeCount))

        for index in 0..<Int(nodeCount) {
            let offset = nodesOffset + index * DAWGFormat.nodeSize
            nodeFirstEdges.append(data.readLittleEndianUInt32(at: offset))
            let packedEdgeCount = data.readLittleEndianUInt16(at: offset + 4)
            nodeEdgeCounts.append(packedEdgeCount & ~DAWGFormat.wordFlag)
            if packedEdgeCount & DAWGFormat.wordFlag != 0 {
                wordNodes.insert(index)
            }
        }

        var edges = [DAWGEdge]()
        edges.reserveCapacity(Int(edgeCount))

        for index in 0..<Int(edgeCount) {
            let offset = edgesOffset + index * DAWGFormat.edgeSize
            edges.append(
                DAWGEdge(
                    key: UInt16(data[offset]),
                    target: data.readLittleEndianUInt24(at: offset + 1)
                )
            )
        }

        self.count = Int(wordCount)
        self.alphabet = alphabet
        self.keyByScalar = keyByScalar
        self.nodeFirstEdges = nodeFirstEdges
        self.nodeEdgeCounts = nodeEdgeCounts
        self.wordNodes = wordNodes
        self.edges = edges
    }

    func contains(_ word: String) -> Bool {
        guard let nodeIndex = nodeIndex(for: word) else {
            return false
        }

        return wordNodes.contains(Int(nodeIndex))
    }

    func words(from letters: String, minLength: Int = 2) -> [String] {
        guard !letters.isEmpty else { return [] }

        var availableLetters = LetterCounter(letters, keyForScalar: key)
        guard !availableLetters.isEmpty else { return [] }

        var currentWord = [UInt16]()
        currentWord.reserveCapacity(letters.unicodeScalars.count)

        var result = [String]()
        collectWords(from: 0, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
        return result
    }

    func words(matching pattern: String) -> [String] {
        guard !pattern.isEmpty else { return [] }

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
        collectWords(matching: patternKeys, patternIndex: 0, nodeIndex: 0, currentWord: &currentWord, result: &result)
        return result
    }

    private func scalar(for key: UInt16) -> UInt16 {
        alphabet[Int(key)]
    }

    private func key(for scalar: UInt16) -> UInt16? {
        keyByScalar[scalar]
    }

    private func string(from keys: [UInt16]) -> String {
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(keys.count)

        for key in keys {
            scalars.append(UnicodeScalar(scalar(for: key))!)
        }

        return String(scalars)
    }

    private func nodeIndex(for word: String) -> UInt32? {
        var nodeIndex: UInt32 = 0

        for scalar in word.unicodeScalars {
            guard
                let scalarKey = UInt16(exactly: scalar.value),
                let key = key(for: scalarKey),
                let nextNodeIndex = targetNodeIndex(for: key, from: nodeIndex)
            else {
                return nil
            }
            nodeIndex = nextNodeIndex
        }

        return nodeIndex
    }

    private func collectWords(
        from nodeIndex: UInt32,
        using availableLetters: inout LetterCounter,
        minLength: Int,
        currentWord: inout [UInt16],
        result: inout [String]
    ) {
        let nodeIndex = Int(nodeIndex)

        if wordNodes.contains(nodeIndex), currentWord.count >= minLength {
            result.append(string(from: currentWord))
        }

        let firstEdge = Int(nodeFirstEdges[nodeIndex])
        let lastEdge = firstEdge + Int(nodeEdgeCounts[nodeIndex])

        for edgeIndex in firstEdge..<lastEdge {
            let edge = edges[edgeIndex]
            guard let letterIndex = availableLetters.consume(edge.key) else { continue }

            currentWord.append(edge.key)
            collectWords(from: edge.target, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
            currentWord.removeLast()

            availableLetters.restore(at: letterIndex)
        }
    }

    private func collectWords(
        matching pattern: [UInt16],
        patternIndex: Int,
        nodeIndex: UInt32,
        currentWord: inout [UInt16],
        result: inout [String]
    ) {
        guard patternIndex < pattern.count else {
            if wordNodes.contains(Int(nodeIndex)) {
                result.append(string(from: currentWord))
            }
            return
        }

        let key = pattern[patternIndex]

        if key == Self.wildcardKey {
            let nodeIndex = Int(nodeIndex)
            let firstEdge = Int(nodeFirstEdges[nodeIndex])
            let lastEdge = firstEdge + Int(nodeEdgeCounts[nodeIndex])

            for edgeIndex in firstEdge..<lastEdge {
                let edge = edges[edgeIndex]
                currentWord.append(edge.key)
                collectWords(matching: pattern, patternIndex: patternIndex + 1, nodeIndex: edge.target, currentWord: &currentWord, result: &result)
                currentWord.removeLast()
            }
        } else if let target = targetNodeIndex(for: key, from: nodeIndex) {
            currentWord.append(key)
            collectWords(matching: pattern, patternIndex: patternIndex + 1, nodeIndex: target, currentWord: &currentWord, result: &result)
            currentWord.removeLast()
        }
    }

    private func targetNodeIndex(for key: UInt16, from nodeIndex: UInt32) -> UInt32? {
        let nodeIndex = Int(nodeIndex)
        let firstEdge = Int(nodeFirstEdges[nodeIndex])
        let lastEdge = firstEdge + Int(nodeEdgeCounts[nodeIndex])

        for edgeIndex in firstEdge..<lastEdge {
            let edge = edges[edgeIndex]
            if edge.key == key {
                return edge.target
            }
        }

        return nil
    }
}

private enum DAWGError: Error {
    case invalidHeader
    case invalidSize
}

private struct DAWGEdge: Sendable {
    let key: UInt16
    let target: UInt32
}

private struct BitSet: Sendable {
    private var words: [UInt64]

    init(capacity: Int) {
        self.words = Array(repeating: 0, count: (capacity + 63) / 64)
    }

    mutating func insert(_ index: Int) {
        words[index / 64] |= UInt64(1) << UInt64(index % 64)
    }

    func contains(_ index: Int) -> Bool {
        words[index / 64] & (UInt64(1) << UInt64(index % 64)) != 0
    }
}

private struct LetterCounter: Sendable {
    private var keys = [UInt16]()
    private var counts = [Int]()

    var isEmpty: Bool {
        keys.isEmpty
    }

    init(_ letters: String, keyForScalar: (UInt16) -> UInt16?) {
        keys.reserveCapacity(letters.unicodeScalars.count)
        counts.reserveCapacity(letters.unicodeScalars.count)

        for scalar in letters.unicodeScalars {
            guard
                let scalarKey = UInt16(exactly: scalar.value),
                let key = keyForScalar(scalarKey)
            else { continue }

            if let index = keys.firstIndex(of: key) {
                counts[index] += 1
            } else {
                keys.append(key)
                counts.append(1)
            }
        }
    }

    mutating func consume(_ key: UInt16) -> Int? {
        for index in keys.indices where keys[index] == key && counts[index] > 0 {
            counts[index] -= 1
            return index
        }

        return nil
    }

    mutating func restore(at index: Int) {
        counts[index] += 1
    }
}

private extension Data {
    func readLittleEndianUInt16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func readLittleEndianUInt24(at offset: Int) -> UInt32 {
        UInt32(self[offset]) | UInt32(self[offset + 1]) << 8 | UInt32(self[offset + 2]) << 16
    }

    func readLittleEndianUInt32(at offset: Int) -> UInt32 {
        UInt32(self[offset]) | UInt32(self[offset + 1]) << 8 | UInt32(self[offset + 2]) << 16 | UInt32(self[offset + 3]) << 24
    }
}
