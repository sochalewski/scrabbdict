//
//  DAWGPerformance
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Darwin
import DAWGSideA
import DAWGSideB
import Foundation

private enum InputsMode: String {
    case matching
    case sharedBase = "shared-base"
    case sharedCompare = "shared-compare"
}

private enum Side: String {
    case base = "A"
    case compare = "B"
}

private enum ModuleAssignment: String {
    case normal
    case crossed
}

private enum MeasurementProfile: String {
    case quick
    case decision
    case confirm

    func samplingConfiguration(for operation: BenchmarkOperation) -> SamplingConfiguration {
        switch self {
        case .quick:
            SamplingConfiguration(supercycles: 3, targetNanoseconds: 9_000_000)
        case .decision, .confirm:
            switch operation {
            case .load:
                SamplingConfiguration(supercycles: 3, targetNanoseconds: 17_000_000)
            case .contains:
                SamplingConfiguration(supercycles: 7, targetNanoseconds: 8_000_000)
            case .words, .pattern:
                SamplingConfiguration(supercycles: 5, targetNanoseconds: 10_000_000)
            }
        }
    }
}

private struct SamplingConfiguration {
    let supercycles: Int
    let targetNanoseconds: UInt64
}

private enum Schedule: String {
    case abba = "ABBA"
    case baab = "BAAB"

    var sides: [Side] {
        switch self {
        case .abba:
            [.base, .compare, .compare, .base]
        case .baab:
            [.compare, .base, .base, .compare]
        }
    }
}

private enum Phase: String {
    case abbaFirst = "ABBA-first"
    case baabFirst = "BAAB-first"

    var firstSchedule: Schedule {
        switch self {
        case .abbaFirst: .abba
        case .baabFirst: .baab
        }
    }

    func schedules(forSupercycle index: Int) -> [Schedule] {
        let startsWithABBA = switch self {
        case .abbaFirst: index.isMultiple(of: 2)
        case .baabFirst: !index.isMultiple(of: 2)
        }
        return startsWithABBA ? [.abba, .baab] : [.baab, .abba]
    }
}

private struct RunnerError: Error, CustomStringConvertible {
    let description: String
}

private struct LocalMeasurement {
    let cpuNanoseconds: UInt64
    let wallNanoseconds: UInt64
    let checksum: UInt64
}

private struct LocalPreflightResult {
    let values: [String]
    let digest: String
    let count: Int
}

private struct ExpectedPreflight {
    let workload: String
    let operation: BenchmarkOperation
    let language: Language
    let baseDigest: String
    let compareDigest: String
    let baseCount: Int
    let compareCount: Int
    let equal: Bool
}

private struct CalibrationEntry {
    let workload: String
    let operation: BenchmarkOperation
    let operations: Int
    let supercycles: Int
    let targetNanoseconds: UInt64
    let baseCPUNanoseconds: UInt64
    let compareCPUNanoseconds: UInt64
}

private struct RawRow {
    let block: Int
    let phase: Phase
    let moduleAssignment: ModuleAssignment
    let worker: Int
    let supercycle: Int
    let schedule: Schedule
    let position: Int
    let workload: BenchmarkWorkload
    let side: Side
    let measurement: LocalMeasurement
    let operations: Int
    let thermalBefore: String
    let thermalAfter: String
    let lowPower: Bool

    var tsv: String {
        [
            String(block),
            phase.rawValue,
            moduleAssignment.rawValue,
            String(worker),
            String(supercycle),
            schedule.rawValue,
            String(position),
            workload.name,
            workload.operation.rawValue,
            side.rawValue,
            String(measurement.cpuNanoseconds),
            String(measurement.wallNanoseconds),
            String(measurement.checksum),
            String(operations),
            thermalBefore,
            thermalAfter,
            lowPower ? "1" : "0"
        ].joined(separator: "\t")
    }
}

@main
private enum PairedRunner {
    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            let message = "DAWG performance runner failed: \(error)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(EXIT_FAILURE)
        }
    }
}

private extension PairedRunner {
    static let preflightHeader = [
        "workload",
        "operation",
        "language",
        "base_digest",
        "compare_digest",
        "base_count",
        "compare_count",
        "equal"
    ].joined(separator: "\t")

