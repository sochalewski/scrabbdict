//
//  DAWGWizard
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

private let sourceFileURL = URL(fileURLWithPath: #filePath)
private let repositoryURL = sourceFileURL.deletingLastPathComponent().deletingLastPathComponent()
private let defaultInputDirectory = repositoryURL.appendingPathComponent("DAWGWizard/Files")
private let defaultOutputDirectory = repositoryURL.appendingPathComponent("Scrabbdict/Files/DAWG")

private func usage() -> String {
    """
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

    return try FileManager.default.contentsOfDirectory(at: inputDirectory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "txt" }
        .map { $0.deletingPathExtension().lastPathComponent }
        .sorted()
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

            let data = try DAWGBuilder(words: words).data()
            try data.write(to: outputURL, options: .atomic)
            print("Generated \(outputURL.path) (\(words.count) words, \(formatByteCount(data.count)))")
        } catch {
            fail("Failed to generate \(outputURL.path): \(error)")
        }
    }
}
