//
//  DAWG.swift
//  Scrabbdict
//
//  Created by OpenAI Codex on 12.04.2026.
//

import Foundation

final class DAWG {
    private static let magic: UInt32 = 0x47574453
    private static let version: UInt32 = 1
    private static let headerSize = 24
    private static let nodeSize = 12
    private static let edgeSize = 8

    private static let wildcardKey = UnicodeScalar("?").value

    private let nodes: [DAWGNode]
    private let edges: [DAWGEdge]

    let count: Int

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
        guard data.count >= Self.headerSize else { throw DAWGError.invalidHeader }

        let magic = data.readLittleEndianUInt32(at: 0)
        let version = data.readLittleEndianUInt32(at: 4)
        let wordCount = data.readLittleEndianUInt32(at: 8)
        let nodeCount = data.readLittleEndianUInt32(at: 12)
        let edgeCount = data.readLittleEndianUInt32(at: 16)

        guard magic == Self.magic, version == Self.version else { throw DAWGError.invalidHeader }

        let nodesOffset = Self.headerSize
        let edgesOffset = nodesOffset + Int(nodeCount) * Self.nodeSize
        let expectedSize = edgesOffset + Int(edgeCount) * Self.edgeSize
        guard data.count == expectedSize else { throw DAWGError.invalidSize }

        var nodes = [DAWGNode]()
        nodes.reserveCapacity(Int(nodeCount))

        for index in 0..<Int(nodeCount) {
            let offset = nodesOffset + index * Self.nodeSize
            nodes.append(DAWGNode(
                firstEdge: data.readLittleEndianUInt32(at: offset),
                edgeCount: data.readLittleEndianUInt32(at: offset + 4),
                isWord: data.readLittleEndianUInt32(at: offset + 8) != 0
            ))
        }

        var edges = [DAWGEdge]()
        edges.reserveCapacity(Int(edgeCount))

        for index in 0..<Int(edgeCount) {
            let offset = edgesOffset + index * Self.edgeSize
            edges.append(DAWGEdge(
                key: data.readLittleEndianUInt32(at: offset),
                target: data.readLittleEndianUInt32(at: offset + 4)
            ))
        }

        self.count = Int(wordCount)
        self.nodes = nodes
        self.edges = edges
    }

    func contains(_ word: String) -> Bool {
        guard let nodeIndex = nodeIndex(for: word) else {
            return false
        }

        return nodes[Int(nodeIndex)].isWord
    }

    func words(from letters: String, minLength: Int = 2) -> [String] {
        guard !letters.isEmpty else { return [] }

        var availableLetters = [UInt32: Int]()
        letters.unicodeScalars.forEach { availableLetters[$0.value, default: 0] += 1 }

        var currentWord = [Character]()
        var result = [String]()
        collectWords(from: 0, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
        return result
    }

    func words(matching pattern: String) -> [String] {
        guard !pattern.isEmpty else { return [] }

        let patternKeys = pattern.unicodeScalars.map(\.value)
        var currentWord = [Character]()
        var result = [String]()
        collectWords(matching: patternKeys, patternIndex: 0, nodeIndex: 0, currentWord: &currentWord, result: &result)
        return result
    }

    private func nodeIndex(for word: String) -> UInt32? {
        var nodeIndex: UInt32 = 0

        for scalar in word.unicodeScalars {
            guard let nextNodeIndex = targetNodeIndex(for: scalar.value, from: nodeIndex) else {
                return nil
            }
            nodeIndex = nextNodeIndex
        }

        return nodeIndex
    }

    private func collectWords(
        from nodeIndex: UInt32,
        using availableLetters: inout [UInt32: Int],
        minLength: Int,
        currentWord: inout [Character],
        result: inout [String]
    ) {
        let node = nodes[Int(nodeIndex)]

        if node.isWord, currentWord.count >= minLength {
            result.append(String(currentWord))
        }

        let firstEdge = Int(node.firstEdge)
        let lastEdge = firstEdge + Int(node.edgeCount)

        for edgeIndex in firstEdge..<lastEdge {
            let edge = edges[edgeIndex]
            guard let remainingCount = availableLetters[edge.key], remainingCount > 0 else { continue }

            availableLetters[edge.key] = remainingCount - 1
            currentWord.append(Character(UnicodeScalar(edge.key)!))
            collectWords(from: edge.target, using: &availableLetters, minLength: minLength, currentWord: &currentWord, result: &result)
            currentWord.removeLast()

            availableLetters[edge.key] = remainingCount
        }
    }

    private func collectWords(
        matching pattern: [UInt32],
        patternIndex: Int,
        nodeIndex: UInt32,
        currentWord: inout [Character],
        result: inout [String]
    ) {
        guard patternIndex < pattern.count else {
            if nodes[Int(nodeIndex)].isWord {
                result.append(String(currentWord))
            }
            return
        }

        let key = pattern[patternIndex]

        if key == Self.wildcardKey {
            let node = nodes[Int(nodeIndex)]
            let firstEdge = Int(node.firstEdge)
            let lastEdge = firstEdge + Int(node.edgeCount)

            for edgeIndex in firstEdge..<lastEdge {
                let edge = edges[edgeIndex]
                currentWord.append(Character(UnicodeScalar(edge.key)!))
                collectWords(matching: pattern, patternIndex: patternIndex + 1, nodeIndex: edge.target, currentWord: &currentWord, result: &result)
                currentWord.removeLast()
            }
        } else if let target = targetNodeIndex(for: key, from: nodeIndex) {
            currentWord.append(Character(UnicodeScalar(key)!))
            collectWords(matching: pattern, patternIndex: patternIndex + 1, nodeIndex: target, currentWord: &currentWord, result: &result)
            currentWord.removeLast()
        }
    }

    private func targetNodeIndex(for key: UInt32, from nodeIndex: UInt32) -> UInt32? {
        let node = nodes[Int(nodeIndex)]
        let firstEdge = Int(node.firstEdge)
        let lastEdge = firstEdge + Int(node.edgeCount)

        for edgeIndex in firstEdge..<lastEdge where edges[edgeIndex].key == key {
            return edges[edgeIndex].target
        }

        return nil
    }
}

private enum DAWGError: Error {
    case invalidHeader
    case invalidSize
}

private struct DAWGNode {
    let firstEdge: UInt32
    let edgeCount: UInt32
    let isWord: Bool
}

private struct DAWGEdge {
    let key: UInt32
    let target: UInt32
}

private extension Data {
    func readLittleEndianUInt32(at offset: Int) -> UInt32 {
        return UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }
}