    static let calibrationHeader = [
        "workload",
        "operation",
        "operations",
        "supercycles",
        "target_ns",
        "base_cpu_ns",
        "compare_cpu_ns"
    ].joined(separator: "\t")

    static let rawHeader = [
        "block",
        "phase",
        "module_assignment",
        "worker",
        "supercycle",
        "schedule",
        "position",
        "workload",
        "operation",
        "side",
        "cpu_ns",
        "wall_ns",
        "checksum",
        "operations",
        "thermal_before",
        "thermal_after",
        "low_power"
    ].joined(separator: "\t")

    static var moduleAssignment: ModuleAssignment {
        #if CROSSED_MODULES
            .crossed
        #else
            .normal
        #endif
    }

    static let processInfo = ProcessInfo.processInfo

    static func run(arguments: [String]) throws {
        guard let subcommand = arguments.first else {
            throw RunnerError(description: usage)
        }

        let qosResult = pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0)
        guard qosResult == 0 else {
            throw RunnerError(description: "pthread_set_qos_class_self_np failed with code \(qosResult)")
        }

        switch subcommand {
        case "self-test":
            guard arguments.count == 1 else {
                throw RunnerError(description: usage)
            }
            try runSelfTests()
        case "preflight":
            guard arguments.count == 4, let inputsMode = InputsMode(rawValue: arguments[3]) else {
                throw RunnerError(description: usage)
            }
            try runPreflight(
                baseDirectory: directoryURL(arguments[1]),
                compareDirectory: directoryURL(arguments[2]),
                inputsMode: inputsMode
            )
        case "calibrate":
            guard
                arguments.count == 6,
                let profile = MeasurementProfile(rawValue: arguments[3])
            else {
                throw RunnerError(description: usage)
            }
            try calibrate(
                baseDirectory: directoryURL(arguments[1]),
                compareDirectory: directoryURL(arguments[2]),
                profile: profile,
                outputURL: URL(fileURLWithPath: arguments[4]),
                workloadName: arguments[5]
            )
        case "block":
            guard
                arguments.count == 9,
                let blockIndex = Int(arguments[4]),
                blockIndex > 0,
                let phase = Phase(rawValue: arguments[5]),
                let worker = Int(arguments[8]),
                worker == 1 || worker == 2
            else {
                throw RunnerError(description: usage)
            }
            try runBlock(
                baseDirectory: directoryURL(arguments[1]),
                compareDirectory: directoryURL(arguments[2]),
                profileURL: URL(fileURLWithPath: arguments[3]),
                preflightURL: URL(fileURLWithPath: arguments[6]),
                blockIndex: blockIndex,
                phase: phase,
                workloadName: arguments[7],
                worker: worker
            )
        case "workload-order":
            guard
                arguments.count == 3,
                let blockIndex = Int(arguments[1]),
                blockIndex > 0,
                let phase = Phase(rawValue: arguments[2])
            else {
                throw RunnerError(description: usage)
            }
            rotatedWorkloads(for: blockIndex, phase: phase).forEach { print($0.name) }
        case "verify-profile":
            guard arguments.count == 6 else {
                throw RunnerError(description: usage)
            }
            try verifyCalibrationProfile(
                baseDirectory: directoryURL(arguments[1]),
                compareDirectory: directoryURL(arguments[2]),
                inputURL: URL(fileURLWithPath: arguments[3]),
                outputURL: URL(fileURLWithPath: arguments[4]),
                workloadName: arguments[5]
            )
        default:
            throw RunnerError(description: usage)
        }
    }

    static var usage: String {
        """
        Usage:
          PairedRunner self-test
          PairedRunner preflight <base-dir> <compare-dir> <matching|shared-base|shared-compare>
          PairedRunner calibrate <base-dir> <compare-dir> <quick|decision|confirm> <profile-output> <workload>
          PairedRunner verify-profile <base-dir> <compare-dir> <profile> <verified-output> <workload>
          PairedRunner workload-order <block-index> <ABBA-first|BAAB-first>
          PairedRunner block <base-dir> <compare-dir> <profile> <block-index> <ABBA-first|BAAB-first> <preflight> <workload> <worker-1|2>
        """
    }

    static func directoryURL(_ path: String) -> URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    static func workload(named name: String) throws -> (index: Int, workload: BenchmarkWorkload) {
        guard let index = benchmarkWorkloads.firstIndex(where: { $0.name == name }) else {
            throw RunnerError(description: "Unknown workload: \(name)")
        }
        return (index, benchmarkWorkloads[index])
    }

    static func runSelfTests() throws {
        for phase in [Phase.abbaFirst, .baabFirst] {
            for supercycleCount in [3, 5, 7] {
                let bridgeSupercycleIndex = supercycleCount / 2
                for worker in 1...2 {
                    let firstMeasuredIndex = worker == 1 ? 0 : bridgeSupercycleIndex
                    let warmupSides = phase.schedules(forSupercycle: firstMeasuredIndex - 1).flatMap(\.sides)
                    let firstMeasuredSides = phase.schedules(forSupercycle: firstMeasuredIndex).flatMap(\.sides)
                    guard
                        warmupSides.filter({ $0 == .base }).count == 4,
                        warmupSides.filter({ $0 == .compare }).count == 4,
                        warmupSides.last == firstMeasuredSides.first
                    else {
                        throw RunnerError(description: "Warm-up is not balanced and contiguous with worker \(worker)")
                    }
                }
            }

            var positions: [String: [Int]] = [:]
            for cycle in 0..<8 {
                let workloads = rotatedWorkloads(for: cycle * 4 + 1, phase: phase)
                guard workloads.count == benchmarkWorkloads.count, Set(workloads.map(\.name)).count == workloads.count else {
                    throw RunnerError(description: "Workload rotation is incomplete")
                }
                for (position, workload) in workloads.enumerated() {
                    positions[workload.name, default: []].append(position + 1)
                }
            }
            for workload in benchmarkWorkloads {
                guard let workloadPositions = positions[workload.name], workloadPositions.count == 8 else {
                    throw RunnerError(description: "Workload rotation is missing \(workload.name)")
                }
                for pairStart in stride(from: 0, to: workloadPositions.count, by: 2) {
                    guard workloadPositions[pairStart] + workloadPositions[pairStart + 1] == benchmarkWorkloads.count + 1 else {
                        throw RunnerError(description: "Workload rotation is not position-balanced for \(workload.name)")
                    }
                }
            }
        }
        print("PairedRunner self-tests passed (warm-up continuity, module, phase, and timeline balance).")
    }
}

