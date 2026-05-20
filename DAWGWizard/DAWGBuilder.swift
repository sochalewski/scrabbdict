//
//  DAWGWizard
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

enum DAWGFormat {
    static let magic: UInt32 = 0x47574453
    static let version: UInt32 = 2
    static let headerSize = 24
    static let nodeSize = 8
    static let edgeSize = 6
}

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
        var data = Data()
        data.reserveCapacity(DAWGFormat.headerSize + compactDAWG.nodes.count * DAWGFormat.nodeSize + compactDAWG.edges.count * DAWGFormat.edgeSize)

        data.appendLittleEndianUInt32(DAWGFormat.magic)
        data.appendLittleEndianUInt32(DAWGFormat.version)
        data.appendLittleEndianUInt32(UInt32(wordCount))
        data.appendLittleEndianUInt32(UInt32(compactDAWG.nodes.count))
        data.appendLittleEndianUInt32(UInt32(compactDAWG.edges.count))
        data.appendLittleEndianUInt32(0)

        compactDAWG.nodes.forEach { node in
            data.appendLittleEndianUInt32(node.firstEdge)
            data.appendLittleEndianUInt16(node.edgeCount)
            data.appendLittleEndianUInt16(node.isWord ? 1 : 0)
        }

        compactDAWG.edges.forEach { edge in
            data.appendLittleEndianUInt16(edge.key)
            data.appendLittleEndianUInt32(edge.target)
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
                throw DAWGBuilderError.tooManyOutgoingEdges
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
}

enum DAWGBuilderError: Error, CustomStringConvertible {
    case tooManyOutgoingEdges
    case unsupportedScalar(UInt32)

    var description: String {
        switch self {
        case .tooManyOutgoingEdges:
            "DAWG v2 supports at most \(UInt16.max) outgoing edges per node."
        case let .unsupportedScalar(scalar):
            "DAWG v2 supports Unicode scalars up to \(UInt16.max); unsupported scalar: \(scalar)."
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
}

private struct CompactEdge {
    let key: UInt16
    let target: UInt32
}

private extension Data {
    mutating func appendLittleEndianUInt16(_ value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndianUInt32(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
