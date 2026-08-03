//
//  DAWGPerformance
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Darwin
import Foundation

private enum MemoryProbeError: Error, CustomStringConvertible {
    case footprintUnavailable(kern_return_t)
    case invalidArguments
    case unknownLanguage(String)

    var description: String {
        switch self {
        case let .footprintUnavailable(result):
            "task_info(TASK_VM_INFO) failed with code \(result)"
        case .invalidArguments:
            "Usage: DAWGMemoryProbe <dictionary-dir> <language>"
        case let .unknownLanguage(language):
            "Unknown language: \(language)"
        }
    }
}

@main
private enum DAWGMemoryProbe {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            let message = "DAWG memory probe failed: \(error)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }
}

private extension DAWGMemoryProbe {
    static func run(arguments: [String]) throws {
        guard arguments.count == 2 else {
            throw MemoryProbeError.invalidArguments
        }
        guard let language = Language(rawValue: arguments[1]) else {
            throw MemoryProbeError.unknownLanguage(arguments[1])
        }

        let dictionaryURL = URL(fileURLWithPath: arguments[0], isDirectory: true)
            .appendingPathComponent(language.rawValue)
            .appendingPathExtension("dawg")
        let before = try physicalFootprint()
        let dawg = try DAWG(url: dictionaryURL)
        let count = dawg.count

        try withExtendedLifetime(dawg) {
            let after = try physicalFootprint()
            let delta = Int64(after) - Int64(before)
            print("\(language.rawValue)\t\(before)\t\(after)\t\(delta)\t\(count)")
        }
    }

    static func physicalFootprint() throws -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    rebound,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw MemoryProbeError.footprintUnavailable(result)
        }
        return info.phys_footprint
    }
}