private extension PairedRunner {
    static func runPreflight(
        baseDirectory: URL,
        compareDirectory: URL,
        inputsMode: InputsMode
    ) throws {
        let directories: (base: URL, compare: URL) = switch inputsMode {
        case .matching:
            (baseDirectory, compareDirectory)
        case .sharedBase:
            (baseDirectory, baseDirectory)
        case .sharedCompare:
            (compareDirectory, compareDirectory)
        }

        var rows = [String]()
        var allEqual = true

        for workload in benchmarkWorkloads {
            let base = try preflightBase(
                workload: workload,
                url: dictionaryURL(for: workload, in: directories.base)
            )
            let compare = try preflightCompare(
                workload: workload,
                url: dictionaryURL(for: workload, in: directories.compare)
            )
            let equal = base.count == compare.count && base.values == compare.values
            allEqual = allEqual && equal

            rows.append(
                [
                    workload.name,
                    workload.operation.rawValue,
                    workload.language.rawValue,
                    base.digest,
                    compare.digest,
                    String(base.count),
                    String(compare.count),
                    equal ? "true" : "false"
                ].joined(separator: "\t")
            )
        }

        print(preflightHeader)
        rows.forEach { print($0) }

        if inputsMode != .matching, !allEqual {
            throw RunnerError(description: "Shared-input preflight produced different exact results")
        }
    }

    static func preflightBase(
        workload: BenchmarkWorkload,
        url: URL
    ) throws -> LocalPreflightResult {
        #if CROSSED_MODULES
            let result = try DAWGSideB.BenchmarkAdapter.preflight(
                operation: baseOperation(workload.operation),
                url: url,
                query: workload.query
            )
        #else
            let result = try DAWGSideA.BenchmarkAdapter.preflight(
                operation: baseOperation(workload.operation),
                url: url,
                query: workload.query
            )
        #endif
        return LocalPreflightResult(
            values: result.values,
            digest: result.digest,
            count: result.count
        )
    }

