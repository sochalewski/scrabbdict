//
//  main.swift
//  DAWGWizard
//
//  Created by OpenAI Codex on 12.04.2026.
//

import Foundation

private enum DAWGFormat {
    static let magic: UInt32 = 0x47574453
    static let version: UInt32 = 1
    static let headerSize = 24
    static let nodeSize = 12
    static let edgeSize = 8
}

private let sourceFileURL = URL(fileURLWithPath: #filePath)
private let repositoryURL = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
private let defaultInputDirectory = repositoryURL.appendingPathComponent("DAWGWizard/Files")
private let defaultOutputDirectory = repositoryURL.appendingPathComponent("Scrabbdict/Files/DAWG")

private func usage() -> String {
    return """
    Usage: DAWGWizard [options] [language...]

    Generates .dawg files from text word lists.

    Options:
      --input-dir PATH   Directory with *.txt word lists.
                         Default: \(defaultInputDirectory.path)
      --output-dir PATH  Directory for generated *.dawg files.
                         Default: \(defaultOutputDirectory.path)
      --help             Show this help.

    Examples:
      DAWGWizard
      DAWGWizard pl_PL
      DAWGWizard --output-dir /tmp/dawg en_US_twl fr_ODS
    """
}

private func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs("\(message)\n", stderr)
    exit(code)
}

private func formatByteCount(_ count: Int) -> String {
    return ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
}

private struct Options {
    var inputDirectory = defaultInputDirectory
    var outputDirectory = defaultOutputDirectory
    var languages = [String]()
}

private func parseOptions(arguments: [String]) -> Options {
    var options = Options()
    var index = 1

    while index < arguments.count {
        switch arguments[index] {
        case "--input-dir":
            guard index + 1 < arguments.count else {
                fail("Missing value for --input-dir", code: 64)
            }
            options.inputDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            index += 2
        case "--output-dir":
            guard index + 1 < arguments.count else {
                fail("Missing value for --output-dir", code: 64)
            }
            options.outputDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
            index += 2
        case "--help", "-h":
            print(usage())
            exit(0)
        default:
            if arguments[index].hasPrefix("--") {
                fail("Unknown option: \(arguments[index])\n\(usage())", code: 64)
            }
            options.languages.append(arguments[index])
            index += 1
        }
    }

    return options
}

private func languages(in inputDirectory: URL, requestedLanguages: [String]) throws -> [String] {
    if !requestedLanguages.isEmpty {
        return requestedLanguages
    }

    return try FileManager.default.contentsOfDirectory(at: inputDirectory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "txt" }
        .map { $0.deletingPathExtension().lastPathComponent }
        .sorted()
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
        data.reserveCapacity(DAWGFormat.headerSize + compactDAWG.nodes.count * DAWGFormat.nodeSize + compactDAWG.edges.count * DAWGFormat.edgeSize)

        data.appendLittleEndianUInt32(DAWGFormat.magic)
        data.appendLittleEndianUInt32(DAWGFormat.version)
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

private let options = parseOptions(arguments: CommandLine.arguments)

guard FileManager.default.fileExists(atPath: options.inputDirectory.path) else {
    fail("Input directory does not exist: \(options.inputDirectory.path)", code: 66)
}

let languagesToGenerate: [String]
do {
    languagesToGenerate = try languages(in: options.inputDirectory, requestedLanguages: options.languages)
    guard !languagesToGenerate.isEmpty else {
        fail("No word lists found in \(options.inputDirectory.path).", code: 66)
    }

    try FileManager.default.createDirectory(at: options.outputDirectory, withIntermediateDirectories: true)
} catch {
    fail("Could not prepare DAWG generation: \(error)", code: 66)
}

for language in languagesToGenerate {
    autoreleasepool {
        let sourceURL = options.inputDirectory.appendingPathComponent(language).appendingPathExtension("txt")
        let outputURL = options.outputDirectory.appendingPathComponent(language).appendingPathExtension("dawg")

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            fail("Missing word list: \(sourceURL.path)", code: 66)
        }

        do {
            let words = try String(contentsOf: sourceURL, encoding: .utf8)
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .sorted()

            let data = DAWGBuilder(words: words).data()
            try data.write(to: outputURL, options: .atomic)
            print("Generated \(outputURL.path) (\(words.count) words, \(formatByteCount(data.count)))")
        } catch {
            fail("Failed to generate \(outputURL.path): \(error)")
        }
    }
}
