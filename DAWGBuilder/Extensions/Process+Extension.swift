//
//  DAWGBuilder
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

extension Process {
    static func unzip(arguments: [String]) throws -> Data {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
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
}
