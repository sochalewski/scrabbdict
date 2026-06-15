//
//  DAWGBuilder
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

private func fail(_ message: String, code: Int32 = 1) -> Never {
    fputs("\(message)\n", stderr)
    exit(code)
}

do {
    let results = try DAWGCommand(unzip: Process.unzip).generate(arguments: CommandLine.arguments)
    for result in results {
        print("Generated \(result.outputURL.path) (\(result.wordCount) words, \(DAWGCommand.formatByteCount(result.byteCount)))")
    }
} catch {
    if case .help = error {
        print(error.description)
        exit(error.exitCode)
    } else {
        fail(error.description, code: error.exitCode)
    }
}
