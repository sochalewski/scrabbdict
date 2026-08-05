//
//  DAWGBuilder
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

struct DAWGBuilder {
    private let alphabet: Alphabet
    private var nodes = [BuildNode()]
    private var uncheckedEdges = [UncheckedEdge]()
    private var registry = [Signature: Int]()
    private var previousWord = [UInt16]()
    private var wordCount = 0

    init(words: [String], locale: Locale) throws {
        let alphabet = try Alphabet(words: words, locale: locale)
        self.alphabet = alphabet

        if alphabet.areWordsOrdered(words) {
            words.forEach { insert($0) }
        } else {
            words.sorted { alphabet.precedes($0, $1) }.forEach { insert($0) }
        }
        minimizeUncheckedEdges(downTo: 0)
    }

    func data() throws -> Data {
        let compactEdges = compact()
        let alphabetByteCount = alphabet.count * MemoryLayout<UInt16>.size
        var data = Data()
        data.reserveCapacity(DAWGFormat.headerSize + alphabetByteCount + compactEdges.count * DAWGFormat.edgeSize)

        data.appendLittleEndianUInt32(DAWGFormat.magic)
        data.appendLittleEndianUInt32(DAWGFormat.version)
        data.appendLittleEndianUInt32(UInt32(wordCount))
        data.appendLittleEndianUInt32(UInt32(compactEdges.count))
        data.appendLittleEndianUInt32(UInt32(alphabet.count))

        alphabet.keys.forEach { data.appendLittleEndianUInt16($0) }

        for edge in compactEdges {
            guard edge.target <= DAWGFormat.edgeTargetMask else {
                throw DAWGBuilderError.tooManyEdgesForPackedTarget
            }

            var packed = edge.target
            if edge.isWord {
                packed |= DAWGFormat.edgeWordFlag
            }
            if edge.isLast {
                packed |= DAWGFormat.edgeLastFlag
            }
            packed |= UInt32(alphabet.index(for: edge.key)) << DAWGFormat.edgeKeyShift
            data.appendLittleEndianUInt32(packed)
        }

        return data
    }

    private mutating func insert(_ word: String) {
        let scalars = word.unicodeScalars.map { UInt16($0.value) }
        guard scalars != previousWord else { return }

        let commonPrefixCount = commonPrefixLength(scalars, previousWord)
        minimizeUncheckedEdges(downTo: commonPrefixCount)

        var parent = commonPrefixCount == 0 ? 0 : uncheckedEdges[commonPrefixCount - 1].child

        for scalar in scalars.dropFirst(commonPrefixCount) {
            let child = nodes.count
            nodes.append(BuildNode())

            let edgeIndex = nodes[parent].edges.count
            nodes[parent].edges.append(BuildEdge(key: scalar, target: child))
            uncheckedEdges.append(UncheckedEdge(parent: parent, edgeIndex: edgeIndex, child: child))
            parent = child
        }

        if !nodes[parent].isWord {
            nodes[parent].isWord = true
            wordCount += 1
        }

        previousWord = scalars
    }

    private mutating func minimizeUncheckedEdges(downTo prefixCount: Int) {
        while uncheckedEdges.count > prefixCount {
            let uncheckedEdge = uncheckedEdges.removeLast()
            let signature = Signature(isWord: nodes[uncheckedEdge.child].isWord, edges: nodes[uncheckedEdge.child].edges)

            if let equivalentNode = registry[signature] {
                nodes[uncheckedEdge.parent].edges[uncheckedEdge.edgeIndex].target = equivalentNode
            } else {
                registry[signature] = uncheckedEdge.child
            }
        }
    }

    private func commonPrefixLength(_ lhs: [UInt16], _ rhs: [UInt16]) -> Int {
        var index = 0
        while index < lhs.count, index < rhs.count, lhs[index] == rhs[index] {
            index += 1
        }
        return index
    }