    static func preflightCompare(
        workload: BenchmarkWorkload,
        url: URL
    ) throws -> LocalPreflightResult {
        #if CROSSED_MODULES
            let result = try DAWGSideA.BenchmarkAdapter.preflight(
                operation: compareOperation(workload.operation),
                url: url,
                query: workload.query
            )
        #else
            let result = try DAWGSideB.BenchmarkAdapter.preflight(
                operation: compareOperation(workload.operation),
                url: url,
                query: workload.query
            )
        #endif
        return LocalPreflightResult(
            values: result.values,
            digest: result.digest,
            count: result.count
        )
    }

    static func readExpectedPreflights(_ url: URL) throws -> [String: ExpectedPreflight] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.first == preflightHeader else {
            throw RunnerError(description: "Invalid preflight header at \(url.path)")
        }

        let workloadsByName = Dictionary(uniqueKeysWithValues: benchmarkWorkloads.map { ($0.name, $0) })
        var entries = [String: ExpectedPreflight]()
        for line in lines.dropFirst() {
            let fields = line.components(separatedBy: "\t")
            guard
                fields.count == 8,
                let workload = workloadsByName[fields[0]],
                workload.operation.rawValue == fields[1],
                workload.language.rawValue == fields[2],
                !fields[3].isEmpty,
                !fields[4].isEmpty,
                let baseCount = Int(fields[5]),
                baseCount >= 0,
                let compareCount = Int(fields[6]),
                compareCount >= 0,
                let equal = parsePreflightBool(fields[7]),
                entries[fields[0]] == nil
            else {
                throw RunnerError(description: "Invalid preflight row: \(line)")
            }
            guard
                !equal || (fields[3] == fields[4] && baseCount == compareCount)
            else {
                throw RunnerError(description: "Equal preflight row differs between sides: \(line)")
            }

            entries[fields[0]] = ExpectedPreflight(
                workload: workload.name,
                operation: workload.operation,
                language: workload.language,
                baseDigest: fields[3],
                compareDigest: fields[4],
                baseCount: baseCount,
                compareCount: compareCount,
                equal: equal
            )
        }

        guard entries.count == benchmarkWorkloads.count else {
            throw RunnerError(description: "Preflight must contain all \(benchmarkWorkloads.count) workloads")
        }
        return entries
    }

    static func parsePreflightBool(_ value: String) -> Bool? {
        switch value {
        case "true": true
        case "false": false
        default: nil
        }
    }

    static func validateImmediatePreflight(
        workload: BenchmarkWorkload,
        expected: ExpectedPreflight,
        baseURL: URL,
        compareURL: URL,
        schedule: Schedule
    ) throws {
        let base: LocalPreflightResult
        let compare: LocalPreflightResult
        switch schedule {
        case .abba:
            base = try preflightBase(workload: workload, url: baseURL)
            compare = try preflightCompare(workload: workload, url: compareURL)
        case .baab:
            compare = try preflightCompare(workload: workload, url: compareURL)
            base = try preflightBase(workload: workload, url: baseURL)
        }

        guard
            expected.workload == workload.name,
            expected.operation == workload.operation,
            expected.language == workload.language,
            base.digest == expected.baseDigest,
            compare.digest == expected.compareDigest,
            base.count == expected.baseCount,
            compare.count == expected.compareCount
        else {
            throw RunnerError(description: "Immediate preflight changed for \(workload.name)")
        }
        guard !expected.equal || base.values == compare.values else {
            throw RunnerError(description: "Immediate preflight differs between sides for \(workload.name)")
        }
    }
}

