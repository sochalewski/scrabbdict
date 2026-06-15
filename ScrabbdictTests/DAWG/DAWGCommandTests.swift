//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import XCTest
@testable import Scrabbdict

final class DAWGCommandTests: XCTestCase {
    func testParseOptionsUsesDefaultsAndCollectsLanguages() throws {
        let options = try DAWGCommand.parseOptions(arguments: ["DAWGBuilder", "en_US_nwl", "fr_ODS"])

        XCTAssertEqual(options.inputDirectory, DAWGCommand.defaultInputDirectory)
        XCTAssertEqual(options.outputDirectory, DAWGCommand.defaultOutputDirectory)
        XCTAssertEqual(options.languages, ["en_US_nwl", "fr_ODS"])
    }

    func testParseOptionsSupportsInputAndOutputDirectories() throws {
        let inputDirectory = temporaryURL("input")
        let outputDirectory = temporaryURL("output")

        let options = try DAWGCommand.parseOptions(arguments: [
            "DAWGBuilder",
            "--input-dir", inputDirectory.path,
            "--output-dir", outputDirectory.path,
            "pl_OSPS"
        ])

        XCTAssertEqual(options.inputDirectory.standardizedFileURL, inputDirectory.standardizedFileURL)
        XCTAssertEqual(options.outputDirectory.standardizedFileURL, outputDirectory.standardizedFileURL)
        XCTAssertEqual(options.languages, ["pl_OSPS"])
    }

    func testParseOptionsRejectsMissingOptionValue() {
        XCTAssertThrowsError(try DAWGCommand.parseOptions(arguments: ["DAWGBuilder", "--input-dir"])) { error in
            guard case .missingOptionValue("--input-dir") = error as? DAWGCommand.CommandError else {
                XCTFail()
                return
            }
        }
        XCTAssertThrowsError(try DAWGCommand.parseOptions(arguments: ["DAWGBuilder", "--output-dir"])) { error in
            guard case .missingOptionValue("--output-dir") = error as? DAWGCommand.CommandError else {
                XCTFail()
                return
            }
        }
    }

    func testParseOptionsRejectsUnknownOption() {
        XCTAssertThrowsError(try DAWGCommand.parseOptions(arguments: ["DAWGBuilder", "--unknown"])) { error in
            guard case .unknownOption("--unknown") = error as? DAWGCommand.CommandError else {
                XCTFail()
                return
            }
        }
    }

    func testLanguagesDiscoversTextAndZipWordListsWithoutDuplicates() throws {
        try withTemporaryDirectory { inputDirectory in
            try Data().write(to: inputDirectory.appendingPathComponent("pl_OSPS.txt"))
            try Data().write(to: inputDirectory.appendingPathComponent("en_US_nwl.zip"))
            try Data().write(to: inputDirectory.appendingPathComponent("en_US_nwl.txt"))
            try Data().write(to: inputDirectory.appendingPathComponent("README.md"))

            let languages = try DAWGCommand().languages(in: inputDirectory, requestedLanguages: [])

            XCTAssertEqual(languages, ["en_US_nwl", "pl_OSPS"])
        }
    }

    func testLanguagesReturnsRequestedLanguagesWithoutReadingDirectory() throws {
        let missingDirectory = temporaryURL("missing")

        let languages = try DAWGCommand().languages(in: missingDirectory, requestedLanguages: ["fr_ODS"])

        XCTAssertEqual(languages, ["fr_ODS"])
    }

    func testWordsReadsAndSortsTextWordList() throws {
        try withTemporaryDirectory { inputDirectory in
            let textURL = inputDirectory.appendingPathComponent("test.txt")
            try "zed\nalpha\nbeta\n".write(to: textURL, atomically: true, encoding: .utf8)

            let words = try DAWGCommand().words(for: "test", in: inputDirectory)

            XCTAssertEqual(words, ["alpha", "beta", "zed"])
        }
    }

