//
//  ViewController.swift
//  DAWGWizard
//
//  Created by Piotr Sochalewski on 02.02.2018.
//  Copyright © 2018 Piotr Sochalewski. All rights reserved.
//

import Cocoa
import Foundation

extension Language {
    var url: URL {
        return Bundle.main.url(forResource: rawValue, withExtension: "txt")!
    }
}

final class ViewController: NSViewController {

    override func viewDidAppear() {
        super.viewDidAppear()

        writeDAWGFiles()
        NSWorkspace.shared.open(.homeDirectory)
    }

    private func writeDAWGFiles() {
        Language.allCases.forEach { language in
            autoreleasepool {
                let words = try! String(contentsOf: language.url, encoding: .utf8)
                    .split(separator: "\n")
                    .map(String.init)
                    .sorted()

                let data = DAWGBuilder(words: words).data()
                let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("\(language.rawValue).dawg")
                try? FileManager.default.removeItem(at: url)
                try! data.write(to: url, options: .atomic)
            }
        }
    }
}

private struct DAWGBuilder {
    private var nodes = [BuildNode()]
    private var uncheckedEdges = [UncheckedEdge]()
    private var registry = [Signature: Int]()
    private var previousWord = [UInt32]()
    private var wordCount = 0

    init(words: [String]) {
        words.forEach { insert($0) }
        minimizeUncheckedEdges(downTo: 0)
    }

    func data() -> Data {
        let compactDAWG = compact()
        var data = Data()
        data.reserveCapacity(24 + compactDAWG.nodes.count * 12 + compactDAWG.edges.count * 8)

        data.appendLittleEndianUInt32(0x47574453)
        data.appendLittleEndianUInt32(1)
        data.appendLittleEndianUInt32(UInt32(wordCount))
        data.appendLittleEndianUInt32(UInt32(compactDAWG.nodes.count))
        data.appendLittleEndianUInt32(UInt32(compactDAWG.edges.count))
        data.appendLittleEndianUInt32(0)

        compactDAWG.nodes.forEach { node in
            data.appendLittleEndianUInt32(node.firstEdge)
            data.appendLittleEndianUInt32(node.edgeCount)
            data.appendLittleEndianUInt32(node.isWord ? 1 : 0)
        }

        compactDAWG.edges.forEach { edge in
            data.appendLittleEndianUInt32(edge.key)
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

    private func compact() -> CompactDAWG {
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

        orderedNodes.forEach { buildIndex in
            let firstEdge = UInt32(compactEdges.count)

            nodes[buildIndex].edges.forEach { edge in
                compactEdges.append(CompactEdge(key: edge.key, target: remap[edge.target]!))
            }

            compactNodes.append(CompactNode(
                firstEdge: firstEdge,
                edgeCount: UInt32(nodes[buildIndex].edges.count),
                isWord: nodes[buildIndex].isWord
            ))
        }

        return CompactDAWG(nodes: compactNodes, edges: compactEdges)
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
    let edgeCount: UInt32
    let isWord: Bool
}

private struct CompactEdge {
    let key: UInt32
    let target: UInt32
}

private extension Data {
    mutating func appendLittleEndianUInt32(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