    /// Flattens the minimized graph into a single edge array.
    ///
    /// Nodes with outgoing edges are visited in depth-first preorder starting
    /// from the root, so the root's edges begin at index `0`. Each visited node
    /// is assigned the index of its first edge; nodes without outgoing edges
    /// are encoded as the null target `0`.
    private func compact() -> [CompactEdge] {
        var firstEdgeByNode = [Int: UInt32]()
        var orderedNodes = [Int]()
        var nextFirstEdge: UInt32 = 0
        var stack = [0]

        while let buildIndex = stack.popLast() {
            let edges = nodes[buildIndex].edges
            guard !edges.isEmpty, firstEdgeByNode[buildIndex] == nil else { continue }

            firstEdgeByNode[buildIndex] = nextFirstEdge
            nextFirstEdge += UInt32(edges.count)
            orderedNodes.append(buildIndex)

            edges.reversed().forEach {
                stack.append($0.target)
            }
        }

        var compactEdges = [CompactEdge]()
        compactEdges.reserveCapacity(Int(nextFirstEdge))

        for buildIndex in orderedNodes {
            let edges = nodes[buildIndex].edges

            for (offset, edge) in edges.enumerated() {
                compactEdges.append(CompactEdge(
                    key: edge.key,
                    target: firstEdgeByNode[edge.target] ?? 0,
                    isWord: nodes[edge.target].isWord,
                    isLast: offset == edges.count - 1
                ))
            }
        }

        return compactEdges
    }
}

enum DAWGBuilderError: Error, Hashable, CustomStringConvertible {
    case unsupportedScalar(UInt32)
    case tooManyEdgesForPackedTarget
    case tooManyAlphabetScalarsForUInt8(Int)

    var description: String {
        switch self {
        case let .unsupportedScalar(scalar):
            "DAWG supports Unicode scalars up to \(UInt16.max); unsupported scalar: \(scalar)."
        case .tooManyEdgesForPackedTarget:
            "DAWG supports at most \(DAWGFormat.edgeTargetMask + 1) edges."
        case let .tooManyAlphabetScalarsForUInt8(count):
            "DAWG supports at most \(Int(UInt8.max) + 1) distinct scalars; found \(count)."
        }
    }
}

private final class BuildNode {
    var isWord = false
    var edges = [BuildEdge]()
}

private struct BuildEdge: Hashable {
    let key: UInt16
    var target: Int
}

private struct Signature: Hashable {
    let isWord: Bool
    let edges: [BuildEdge]
}

private struct UncheckedEdge {
    let parent: Int
    let edgeIndex: Int
    let child: Int
}

private struct CompactEdge {
    let key: UInt16
    let target: UInt32
    let isWord: Bool
    let isLast: Bool
}

private struct Alphabet {
    let keys: [UInt16]

    private let indexByScalar: [UInt16]

    var count: Int {
        keys.count
    }

    init(words: [String], locale: Locale) throws {
        var distinctKeys = Set<UInt16>()
        for word in words {
            for scalar in word.unicodeScalars {
                guard let key = UInt16(exactly: scalar.value) else {
                    throw DAWGBuilderError.unsupportedScalar(scalar.value)
                }
                distinctKeys.insert(key)
            }
        }

        let keys = distinctKeys.sorted { lhs, rhs in
            let comparison = String(UnicodeScalar(UInt32(lhs))!).compare(
                String(UnicodeScalar(UInt32(rhs))!),
                options: [],
                range: nil,
                locale: locale
            )
            return comparison == .orderedSame ? lhs < rhs : comparison == .orderedAscending
        }
        guard keys.count <= Int(UInt8.max) + 1 else {
            throw DAWGBuilderError.tooManyAlphabetScalarsForUInt8(keys.count)
        }

        self.keys = keys
        var indexByScalar = [UInt16](repeating: .max, count: Int(keys.max() ?? 0) + 1)
        for (index, key) in keys.enumerated() {
            indexByScalar[Int(key)] = UInt16(index)
        }
        self.indexByScalar = indexByScalar
    }

    func index(for key: UInt16) -> UInt8 {
        UInt8(indexByScalar[Int(key)])
    }

    func areWordsOrdered(_ words: [String]) -> Bool {
        guard var previousWord = words.first else { return true }

        for word in words.dropFirst() {
            if precedes(word, previousWord) {
                return false
            }
            previousWord = word
        }
        return true
    }

    func precedes(_ lhs: String, _ rhs: String) -> Bool {
        var lhsScalars = lhs.unicodeScalars.makeIterator()
        var rhsScalars = rhs.unicodeScalars.makeIterator()

        while let lhsScalar = lhsScalars.next() {
            guard let rhsScalar = rhsScalars.next() else { return false }

            let lhsIndex = indexByScalar[Int(lhsScalar.value)]
            let rhsIndex = indexByScalar[Int(rhsScalar.value)]
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }
        }

        return rhsScalars.next() != nil
    }
}