private extension PairedRunner {
    static func calibrate(
        baseDirectory: URL,
        compareDirectory: URL,
        profile: MeasurementProfile,
        outputURL: URL,
        workloadName: String
    ) throws {
        let (index, workload) = try workload(named: workloadName)
        let configuration = profile.samplingConfiguration(for: workload.operation)
        let verificationTargetNanoseconds = UInt64(
            (Double(configuration.targetNanoseconds) * 1.10).rounded(.up)
        )
        let baseURL = dictionaryURL(for: workload, in: baseDirectory)
        let compareURL = dictionaryURL(for: workload, in: compareDirectory)
        let pilotOperations = workload.pilotOperations

        _ = try measurePair(
            workload: workload,
            baseURL: baseURL,
            compareURL: compareURL,
            operations: pilotOperations,
            baseFirst: index.isMultiple(of: 2)
        )

        var basePilots = [LocalMeasurement]()
        var comparePilots = [LocalMeasurement]()
        basePilots.reserveCapacity(3)
        comparePilots.reserveCapacity(3)
        for pilot in 0..<3 {
            let pair = try measurePair(
                workload: workload,
                baseURL: baseURL,
                compareURL: compareURL,
                operations: pilotOperations,
                baseFirst: (index + pilot).isMultiple(of: 2)
            )
            basePilots.append(pair.base)
            comparePilots.append(pair.compare)
        }

        try validateStableChecksums(basePilots, workload: workload, side: .base)
        try validateStableChecksums(comparePilots, workload: workload, side: .compare)

        let fastestPerOperation = Double(min(
            median(basePilots.map(\.cpuNanoseconds)),
            median(comparePilots.map(\.cpuNanoseconds))
        )) / Double(pilotOperations)
        guard fastestPerOperation > 0 else {
            throw RunnerError(description: "Zero-duration calibration pilot for \(workload.name)")
        }

        let initialOperations = try checkedOperationCount(
            ceil(Double(verificationTargetNanoseconds) * 1.02 / fastestPerOperation),
            workload: workload
        )
        let verified = try verifyCalibration(
            workload: workload,
            baseURL: baseURL,
            compareURL: compareURL,
            initialOperations: initialOperations,
            targetNanoseconds: verificationTargetNanoseconds,
            orderOffset: index
        )
        try writeCalibrationProfile(
            CalibrationEntry(
                workload: workload.name,
                operation: workload.operation,
                operations: verified.operations,
                supercycles: configuration.supercycles,
                targetNanoseconds: configuration.targetNanoseconds,
                baseCPUNanoseconds: verified.base.cpuNanoseconds,
                compareCPUNanoseconds: verified.compare.cpuNanoseconds
            ),
            to: outputURL
        )
    }

    static func verifyCalibrationProfile(
        baseDirectory: URL,
        compareDirectory: URL,
        inputURL: URL,
        outputURL: URL,
        workloadName: String
    ) throws {
        let profile = try readCalibrationProfile(inputURL)
        let (index, workload) = try workload(named: workloadName)
        guard let calibration = profile[workload.name] else {
            throw RunnerError(description: "Missing calibration entry for \(workload.name)")
        }
        let baseURL = dictionaryURL(for: workload, in: baseDirectory)
        let compareURL = dictionaryURL(for: workload, in: compareDirectory)
        let verified = try verifyCalibration(
            workload: workload,
            baseURL: baseURL,
            compareURL: compareURL,
            initialOperations: calibration.operations,
            targetNanoseconds: UInt64((Double(calibration.targetNanoseconds) * 1.10).rounded(.up)),
            orderOffset: index
        )
        try writeCalibrationProfile(
            CalibrationEntry(
                workload: workload.name,
                operation: workload.operation,
                operations: verified.operations,
                supercycles: calibration.supercycles,
                targetNanoseconds: calibration.targetNanoseconds,
                baseCPUNanoseconds: verified.base.cpuNanoseconds,
                compareCPUNanoseconds: verified.compare.cpuNanoseconds
            ),
            to: outputURL
        )
    }

    static func writeCalibrationProfile(
        _ entry: CalibrationEntry,
        to outputURL: URL
    ) throws {
        let lines = [
            calibrationHeader,
            [
                entry.workload,
                entry.operation.rawValue,
                String(entry.operations),
                String(entry.supercycles),
                String(entry.targetNanoseconds),
                String(entry.baseCPUNanoseconds),
                String(entry.compareCPUNanoseconds)
            ].joined(separator: "\t")
        ]
        try (lines.joined(separator: "\n") + "\n").write(
            to: outputURL,
            atomically: true,
            encoding: .utf8
        )
    }

    static func measurePair(
        workload: BenchmarkWorkload,
        baseURL: URL,
        compareURL: URL,
        operations: Int,
        baseFirst: Bool
    ) throws -> (base: LocalMeasurement, compare: LocalMeasurement) {
        if baseFirst {
            let base = try measureBase(workload: workload, url: baseURL, operations: operations)
            let compare = try measureCompare(workload: workload, url: compareURL, operations: operations)
            return (base, compare)
        }
        let compare = try measureCompare(workload: workload, url: compareURL, operations: operations)
        let base = try measureBase(workload: workload, url: baseURL, operations: operations)
        return (base, compare)
    }

