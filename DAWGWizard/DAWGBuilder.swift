//
//  DAWGWizard
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

struct DAWGBuilder {
    private var nodes = [BuildNode()]
    private var uncheckedEdges = [UncheckedEdge]()
    private var registry = [Signature: Int]()
    private var previousWord = [UInt32]()
    private var wordCount = 0

    init(words: [String]) {
        words.forEach { insert($0) }
        minimizeUncheckedEdges(downTo: 0)
    }

    func data() throws -> Data {
        let compactDAWG = try compact()
        let alphabet = try alphabet(for: compactDAWG)
        let alphabetByteCount = alphabet.count * MemoryLayout<UInt16>.size
        var data = Data()
        data.reserveCapacity(DAWGFormat.headerSize + alphabetByteCount + compactDAWG.nodes.count * DAWGFormat.nodeSize + compactDAWG.edges.count * DAWGFormat.edgeSize)

        data.appendLittleEndianUInt32(DAWGFormat.magic)
        data.appendLittleEndianUInt32(DAWGFormat.version)
        data.appendLittleEndianUInt32(UInt32(wordCount))
        data.appendLittleEndianUInt32(UInt32(compactDAWG.nodes.count))
        data.appendLittleEndianUInt32(UInt32(compactDAWG.edges.count))
        data.appendLittleEndianUInt32(UInt32(alphabet.count))

        alphabet.keys.forEach { data.appendLittleEndianUInt16($0) }

        for node in compactDAWG.nodes {
            guard node.edgeCount <= DAWGFormat.packedEdgeCountMask else {
                throw DAWGBuilderError.tooManyOutgoingEdgesForPackedCount
            }
            data.appendLittleEndianUInt32(node.firstEdge)
            data.appendLittleEndianUInt16(node.packedEdgeCount)
        }

        for edge in compactDAWG.edges {
            guard edge.target <= UInt32.max24 else {
                throw DAWGBuilderError.tooManyNodesForUInt24
            }
            data.appendUInt8(alphabet.indexByKey[edge.key]!)
            data.appendLittleEndianUInt24(edge.target)
        }

        return data
    }

    private mutating func insert(_ word: String) {
        let scalars = word.unicodeScalars.map(\.value)
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

    private func commonPrefixLength(_ lhs: [UInt32], _ rhs: [UInt32]) -> Int {
        var index = 0
        while index < lhs.count, index < rhs.count, lhs[index] == rhs[index] {
            index += 1
        }
        return index
    }

    private func compact() throws -> CompactDAWG {
        var remap = [Int: UInt32]()
        var orderedNodes = [Int]()
        var stack = [0]

        while let buildIndex = stack.popLast() {
            if remap[buildIndex] != nil {
                continue
            }

            remap[buildIndex] = UInt32(orderedNodes.count)
            orderedNodes.append(buildIndex)

            nodes[buildIndex].edges.reversed().forEach {
                stack.append($0.target)
            }
        }

        var compactNodes = [CompactNode]()
        compactNodes.reserveCapacity(orderedNodes.count)

        var compactEdges = [CompactEdge]()

        for buildIndex in orderedNodes {
            let firstEdge = UInt32(compactEdges.count)
            guard nodes[buildIndex].edges.count <= Int(UInt16.max) else {
                throw DAWGBuilderError.tooManyOutgoingEdgesForUInt16
            }

            for edge in nodes[buildIndex].edges {
                guard let key = UInt16(exactly: edge.key) else {
                    throw DAWGBuilderError.unsupportedScalar(edge.key)
                }
                compactEdges.append(CompactEdge(key: key, target: remap[edge.target]!))
            }

            compactNodes.append(CompactNode(
                firstEdge: firstEdge,
                edgeCount: UInt16(nodes[buildIndex].edges.count),
                isWord: nodes[buildIndex].isWord
            ))
        }

        return CompactDAWG(nodes: compactNodes, edges: compactEdges)
    }

    private func alphabet(for compactDAWG: CompactDAWG) throws -> Alphabet {
        let keys = compactDAWG.edges.map(\.key).uniqued().sorted()
        guard keys.count <= Int(UInt8.max) + 1 else {
            throw DAWGBuilderError.tooManyAlphabetScalarsForUInt8(keys.count)
        }

        return Alphabet(keys: keys)
    }
}

enum DAWGBuilderError: Error, CustomStringConvertible {
    case unsupportedScalar(UInt32)
    case tooManyOutgoingEdgesForUInt16
    case tooManyNodesForUInt24
    case tooManyAlphabetScalarsForUInt8(Int)
    case tooManyOutgoingEdgesForPackedCount

    var description: String {
        switch self {
        case let .unsupportedScalar(scalar):
            "DAWG supports Unicode scalars up to \(UInt16.max); unsupported scalar: \(scalar)."
        case .tooManyOutgoingEdgesForUInt16:
            "DAWG supports at most \(UInt16.max) outgoing edges per node."
        case .tooManyNodesForUInt24:
            "DAWG supports at most \(UInt32.max24 + 1) nodes."
        case let .tooManyAlphabetScalarsForUInt8(count):
            "DAWG supports at most \(Int(UInt8.max) + 1) distinct scalars; found \(count)."
        case .tooManyOutgoingEdgesForPackedCount:
            "DAWG supports at most \(DAWGFormat.packedEdgeCountMask) outgoing edges per node."
        }
    }
}

private final class BuildNode {
    var isWord = false
    var edges = [BuildEdge]()
}

private struct BuildEdge: Hashable {
    let key: UInt32
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

private struct CompactDAWG {
    let nodes: [CompactNode]
    let edges: [CompactEdge]
}

private struct CompactNode {
    let firstEdge: UInt32
    let edgeCount: UInt16
    let isWord: Bool

    var packedEdgeCount: UInt16 {
        edgeCount | (isWord ? DAWGFormat.wordFlag : 0)
    }
}

private struct CompactEdge {
    let key: UInt16
    let target: UInt32
}

private struct Alphabet {
    let keys: [UInt16]
    let indexByKey: [UInt16: UInt8]

    var count: Int {
        keys.count
    }

    init(keys: [UInt16]) {
        self.keys = keys
        self.indexByKey = Dictionary(uniqueKeysWithValues: keys.enumerated().map { index, key in
            (key, UInt8(index))
        })
    }
}

private extension Data {
    mutating func appendUInt8(_ value: UInt8) {
        append(value)
    }

    mutating func appendLittleEndianUInt16(_ value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndianUInt24(_ value: UInt32) {
        appendUInt8(UInt8(truncatingIfNeeded: value))
        appendUInt8(UInt8(truncatingIfNeeded: value >> 8))
        appendUInt8(UInt8(truncatingIfNeeded: value >> 16))
    }

    mutating func appendLittleEndianUInt32(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension UInt32 {
    static let max24: Self = 0x00ff_ffff
}
