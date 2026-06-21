//
//  DAWGBuilder
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

struct DAWGCommand {
    struct Options: Hashable {
        var inputDirectory: URL
        var outputDirectory: URL
        var languages: [String]
    }

    struct GenerationResult: Hashable {
        let outputURL: URL
        let wordCount: Int
        let byteCount: Int
    }

    enum CommandError: Error, CustomStringConvertible {
        case help(String)
        case missingOptionValue(String)
        case unknownOption(String)
        case inputDirectoryMissing(URL)
        case noWordListsFound(URL)
        case preparationFailed(any Error)
        case generationFailed(URL, any Error)

        var exitCode: Int32 {
            switch self {
            case .help: 0
            case .missingOptionValue, .unknownOption: 64
            case .inputDirectoryMissing, .noWordListsFound, .preparationFailed: 66
            case .generationFailed: 1
            }
        }

        var description: String {
            switch self {
            case let .help(usage):
                usage
            case let .missingOptionValue(option):
                "Missing value for \(option)"
            case let .unknownOption(option):
                "Unknown option: \(option)\n\(DAWGCommand.usage())"
            case let .inputDirectoryMissing(url):
                "Input directory does not exist: \(url.path)"
            case let .noWordListsFound(url):
                "No word lists found in \(url.path)."
            case let .preparationFailed(error):
                "Could not prepare DAWG generation: \(error)"
            case let .generationFailed(url, error):
                "Failed to generate \(url.path): \(error)"
            }
        }
    }

    static let defaultInputDirectory = repositoryURL.appendingPathComponent("DAWGBuilder/RAW")
    static let defaultOutputDirectory = repositoryURL.appendingPathComponent("Scrabbdict/Resources/Dictionaries")

    let unzip: ([String]) throws -> Data

    init(unzip: @escaping ([String]) throws -> Data = { _ in throw WordListError.unzipFailed("unzip is not configured") }) {
        self.unzip = unzip
    }

    static func usage() -> String {
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

    static func parseOptions(arguments: [String]) throws(CommandError) -> Options {
        var options = Options(
            inputDirectory: defaultInputDirectory,
            outputDirectory: defaultOutputDirectory,
            languages: []
        )
        var index = 1

        while index < arguments.count {
            switch arguments[index] {
            case "--input-dir":
                guard index + 1 < arguments.count else {
                    throw .missingOptionValue("--input-dir")
                }
                options.inputDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
                index += 2
            case "--output-dir":
                guard index + 1 < arguments.count else {
                    throw .missingOptionValue("--output-dir")
                }
                options.outputDirectory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
                index += 2
            case "--help", "-h":
                throw .help(usage())
            default:
                if arguments[index].hasPrefix("--") {
                    throw .unknownOption(arguments[index])
                }
                options.languages.append(arguments[index])
                index += 1
            }
        }

        return options
    }

    static func formatByteCount(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    func generate(arguments: [String]) throws(CommandError) -> [GenerationResult] {
        let options = try Self.parseOptions(arguments: arguments)

        guard FileManager.default.fileExists(atPath: options.inputDirectory.path) else {
            throw .inputDirectoryMissing(options.inputDirectory)
        }

        let languagesToGenerate: [String]
        do {
            languagesToGenerate = try languages(in: options.inputDirectory, requestedLanguages: options.languages)
            guard !languagesToGenerate.isEmpty else {
                throw CommandError.noWordListsFound(options.inputDirectory)
            }

            try FileManager.default.createDirectory(at: options.outputDirectory, withIntermediateDirectories: true)
        } catch let error as CommandError {
            throw error
        } catch {
            throw .preparationFailed(error)
        }

        var results = [GenerationResult]()
        results.reserveCapacity(languagesToGenerate.count)

        for language in languagesToGenerate {
            let outputURL = options.outputDirectory.appendingPathComponent(language).appendingPathExtension("dawg")

            do {
                let words = try words(for: language, in: options.inputDirectory)
                let data = try DAWGBuilder(words: words).data()
                try data.write(to: outputURL, options: .atomic)
                results.append(.init(outputURL: outputURL, wordCount: words.count, byteCount: data.count))
            } catch {
                throw .generationFailed(outputURL, error)
            }
        }

        return results
    }

    func languages(in inputDirectory: URL, requestedLanguages: [String]) throws -> [String] {
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

    func words(for language: String, in inputDirectory: URL) throws -> [String] {
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

    func words(fromTextFile url: URL) throws -> [String] {
        try String(contentsOf: url, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .sorted()
    }

    func words(fromZipFile url: URL, language: String) throws -> [String] {
        let entryName = "\(language).txt"
        let data = try unzip(["-p", url.path, entryName])

        guard let contents = String(data: data, encoding: .utf8) else {
            throw WordListError.invalidUTF8(url)
        }

        return contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .sorted()
    }
}

enum WordListError: Error, Hashable, CustomStringConvertible {
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

private let sourceFileURL = URL(fileURLWithPath: #filePath)
private let repositoryURL = sourceFileURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