    static func verifyCalibration(
        workload: BenchmarkWorkload,
        baseURL: URL,
        compareURL: URL,
        initialOperations: Int,
        targetNanoseconds: UInt64,
        orderOffset: Int
    ) throws -> (operations: Int, base: LocalMeasurement, compare: LocalMeasurement) {
        var operations = initialOperations
        for attempt in 0..<6 {
            let pair = try measurePair(
                workload: workload,
                baseURL: baseURL,
                compareURL: compareURL,
                operations: operations,
                baseFirst: (orderOffset + attempt).isMultiple(of: 2)
            )
            let fastest = min(pair.base.cpuNanoseconds, pair.compare.cpuNanoseconds)
            if fastest >= targetNanoseconds {
                return (operations, pair.base, pair.compare)
            }
            guard fastest > 0, operations < Int.max else {
                throw RunnerError(description: "Could not verify calibration target for \(workload.name)")
            }
            let scaled = ceil(
                Double(operations) * Double(targetNanoseconds) * 1.02 / Double(fastest)
            )
            operations = try max(
                operations + 1,
                checkedOperationCount(scaled, workload: workload)
            )
        }
        throw RunnerError(description: "Could not verify calibration target for \(workload.name)")
    }

    static func checkedOperationCount(
        _ value: Double,
        workload: BenchmarkWorkload
    ) throws -> Int {
        guard value.isFinite, value >= 1, value <= Double(Int.max) else {
            throw RunnerError(description: "Invalid calibrated operation count for \(workload.name)")
        }
        return Int(value)
    }

    static func median(_ values: [UInt64]) -> UInt64 {
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}

private extension PairedRunner {
    static func runBlock(
        baseDirectory: URL,
        compareDirectory: URL,
        profileURL: URL,
        preflightURL: URL,
        blockIndex: Int,
        phase: Phase,
        workloadName: String,
        worker: Int
    ) throws {
        let profile = try readCalibrationProfile(profileURL)
        let expectedPreflights = try readExpectedPreflights(preflightURL)
        let (_, workload) = try workload(named: workloadName)
        guard let calibration = profile[workload.name] else {
            throw RunnerError(description: "Missing calibration entry for \(workload.name)")
        }
        guard let expectedPreflight = expectedPreflights[workload.name] else {
            throw RunnerError(description: "Missing preflight entry for \(workload.name)")
        }

        let baseURL = dictionaryURL(for: workload, in: baseDirectory)
        let compareURL = dictionaryURL(for: workload, in: compareDirectory)

        try validateImmediatePreflight(
            workload: workload,
            expected: expectedPreflight,
            baseURL: baseURL,
            compareURL: compareURL,
            schedule: phase.firstSchedule
        )

        let bridgeSupercycleIndex = calibration.supercycles / 2
        let firstSupercycleIndex = worker == 1 ? 0 : bridgeSupercycleIndex
        let endSupercycleIndex = worker == 1 ? bridgeSupercycleIndex + 1 : calibration.supercycles
        let supercycleIndices = firstSupercycleIndex..<endSupercycleIndex

        // Warm both orientations with the exact timed leg size. Using the
        // preceding parity makes the warm-up end on the side that starts
        // this worker's first measured supercycle.
        for schedule in phase.schedules(forSupercycle: firstSupercycleIndex - 1) {
            for side in schedule.sides {
                _ = try measure(
                    side: side,
                    workload: workload,
                    baseURL: baseURL,
                    compareURL: compareURL,
                    operations: calibration.operations
                )
            }
        }

        var rows = [RawRow]()
        rows.reserveCapacity(supercycleIndices.count * 8)
        for supercycleIndex in supercycleIndices {
            for schedule in phase.schedules(forSupercycle: supercycleIndex) {
                for (position, side) in schedule.sides.enumerated() {
                    let thermalBefore = thermalStateName
                    let lowPower = isLowPowerModeEnabled
                    let measurement = try measure(
                        side: side,
                        workload: workload,
                        baseURL: baseURL,
                        compareURL: compareURL,
                        operations: calibration.operations
                    )

                    rows.append(
                        RawRow(
                            block: blockIndex,
                            phase: phase,
                            moduleAssignment: moduleAssignment,
                            worker: worker,
                            supercycle: supercycleIndex + 1,
                            schedule: schedule,
                            position: position + 1,
                            workload: workload,
                            side: side,
                            measurement: measurement,
                            operations: calibration.operations,
                            thermalBefore: thermalBefore,
                            thermalAfter: thermalStateName,
                            lowPower: lowPower
                        )
                    )
                }
            }
        }

        try validateBlockChecksums(
            rows,
            workload: workload,
            expectedMeasurementsPerSide: supercycleIndices.count * 4
        )
        print(rawHeader)
        rows.forEach { print($0.tsv) }
    }