    func testWordsReadsZipWordListThroughInjectedUnzip() throws {
        try withTemporaryDirectory { inputDirectory in
            let archiveURL = inputDirectory.appendingPathComponent("test.zip")
            try Data().write(to: archiveURL)
            let requestedArguments = LockIsolated<[String]?>(nil)
            let command = DAWGCommand(unzip: { arguments in
                requestedArguments.setValue(arguments)
                return Data("zed\nalpha\nbeta\n".utf8)
            })

            let words = try command.words(for: "test", in: inputDirectory)

            XCTAssertEqual(words, ["alpha", "beta", "zed"])
            XCTAssertEqual(requestedArguments.value, ["-p", archiveURL.path, "test.txt"])
        }
    }

    func testWordsRejectsInvalidUTF8FromZipWordList() throws {
        try withTemporaryDirectory { inputDirectory in
            try Data().write(to: inputDirectory.appendingPathComponent("test.zip"))
            let command = DAWGCommand(unzip: { _ in Data([0xff]) })

            XCTAssertThrowsError(try command.words(for: "test", in: inputDirectory)) { error in
                guard case WordListError.invalidUTF8 = error else {
                    return XCTFail("Expected invalid UTF-8 error, got \(error).")
                }
            }
        }
    }

    func testWordsRejectsMissingWordList() throws {
        try withTemporaryDirectory { inputDirectory in
            XCTAssertThrowsError(try DAWGCommand().words(for: "missing", in: inputDirectory)) { error in
                guard case let WordListError.missingWordList(language, directory) = error else {
                    return XCTFail("Expected missing word list error, got \(error).")
                }
                XCTAssertEqual(language, "missing")
                XCTAssertEqual(directory, inputDirectory)
            }
        }
    }

    func testGenerateRejectsMissingInputDirectory() {
        let inputDirectory = temporaryURL("missing")

        XCTAssertThrowsError(try DAWGCommand().generate(arguments: [
            "DAWGBuilder",
            "--input-dir", inputDirectory.path
        ])) { error in
            guard case .inputDirectoryMissing(inputDirectory) = error as? DAWGCommand.CommandError else {
                XCTFail()
                return
            }
        }
    }

    func testGenerateRejectsEmptyInputDirectory() throws {
        try withTemporaryDirectory { inputDirectory in
            XCTAssertThrowsError(try DAWGCommand().generate(arguments: [
                "DAWGBuilder",
                "--input-dir", inputDirectory.path
            ])) { error in
                guard case .noWordListsFound(inputDirectory) = error as? DAWGCommand.CommandError else {
                    XCTFail()
                    return
                }
            }
        }
    }

    func testGenerateWritesReadableDAWGFile() throws {
        try withTemporaryDirectory { inputDirectory in
            try withTemporaryDirectory { outputDirectory in
                try "ant\nbat\ncat\n".write(
                    to: inputDirectory.appendingPathComponent("test.txt"),
                    atomically: true,
                    encoding: .utf8
                )

                let results = try DAWGCommand().generate(arguments: [
                    "DAWGBuilder",
                    "--input-dir", inputDirectory.path,
                    "--output-dir", outputDirectory.path
                ])

                let outputURL = outputDirectory.appendingPathComponent("test.dawg")
                let byteCount = try Data(contentsOf: outputURL).count
                XCTAssertEqual(results, [.init(outputURL: outputURL, wordCount: 3, byteCount: byteCount)])

                let dawg = try DAWG(url: outputURL)
                XCTAssertTrue(dawg.contains("ant"))
                XCTAssertTrue(dawg.contains("bat"))
                XCTAssertTrue(dawg.contains("cat"))
            }
        }
    }
}

private func withTemporaryDirectory(_ operation: (URL) throws -> Void) throws {
    let directory = temporaryURL(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    try operation(directory)
}

private func temporaryURL(_ component: String) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(component, isDirectory: true)
}
