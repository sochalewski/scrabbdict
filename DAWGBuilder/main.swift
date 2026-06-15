//
//  DAWGBuilder
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

private let sourceFileURL = URL(fileURLWithPath: #filePath)
private let repositoryURL = sourceFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
private let defaultInputDirectory = repositoryURL.appendingPathComponent("DAWGBuilder/RAW")
private let defaultOutputDirectory = repositoryURL.appendingPathComponent("Scrabbdict/Resources/Dictionaries")

private func usage() -> String {
    """
    Usage: DAWGBuilder [options] [language...]

    Generates .dawg files from text word lists.

    Options:
      --input-dir PATH   Directory with *.zip or *.txt word lists.
                         Default: \(defaultInputDirectory.path)
      --output-dir PATH  Directory for generated *.dawg files.
                         Default: \(defaultOutputDirectory.path)
      --help             Show this help.

    Examples:
      DAWGBuilder
      DAWGBuilder pl_OSPS
      DAWGBuilder --output-dir /tmp/dawg en_US_nwl fr_ODS
    """
}

private func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs("\(message)\n", stderr)
    exit(code)
}

private func formatByteCount(_ count: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
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

    let sourceExtensions: Set = ["zip", "txt"]

    return try FileManager.default.contentsOfDirectory(at: inputDirectory, includingPropertiesForKeys: nil)
        .filter { sourceExtensions.contains($0.pathExtension) }
        .map { $0.deletingPathExtension().lastPathComponent }
        .uniqued()
        .sorted()
}

private func words(for language: String, in inputDirectory: URL) throws -> [String] {
    let archiveURL = inputDirectory.appendingPathComponent(language).appendingPathExtension("zip")
    if FileManager.default.fileExists(atPath: archiveURL.path) {
        return try words(fromZipFile: archiveURL, language: language)
    }

    let textURL = inputDirectory.appendingPathComponent(language).appendingPathExtension("txt")
    if FileManager.default.fileExists(atPath: textURL.path) {
        return try words(fromTextFile: textURL)
    }

    throw WordListError.missingWordList(language: language, inputDirectory: inputDirectory)
}

private func words(fromTextFile url: URL) throws -> [String] {
    try String(contentsOf: url, encoding: .utf8)
        .split(whereSeparator: \.isNewline)
        .map(String.init)
        .sorted()
}

private func words(fromZipFile url: URL, language: String) throws -> [String] {
    let entryName = "\(language).txt"
    let data = try runUnzip(arguments: ["-p", url.path, entryName])

    guard let contents = String(data: data, encoding: .utf8) else {
        throw WordListError.invalidUTF8(url)
    }

    return contents
        .split(whereSeparator: \.isNewline)
        .map(String.init)
        .sorted()
}

private func runUnzip(arguments: [String]) throws -> Data {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    let outputURL = temporaryDirectory.appendingPathComponent("word-list.txt")
    let errorURL = temporaryDirectory.appendingPathComponent("unzip.stderr")
    _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    _ = FileManager.default.createFile(atPath: errorURL.path, contents: nil)

    let outputHandle = try FileHandle(forWritingTo: outputURL)
    let errorHandle = try FileHandle(forWritingTo: errorURL)
    defer {
        try? outputHandle.close()
        try? errorHandle.close()
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = arguments
    process.standardOutput = outputHandle
    process.standardError = errorHandle

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        let error = try? String(contentsOf: errorURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        throw WordListError.unzipFailed(error ?? "unzip exited with status \(process.terminationStatus)")
    }

    return try Data(contentsOf: outputURL)
}

private enum WordListError: Error, CustomStringConvertible {
    case invalidUTF8(URL)
    case missingWordList(language: String, inputDirectory: URL)
    case unzipFailed(String)

    var description: String {
        switch self {
        case let .invalidUTF8(url):
            "Word list is not valid UTF-8: \(url.path)"
        case let .missingWordList(language, inputDirectory):
            "Missing word list for \(language). Expected \(language).zip or \(language).txt in \(inputDirectory.path)."
        case let .unzipFailed(message):
            "Could not read zipped word list: \(message)"
        }
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
        let outputURL = options.outputDirectory.appendingPathComponent(language).appendingPathExtension("dawg")

        do {
            let words = try words(for: language, in: options.inputDirectory)
            let data = try DAWGBuilder(words: words).data()
            try data.write(to: outputURL, options: .atomic)
            print("Generated \(outputURL.path) (\(words.count) words, \(formatByteCount(data.count)))")
        } catch {
            fail("Failed to generate \(outputURL.path): \(error)")
        }
    }
}