    static func readCalibrationProfile(_ url: URL) throws -> [String: CalibrationEntry] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.first == calibrationHeader else {
            throw RunnerError(description: "Invalid calibration profile header at \(url.path)")
        }

        var entries = [String: CalibrationEntry]()
        for line in lines.dropFirst() {
            let fields = line.components(separatedBy: "\t")
            guard
                fields.count == 7,
                let operation = BenchmarkOperation(rawValue: fields[1]),
                let operations = Int(fields[2]),
                operations > 0,
                let supercycles = Int(fields[3]),
                supercycles > 0,
                let targetNanoseconds = UInt64(fields[4]),
                targetNanoseconds > 0,
                let baseCPUNanoseconds = UInt64(fields[5]),
                baseCPUNanoseconds > 0,
                let compareCPUNanoseconds = UInt64(fields[6]),
                compareCPUNanoseconds > 0,
                entries[fields[0]] == nil
            else {
                throw RunnerError(description: "Invalid calibration profile row: \(line)")
            }

            entries[fields[0]] = CalibrationEntry(
                workload: fields[0],
                operation: operation,
                operations: operations,
                supercycles: supercycles,
                targetNanoseconds: targetNanoseconds,
                baseCPUNanoseconds: baseCPUNanoseconds,
                compareCPUNanoseconds: compareCPUNanoseconds
            )
        }

        guard entries.count == benchmarkWorkloads.count else {
            throw RunnerError(description: "Calibration profile must contain all \(benchmarkWorkloads.count) workloads")
        }
        for workload in benchmarkWorkloads {
            guard entries[workload.name]?.operation == workload.operation else {
                throw RunnerError(description: "Calibration operation mismatch for \(workload.name)")
            }
        }
        return entries
    }

    static func rotatedWorkloads(
        for blockIndex: Int,
        phase: Phase
    ) -> [BenchmarkWorkload] {
        // Pair consecutive four-process cycles at the same cyclic shifts and
        // opposite directions. In decision and confirm profiles this gives every
        // workload mean position 10.5 independently inside each module × phase
        // cell, while each individual cycle also balances direction across both
        // module assignment and first orientation.
        let zeroBasedBlock = blockIndex - 1
        let cycle = zeroBasedBlock / 4
        let cell = switch (moduleAssignment, phase) {
        case (.normal, .abbaFirst): 0
        case (.crossed, .baabFirst): 1
        case (.crossed, .abbaFirst): 2
        case (.normal, .baabFirst): 3
        }
        let cyclePair = cycle / 2
        let offset = (cyclePair * 7 + cell * 5) % benchmarkWorkloads.count
        let rotated = Array(benchmarkWorkloads[offset...] + benchmarkWorkloads[..<offset])
        let reverse = !(cycle + cell / 2).isMultiple(of: 2)
        return reverse ? Array(rotated.reversed()) : rotated
    }
}

private extension PairedRunner {
    static func dictionaryURL(for workload: BenchmarkWorkload, in directory: URL) -> URL {
        directory
            .appendingPathComponent(workload.language.rawValue)
            .appendingPathExtension("dawg")
    }

    static func measureBase(
        workload: BenchmarkWorkload,
        url: URL,
        operations: Int
    ) throws -> LocalMeasurement {
        #if CROSSED_MODULES
            let result = try DAWGSideB.BenchmarkAdapter.measure(
                operation: baseOperation(workload.operation),
                url: url,
                query: workload.query,
                operations: operations
            )
        #else
            let result = try DAWGSideA.BenchmarkAdapter.measure(
                operation: baseOperation(workload.operation),
                url: url,
                query: workload.query,
                operations: operations
            )
        #endif
        return LocalMeasurement(
            cpuNanoseconds: result.cpuNanoseconds,
            wallNanoseconds: result.wallNanoseconds,
            checksum: result.checksum
        )
    }

    static func measureCompare(
        workload: BenchmarkWorkload,
        url: URL,
        operations: Int
    ) throws -> LocalMeasurement {
        #if CROSSED_MODULES
            let result = try DAWGSideA.BenchmarkAdapter.measure(
                operation: compareOperation(workload.operation),
                url: url,
                query: workload.query,
                operations: operations
            )
        #else
            let result = try DAWGSideB.BenchmarkAdapter.measure(
                operation: compareOperation(workload.operation),
                url: url,
                query: workload.query,
                operations: operations
            )
        #endif
        return LocalMeasurement(
            cpuNanoseconds: result.cpuNanoseconds,
            wallNanoseconds: result.wallNanoseconds,
            checksum: result.checksum
        )
    }

    static func measure(
        side: Side,
        workload: BenchmarkWorkload,
        baseURL: URL,
        compareURL: URL,
        operations: Int
    ) throws -> LocalMeasurement {
        switch side {
        case .base:
            try measureBase(workload: workload, url: baseURL, operations: operations)
        case .compare:
            try measureCompare(workload: workload, url: compareURL, operations: operations)
        }
    }

    #if CROSSED_MODULES
        static func baseOperation(
            _ operation: BenchmarkOperation
        ) -> DAWGSideB.BenchmarkAdapter.Operation {
            switch operation {
            case .load:
                .load
            case .contains:
                .contains
            case .words:
                .words
            case .pattern:
                .pattern
            }
        }

        static func compareOperation(
            _ operation: BenchmarkOperation
        ) -> DAWGSideA.BenchmarkAdapter.Operation {
            switch operation {
            case .load:
                .load
            case .contains:
                .contains
            case .words:
                .words
            case .pattern:
                .pattern
            }
        }
    #else
        static func baseOperation(
            _ operation: BenchmarkOperation
        ) -> DAWGSideA.BenchmarkAdapter.Operation {
            switch operation {
            case .load:
                .load
            case .contains:
                .contains
            case .words:
                .words
            case .pattern:
                .pattern
            }
        }

        static func compareOperation(
            _ operation: BenchmarkOperation
        ) -> DAWGSideB.BenchmarkAdapter.Operation {
            switch operation {
            case .load:
                .load
            case .contains:
                .contains
            case .words:
                .words
            case .pattern:
                .pattern
            }
        }
    #endif

    static func validateStableChecksums(
        _ measurements: [LocalMeasurement],
        workload: BenchmarkWorkload,
        side: Side
    ) throws {
        guard let expected = measurements.first?.checksum else {
            throw RunnerError(description: "Missing checksum for \(workload.name) side \(side.rawValue)")
        }
        guard measurements.dropFirst().allSatisfy({ $0.checksum == expected }) else {
            throw RunnerError(description: "Checksum changed for \(workload.name) side \(side.rawValue)")
        }
    }

    static func validateBlockChecksums(
        _ rows: [RawRow],
        workload: BenchmarkWorkload,
        expectedMeasurementsPerSide: Int
    ) throws {
        let base = rows.filter { $0.side == .base }.map(\.measurement)
        let compare = rows.filter { $0.side == .compare }.map(\.measurement)
        guard base.count == expectedMeasurementsPerSide, compare.count == expectedMeasurementsPerSide else {
            throw RunnerError(description: "Unbalanced supercycles for \(workload.name)")
        }
        try validateStableChecksums(base, workload: workload, side: .base)
        try validateStableChecksums(compare, workload: workload, side: .compare)
    }

    static var thermalStateName: String {
        switch processInfo.thermalState {
        case .nominal:
            "nominal"
        case .fair:
            "fair"
        case .serious:
            "serious"
        case .critical:
            "critical"
        @unknown default:
            "unknown"
        }
    }

    static var isLowPowerModeEnabled: Bool {
        if #available(macOS 12.0, *) {
            processInfo.isLowPowerModeEnabled
        } else {
            false
        }
    }
}
