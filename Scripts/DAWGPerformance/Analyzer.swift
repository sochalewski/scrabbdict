//
//  DAWGPerformance
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

private enum AnalyzerError: Error, CustomStringConvertible {
    case usage(String)
    case invalid(String)

    var description: String {
        switch self {
        case let .usage(message), let .invalid(message):
            message
        }
    }
}

private enum Profile: String {
    case quick
    case decision
    case confirm

    var expectedBlockCount: Int {
        switch self {
        case .quick: 4
        case .decision: 16
        case .confirm: 32
        }
    }

    var allowsVerdict: Bool {
        self != .quick
    }

    func samplingConfiguration(for operation: String) throws -> SamplingConfiguration {
        switch self {
        case .quick:
            return SamplingConfiguration(supercycles: 3, targetNanoseconds: 9_000_000)
        case .decision, .confirm:
            switch operation {
            case "load":
                return SamplingConfiguration(supercycles: 3, targetNanoseconds: 17_000_000)
            case "contains":
                return SamplingConfiguration(supercycles: 7, targetNanoseconds: 8_000_000)
            case "words", "pattern":
                return SamplingConfiguration(supercycles: 5, targetNanoseconds: 10_000_000)
            default:
                throw AnalyzerError.invalid("Unknown calibrated operation: \(operation)")
            }
        }
    }
}

private struct SamplingConfiguration {
    let supercycles: Int
    let targetNanoseconds: UInt64
}

private struct CalibratedWorkload {
    let operations: UInt64
    let supercycles: Int
    let targetNanoseconds: UInt64
}

private enum OutputFormat: String {
    case text
    case markdown
    case none
}

private struct Options {
    let inputDirectory: URL
    let outputDirectory: URL
    let profile: Profile?
    let format: OutputFormat
}

private struct TSVDocument {
    let headers: [String]
    let rows: [[String: String]]

    init(url: URL, requiredHeaders: Set<String>? = nil) throws {
        let contents: String
        do {
            contents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw AnalyzerError.invalid("Could not read \(url.path): \(error.localizedDescription)")
        }

        let lines = contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        guard let firstLine = lines.first else {
            throw AnalyzerError.invalid("TSV file is empty: \(url.path)")
        }

        let parsedHeaders = firstLine.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard !parsedHeaders.contains(where: \.isEmpty), Set(parsedHeaders).count == parsedHeaders.count else {
            throw AnalyzerError.invalid("TSV header contains an empty or duplicate column: \(url.path)")
        }
        if let requiredHeaders {
            let missing = requiredHeaders.subtracting(parsedHeaders)
            guard missing.isEmpty else {
                throw AnalyzerError.invalid("TSV file \(url.lastPathComponent) is missing columns: \(missing.sorted().joined(separator: ", "))")
            }
        }

        let parsedRows = try lines.dropFirst().enumerated().map { offset, line in
            let values = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard values.count == parsedHeaders.count else {
                throw AnalyzerError.invalid("Malformed TSV row \(offset + 2) in \(url.path): expected \(parsedHeaders.count) columns, got \(values.count)")
            }
            return Dictionary(uniqueKeysWithValues: zip(parsedHeaders, values))
        }
        self.headers = parsedHeaders
        self.rows = parsedRows
    }
}

private struct BlockLeg {
    let block: Int
    let phase: String
    let moduleAssignment: String
    let worker: Int
    let supercycle: Int
    let schedule: String
    let position: Int
    let workload: String
    let operation: String
    let side: Character
    let cpuNanoseconds: UInt64
    let wallNanoseconds: UInt64
    let checksum: String
    let operations: UInt64
    let thermalBefore: String
    let thermalAfter: String
    let lowPower: Bool
}

private struct Preflight {
    let workload: String
    let operation: String
    let language: String
    let baseDigest: String
    let compareDigest: String
    let baseCount: UInt64
    let compareCount: UInt64
    let equal: Bool
}

private struct ProcessMeasurement {
    let block: Int
    let workload: String
    let z: Double
    let baseNormalizedCPU: Double
    let compareNormalizedCPU: Double
    let baseTotalCPUNanoseconds: Double
    let compareTotalCPUNanoseconds: Double
    let baseWallCPURatio: Double
    let compareWallCPURatio: Double
    let withinProcessScaledMAD: Double
    let orientationDelta: Double
    let supercycleCount: Int
    let legCount: Int
}

private struct MeasurementKey: Hashable {
    let block: Int
    let workload: String
}

private struct MemoryResult {
    let side: Character
    let language: String
    let medianDeltaBytes: Double
    let sampleCount: Int
    let dictionaryCount: UInt64
}

private struct Estimate {
    let center: Double
    let lower: Double
    let upper: Double
    let median: Double
    let scaledMAD: Double
    let minimum: Double
    let maximum: Double
    let trimCount: Int
}

private enum PreflightStatus {
    case equal
    case changed
    case partial(equal: Int, total: Int)

    var label: String {
        switch self {
        case .equal: "equal"
        case .changed: "changed"
        case let .partial(equal, total): "partial (\(equal)/\(total) equal)"
        }
    }

    var comparable: Bool {
        switch self {
        case .equal, .partial: true
        case .changed: false
        }
    }
}

private enum Classification: String {
    case regression
    case improvement
    case equivalent
    case inconclusive
    case unstableOrderEffect = "unstable-order-effect"
    case notComparable = "not-comparable"
    case notEvaluated = "not-evaluated"
}

private struct ResultRow {
    let name: String
    let kind: String
    let operation: String
    let language: String?
    let preflight: PreflightStatus
    let estimate: Estimate?
    let processCount: Int
    let legCount: Int
    let baseNormalizedCPU: Double?
    let compareNormalizedCPU: Double?
    let baseTotalCPUNanoseconds: Double?
    let compareTotalCPUNanoseconds: Double?
    let baseWallCPURatio: Double?
    let compareWallCPURatio: Double?
    let withinProcessScaledMAD: Double?
    let orientationEstimate: Estimate?
    let supercycleCount: Int
    let classification: Classification
}

private struct Analysis {
    let profile: Profile
    let verdict: Classification?
    let metadata: [String: String]
    let calibrationHeaders: [String]
    let calibrationRows: [[String: String]]
    let blockCount: Int
    let supercycleCount: Int
    let legCount: Int
    let schedules: [String: Int]
    let phases: [String: Int]
    let moduleAssignments: [String: Int]
    let thermalStates: [String]
    let lowPowerObserved: Bool
    let preflights: [Preflight]
    let overallResult: ResultRow
    let workloadResults: [ResultRow]
    let operationResults: [ResultRow]
    let memoryResults: [MemoryResult]?

    var displayedResults: [ResultRow] {
        [overallResult] + operationResults + workloadResults
    }
}

private let blocksHeaders: Set<String> = [
    "block", "phase", "module_assignment", "worker", "supercycle", "schedule", "position", "workload", "operation",
    "side", "cpu_ns", "wall_ns", "checksum", "operations", "thermal_before", "thermal_after", "low_power"
]
private let preflightHeaders: Set<String> = [
    "workload", "operation", "language", "base_digest", "compare_digest", "base_count", "compare_count", "equal"
]
private let memoryHeaders: Set<String> = [
    "side", "language", "sample", "before_bytes", "after_bytes", "delta_bytes", "count"
]
private let operationPresentationOrder = ["load", "contains", "words", "pattern"]

private func operationPrecedes(_ lhs: String, _ rhs: String) -> Bool {
    let lhsRank = operationPresentationOrder.firstIndex(of: lhs) ?? operationPresentationOrder.count
    let rhsRank = operationPresentationOrder.firstIndex(of: rhs) ?? operationPresentationOrder.count
    return lhsRank == rhsRank ? lhs < rhs : lhsRank < rhsRank
}

private func preflightPrecedes(_ lhs: Preflight, _ rhs: Preflight) -> Bool {
    lhs.operation == rhs.operation
        ? lhs.workload < rhs.workload
        : operationPrecedes(lhs.operation, rhs.operation)
}

private func required(_ name: String, in row: [String: String], context: String) throws -> String {
    guard let value = row[name], !value.isEmpty else {
        throw AnalyzerError.invalid("Missing \(name) in \(context)")
    }
    return value
}

private func parseUInt64(_ name: String, in row: [String: String], context: String, positive: Bool = false) throws -> UInt64 {
    let raw = try required(name, in: row, context: context)
    guard let value = UInt64(raw), !positive || value > 0 else {
        throw AnalyzerError.invalid("Invalid \(name) in \(context): \(raw)")
    }
    return value
}

private func parseBool(_ raw: String, context: String) throws -> Bool {
    switch raw {
    case "1", "true": true
    case "0", "false": false
    default: throw AnalyzerError.invalid("Invalid boolean in \(context): \(raw)")
    }
}

private func canonicalSide(_ raw: String, context: String) throws -> Character {
    switch raw {
    case "A": "A"
    case "B": "B"
    default: throw AnalyzerError.invalid("Invalid side in \(context): \(raw)")
    }
}

private func readLegs(from document: TSVDocument) throws -> [BlockLeg] {
    try document.rows.enumerated().map { index, row in
        let context = "blocks.tsv row \(index + 2)"
        let blockRaw = try required("block", in: row, context: context)
        guard let block = Int(blockRaw), block > 0 else {
            throw AnalyzerError.invalid("Invalid block in \(context): \(blockRaw)")
        }
        let positionRaw = try required("position", in: row, context: context)
        guard let position = Int(positionRaw), (1...4).contains(position) else {
            throw AnalyzerError.invalid("Invalid position in \(context): \(positionRaw)")
        }
        let cpu = try parseUInt64("cpu_ns", in: row, context: context, positive: true)
        let wall = try parseUInt64("wall_ns", in: row, context: context, positive: true)
        let supercycleRaw = try required("supercycle", in: row, context: context)
        guard let supercycle = Int(supercycleRaw), supercycle > 0 else {
            throw AnalyzerError.invalid("Invalid supercycle in \(context): \(supercycleRaw)")
        }
        let workerRaw = try required("worker", in: row, context: context)
        guard let worker = Int(workerRaw), worker == 1 || worker == 2 else {
            throw AnalyzerError.invalid("Invalid worker in \(context): \(workerRaw)")
        }
        return try BlockLeg(
            block: block,
            phase: required("phase", in: row, context: context),
            moduleAssignment: required("module_assignment", in: row, context: context).lowercased(),
            worker: worker,
            supercycle: supercycle,
            schedule: required("schedule", in: row, context: context).uppercased(),
            position: position,
            workload: required("workload", in: row, context: context),
            operation: required("operation", in: row, context: context),
            side: canonicalSide(required("side", in: row, context: context), context: context),
            cpuNanoseconds: cpu,
            wallNanoseconds: wall,
            checksum: required("checksum", in: row, context: context),
            operations: parseUInt64("operations", in: row, context: context, positive: true),
            thermalBefore: required("thermal_before", in: row, context: context),
            thermalAfter: required("thermal_after", in: row, context: context),
            lowPower: parseBool(required("low_power", in: row, context: context), context: context)
        )
    }
}

private func readPreflights(from document: TSVDocument) throws -> [String: Preflight] {
    var result: [String: Preflight] = [:]
    for (index, row) in document.rows.enumerated() {
        let context = "preflight.tsv row \(index + 2)"
        let workload = try required("workload", in: row, context: context)
        guard result[workload] == nil else {
            throw AnalyzerError.invalid("Duplicate preflight workload: \(workload)")
        }
        let preflight = try Preflight(
            workload: workload,
            operation: required("operation", in: row, context: context),
            language: required("language", in: row, context: context),
            baseDigest: required("base_digest", in: row, context: context),
            compareDigest: required("compare_digest", in: row, context: context),
            baseCount: parseUInt64("base_count", in: row, context: context),
            compareCount: parseUInt64("compare_count", in: row, context: context),
            equal: parseBool(required("equal", in: row, context: context), context: context)
        )
        guard
            !preflight.equal
            || (preflight.baseDigest == preflight.compareDigest
                && preflight.baseCount == preflight.compareCount)
        else {
            throw AnalyzerError.invalid("Equal preflight has different digest or count for workload \(workload)")
        }
        result[workload] = preflight
    }
    guard !result.isEmpty else {
        throw AnalyzerError.invalid("preflight.tsv contains no workloads")
    }
    return result
}

private func readMemory(from document: TSVDocument) throws -> [MemoryResult] {
    struct Sample {
        let side: Character
        let language: String
        let delta: Int64
        let dictionaryCount: UInt64
    }

    var samples: [Sample] = []
    var seen: Set<String> = []
    for (index, row) in document.rows.enumerated() {
        let context = "memory.tsv row \(index + 2)"
        let side = try canonicalSide(required("side", in: row, context: context), context: context)
        let language = try required("language", in: row, context: context)
        let sample = try parseUInt64("sample", in: row, context: context, positive: true)
        let beforeRaw = try required("before_bytes", in: row, context: context)
        let afterRaw = try required("after_bytes", in: row, context: context)
        let deltaRaw = try required("delta_bytes", in: row, context: context)
        guard
            let before = Int64(beforeRaw), before >= 0,
            let after = Int64(afterRaw), after >= 0,
            let delta = Int64(deltaRaw), delta == after - before
        else {
            throw AnalyzerError.invalid("Invalid or inconsistent footprint values in \(context)")
        }
        let key = "\(side)\u{1f}\(language)\u{1f}\(sample)"
        guard seen.insert(key).inserted else {
            throw AnalyzerError.invalid("Duplicate memory sample in \(context)")
        }
        try samples.append(Sample(
            side: side,
            language: language,
            delta: delta,
            dictionaryCount: parseUInt64("count", in: row, context: context)
        ))
    }

    var grouped: [String: [Sample]] = [:]
    for sample in samples {
        grouped["\(sample.side)\u{1f}\(sample.language)", default: []].append(sample)
    }
    return try grouped.values.map { group in
        guard let first = group.first else { preconditionFailure() }
        guard Set(group.map(\.dictionaryCount)).count == 1 else {
            throw AnalyzerError.invalid("Dictionary count changes across memory samples for side \(first.side), \(first.language)")
        }
        return MemoryResult(
            side: first.side,
            language: first.language,
            medianDeltaBytes: median(group.map { Double($0.delta) }),
            sampleCount: group.count,
            dictionaryCount: first.dictionaryCount
        )
    }.sorted {
        $0.language == $1.language ? $0.side < $1.side : $0.language < $1.language
    }
}

private func metadata(from document: TSVDocument) throws -> [String: String] {
    guard document.headers == ["key", "value"] else {
        throw AnalyzerError.invalid("metadata.tsv must contain key/value rows")
    }
    var values: [String: String] = [:]
    for (index, row) in document.rows.enumerated() {
        let key = try required("key", in: row, context: "metadata.tsv row \(index + 2)")
        guard values[key] == nil else {
            throw AnalyzerError.invalid("Duplicate metadata key: \(key)")
        }
        values[key] = row["value"] ?? ""
    }
    return values
}

private func validateCalibration(
    headers: [String],
    rows: [[String: String]],
    legs: [BlockLeg],
    preflights: [String: Preflight],
    profile: Profile
) throws -> [String: CalibratedWorkload] {
    let requiredHeaders: Set = [
        "workload", "operation", "operations", "supercycles", "target_ns", "base_cpu_ns", "compare_cpu_ns"
    ]
    let missingHeaders = requiredHeaders.subtracting(headers)
    guard missingHeaders.isEmpty else {
        throw AnalyzerError.invalid("calibration.tsv is missing columns: \(missingHeaders.sorted().joined(separator: ", "))")
    }

    var calibrated: [String: CalibratedWorkload] = [:]
    for (index, row) in rows.enumerated() {
        let context = "calibration.tsv row \(index + 2)"
        let workload = try required("workload", in: row, context: context)
        guard calibrated[workload] == nil else {
            throw AnalyzerError.invalid("Duplicate calibration workload: \(workload)")
        }
        guard let preflight = preflights[workload] else {
            throw AnalyzerError.invalid("Calibration contains unknown workload: \(workload)")
        }
        let operation = try required("operation", in: row, context: context)
        guard operation == preflight.operation else {
            throw AnalyzerError.invalid("Calibration operation mismatch for workload \(workload)")
        }
        let operations = try parseUInt64("operations", in: row, context: context, positive: true)
        let supercyclesRaw = try required("supercycles", in: row, context: context)
        guard let supercycles = Int(supercyclesRaw), supercycles > 0 else {
            throw AnalyzerError.invalid("Invalid supercycles in \(context): \(supercyclesRaw)")
        }
        let targetNanoseconds = try parseUInt64("target_ns", in: row, context: context, positive: true)
        let expected = try profile.samplingConfiguration(for: operation)
        guard supercycles == expected.supercycles, targetNanoseconds == expected.targetNanoseconds else {
            throw AnalyzerError.invalid("Calibration sampling does not match the \(profile.rawValue) profile for workload \(workload)")
        }
        for numericColumn in ["base_cpu_ns", "compare_cpu_ns"] {
            let verifiedNanoseconds = try parseUInt64(numericColumn, in: row, context: context, positive: true)
            let verificationTargetNanoseconds = UInt64((Double(targetNanoseconds) * 1.10).rounded(.up))
            guard verifiedNanoseconds >= verificationTargetNanoseconds else {
                throw AnalyzerError.invalid("Calibration did not reach its verification headroom in \(numericColumn) for workload \(workload)")
            }
        }
        calibrated[workload] = CalibratedWorkload(
            operations: operations,
            supercycles: supercycles,
            targetNanoseconds: targetNanoseconds
        )
    }
    guard Set(calibrated.keys) == Set(preflights.keys) else {
        throw AnalyzerError.invalid("Calibration profile and preflight workload sets differ")
    }
    for leg in legs {
        guard let calibration = calibrated[leg.workload], calibration.operations == leg.operations else {
            throw AnalyzerError.invalid("Measured operation count differs from frozen calibration for workload \(leg.workload)")
        }
    }
    return calibrated
}

private func buildMeasurements(
    legs: [BlockLeg],
    preflights: [String: Preflight],
    calibrated: [String: CalibratedWorkload]? = nil,
    expectedBlockCount: Int?
) throws -> ([ProcessMeasurement], [String: Int], [String: Int], [String: Int]) {
    guard !legs.isEmpty else { throw AnalyzerError.invalid("blocks.tsv contains no measured legs") }

    var legsByBlock: [Int: [BlockLeg]] = [:]
    var legsByWorkload: [String: [BlockLeg]] = [:]
    var grouped: [MeasurementKey: [BlockLeg]] = [:]
    for leg in legs {
        legsByBlock[leg.block, default: []].append(leg)
        legsByWorkload[leg.workload, default: []].append(leg)
        grouped[MeasurementKey(block: leg.block, workload: leg.workload), default: []].append(leg)
    }

    let blocks = Set(legsByBlock.keys)
    if let expectedBlockCount, blocks.count != expectedBlockCount {
        throw AnalyzerError.invalid("Profile requires \(expectedBlockCount) fresh-process blocks, got \(blocks.count)")
    }

    var phases: [String: Int] = [:]
    var moduleAssignments: [String: Int] = [:]
    var assignmentPhases: [String: Int] = [:]
    var blockCells: [Int: String] = [:]
    for block in blocks {
        guard let blockLegs = legsByBlock[block] else { preconditionFailure() }
        let blockPhases = Set(blockLegs.map(\.phase))
        guard
            blockPhases.count == 1,
            let phase = blockPhases.first,
            phase == "ABBA-first" || phase == "BAAB-first"
        else {
            throw AnalyzerError.invalid("Block \(block) must contain one ABBA-first or BAAB-first phase")
        }
        let primaryAssignments = Set(blockLegs.lazy.filter { $0.worker == 1 }.map(\.moduleAssignment))
        let pairedAssignments = Set(blockLegs.lazy.filter { $0.worker == 2 }.map(\.moduleAssignment))
        guard
            primaryAssignments.count == 1,
            pairedAssignments.count == 1,
            let assignment = primaryAssignments.first,
            let pairedAssignment = pairedAssignments.first,
            assignment == "normal" || assignment == "crossed",
            pairedAssignment == (assignment == "normal" ? "crossed" : "normal")
        else {
            throw AnalyzerError.invalid("Block \(block) must contain complementary primary and paired module assignments")
        }
        phases[phase, default: 0] += 1
        moduleAssignments[assignment, default: 0] += 1
        assignmentPhases["\(assignment)/\(phase)", default: 0] += 1
        blockCells[block] = "\(assignment)/\(phase)"
    }
    guard abs((phases["ABBA-first"] ?? 0) - (phases["BAAB-first"] ?? 0)) <= 1 else {
        throw AnalyzerError.invalid("Fresh-process phases are unbalanced")
    }
    guard abs((moduleAssignments["normal"] ?? 0) - (moduleAssignments["crossed"] ?? 0)) <= 1 else {
        throw AnalyzerError.invalid("Module assignments are unbalanced: normal=\(moduleAssignments["normal"] ?? 0), crossed=\(moduleAssignments["crossed"] ?? 0)")
    }
    for assignment in ["normal", "crossed"] {
        let abbaFirst = assignmentPhases["\(assignment)/ABBA-first"] ?? 0
        let baabFirst = assignmentPhases["\(assignment)/BAAB-first"] ?? 0
        guard abs(abbaFirst - baabFirst) <= 1 else {
            throw AnalyzerError.invalid("First orientations are unbalanced within the \(assignment) module assignment")
        }
    }
    if let expectedBlockCount {
        let expectedPerAssignment = expectedBlockCount / 2
        let expectedPerCell = expectedBlockCount / 4
        guard
            expectedBlockCount.isMultiple(of: 4),
            moduleAssignments["normal"] == expectedPerAssignment,
            moduleAssignments["crossed"] == expectedPerAssignment,
            assignmentPhases["normal/ABBA-first"] == expectedPerCell,
            assignmentPhases["normal/BAAB-first"] == expectedPerCell,
            assignmentPhases["crossed/ABBA-first"] == expectedPerCell,
            assignmentPhases["crossed/BAAB-first"] == expectedPerCell
        else {
            throw AnalyzerError.invalid("Profile requires balanced normal/crossed × first-orientation cells")
        }

        if expectedBlockCount >= 16 {
            guard blocks == Set(1...expectedBlockCount) else {
                throw AnalyzerError.invalid("Profile blocks must be numbered consecutively from 1 through \(expectedBlockCount)")
            }

            var positionSums: [String: Int] = [:]
            for (block, cell) in blockCells {
                positionSums[cell, default: 0] += block
            }
            guard
                let minimumPositionSum = positionSums.values.min(),
                let maximumPositionSum = positionSums.values.max(),
                maximumPositionSum - minimumPositionSum <= 1
            else {
                throw AnalyzerError.invalid("Process cells are confounded with measurement timeline position")
            }
        }
    }

    let workloads = Set(legsByWorkload.keys)
    for workload in workloads {
        guard let workloadLegs = legsByWorkload[workload] else { preconditionFailure() }
        guard Set(workloadLegs.map(\.operations)).count == 1 else {
            throw AnalyzerError.invalid("Operation count changes between blocks for workload \(workload)")
        }
        for side: Character in ["A", "B"] {
            let sideChecksums = Set(workloadLegs.lazy.filter { $0.side == side }.map(\.checksum))
            guard sideChecksums.count == 1 else {
                throw AnalyzerError.invalid("Checksum changes between blocks for workload \(workload), side \(side)")
            }
        }
        if preflights[workload]?.equal == true {
            guard Set(workloadLegs.map(\.checksum)).count == 1 else {
                throw AnalyzerError.invalid("Equal preflight produced different timed checksums between sides for workload \(workload)")
            }
        }
    }
    let expectedPairs = Set(blocks.flatMap { block in
        workloads.map { MeasurementKey(block: block, workload: $0) }
    })
    let actualPairs = Set(grouped.keys)
    let missingPairs = expectedPairs.subtracting(actualPairs)
    guard missingPairs.isEmpty else {
        throw AnalyzerError.invalid("Every workload must be present in every block; missing \(missingPairs.count) block/workload pair(s)")
    }

    var measurements: [ProcessMeasurement] = []
    var schedules: [String: Int] = [:]

    for key in grouped.keys.sorted(by: {
        $0.block == $1.block ? $0.workload < $1.workload : $0.block < $1.block
    }) {
        guard let group = grouped[key], let first = group.first else { preconditionFailure() }
        guard Set(group.map(\.operation)).count == 1 else {
            throw AnalyzerError.invalid("Operation changes within block \(first.block), workload \(first.workload)")
        }
        guard Set(group.map(\.operations)).count == 1 else {
            throw AnalyzerError.invalid("Operation count changes within block \(first.block), workload \(first.workload)")
        }
        guard let preflight = preflights[first.workload] else {
            throw AnalyzerError.invalid("Missing preflight result for workload \(first.workload)")
        }
        guard preflight.operation == first.operation else {
            throw AnalyzerError.invalid("Preflight operation does not match measured operation for workload \(first.workload)")
        }
        let primaryAssignments = Set(group.lazy.filter { $0.worker == 1 }.map(\.moduleAssignment))
        let pairedAssignments = Set(group.lazy.filter { $0.worker == 2 }.map(\.moduleAssignment))
        guard
            Set(group.map(\.phase)).count == 1,
            Set(group.map(\.worker)) == Set([1, 2]),
            primaryAssignments.count == 1,
            pairedAssignments.count == 1,
            let primaryAssignment = primaryAssignments.first,
            let pairedAssignment = pairedAssignments.first,
            pairedAssignment == (primaryAssignment == "normal" ? "crossed" : "normal")
        else {
            throw AnalyzerError.invalid("Block \(first.block), workload \(first.workload) must contain complementary module-paired workers")
        }

        let expectedSupercycles = calibrated?[first.workload]?.supercycles ?? (group.map(\.supercycle).max() ?? 0)
        guard expectedSupercycles > 0, Set(group.map(\.supercycle)) == Set(1...expectedSupercycles) else {
            throw AnalyzerError.invalid("Block \(first.block), workload \(first.workload) has incomplete supercycle indices")
        }
        let expectedLegCount = (expectedSupercycles + 1) * 8
        guard group.count == expectedLegCount else {
            throw AnalyzerError.invalid("Block \(first.block), workload \(first.workload) must have \(expectedLegCount) module-paired legs, got \(group.count)")
        }

        var supercycleValues: [Double] = []
        var orientationDeltas: [Double] = []
        var allBase: [BlockLeg] = []
        var allCompare: [BlockLeg] = []
        var moduleQuartetsBySupercycle: [Int: [String: [Double]]] = [:]
        var workersBySupercycle: [Int: [Int]] = [:]
        let bridgeSupercycle = expectedSupercycles / 2 + 1
        for supercycle in 1...expectedSupercycles {
            let supercycleLegs = group.filter { $0.supercycle == supercycle }
            let expectedWorkers = supercycle == bridgeSupercycle
                ? [1, 2]
                : supercycle < bridgeSupercycle ? [1] : [2]
            guard Set(supercycleLegs.map(\.worker)) == Set(expectedWorkers) else {
                throw AnalyzerError.invalid("Block \(first.block), workload \(first.workload), supercycle \(supercycle) has the wrong worker coverage")
            }
            let startsWithABBA = first.phase == "ABBA-first" ? supercycle.isMultiple(of: 2) == false : supercycle.isMultiple(of: 2)
            let expectedSchedules = startsWithABBA ? ["ABBA", "BAAB"] : ["BAAB", "ABBA"]

            var moduleQuartetValues: [String: [Double]] = [:]
            for worker in expectedWorkers {
                let workerLegs = supercycleLegs.filter { $0.worker == worker }
                guard workerLegs.count == 8 else {
                    throw AnalyzerError.invalid("Block \(first.block), workload \(first.workload), supercycle \(supercycle), worker \(worker) must have eight legs")
                }
                var observedSchedules: [String] = []
                for leg in workerLegs where observedSchedules.last != leg.schedule {
                    observedSchedules.append(leg.schedule)
                }
                guard observedSchedules == expectedSchedules else {
                    throw AnalyzerError.invalid("Block \(first.block), workload \(first.workload), supercycle \(supercycle), worker \(worker) has the wrong orientation order")
                }
                for schedule in expectedSchedules {
                    let quartet = workerLegs.filter { $0.schedule == schedule }.sorted { $0.position < $1.position }
                    guard quartet.count == 4, Set(quartet.map(\.position)) == Set(1...4) else {
                        throw AnalyzerError.invalid("Block \(first.block), workload \(first.workload), supercycle \(supercycle), worker \(worker), \(schedule) must contain positions 1 through 4")
                    }
                    guard quartet.map(\.side) == Array(schedule) else {
                        throw AnalyzerError.invalid("Block \(first.block), workload \(first.workload), supercycle \(supercycle), worker \(worker) legs do not match \(schedule)")
                    }
                    let base = quartet.filter { $0.side == "A" }
                    let compare = quartet.filter { $0.side == "B" }
                    guard base.count == 2, compare.count == 2 else {
                        throw AnalyzerError.invalid("Unbalanced quartet for block \(first.block), workload \(first.workload)")
                    }
                    let meanBaseLog = base.map { log(Double($0.cpuNanoseconds)) }.reduce(0, +) / 2
                    let meanCompareLog = compare.map { log(Double($0.cpuNanoseconds)) }.reduce(0, +) / 2
                    moduleQuartetValues[schedule, default: []].append(meanCompareLog - meanBaseLog)
                    allBase.append(contentsOf: base)
                    allCompare.append(contentsOf: compare)
                }
            }
            moduleQuartetsBySupercycle[supercycle] = moduleQuartetValues
            workersBySupercycle[supercycle] = expectedWorkers
        }

        guard
            let bridgeQuartets = moduleQuartetsBySupercycle[bridgeSupercycle],
            let bridgeABBA = bridgeQuartets["ABBA"], bridgeABBA.count == 2,
            let bridgeBAAB = bridgeQuartets["BAAB"], bridgeBAAB.count == 2
        else {
            preconditionFailure()
        }
        let moduleOffsets = [
            "ABBA": (bridgeABBA[0] - bridgeABBA[1]) / 2,
            "BAAB": (bridgeBAAB[0] - bridgeBAAB[1]) / 2
        ]
        for supercycle in 1...expectedSupercycles {
            guard
                let moduleQuartets = moduleQuartetsBySupercycle[supercycle],
                let workers = workersBySupercycle[supercycle]
            else {
                preconditionFailure()
            }
            var quartetValues: [String: Double] = [:]
            for schedule in ["ABBA", "BAAB"] {
                guard
                    let values = moduleQuartets[schedule],
                    values.count == workers.count,
                    let moduleOffset = moduleOffsets[schedule]
                else {
                    preconditionFailure()
                }
                let corrected = zip(workers, values).map { worker, value in
                    worker == 1 ? value - moduleOffset : value + moduleOffset
                }
                quartetValues[schedule] = corrected.reduce(0, +) / Double(corrected.count)
                schedules[schedule, default: 0] += 1
            }
            guard let abba = quartetValues["ABBA"], let baab = quartetValues["BAAB"] else {
                preconditionFailure()
            }
            supercycleValues.append((abba + baab) / 2)
            orientationDeltas.append(abba - baab)
        }

        guard schedules["ABBA", default: 0] == schedules["BAAB", default: 0] else {
            throw AnalyzerError.invalid("Timed ABBA and BAAB quartets are unbalanced")
        }
        let operations = Double(first.operations)
        let processValue = try trimmedMean(supercycleValues)
        let orientationDelta = try trimmedMean(orientationDeltas)
        let baseTotalCPUNanoseconds = allBase.reduce(0.0) { $0 + Double($1.cpuNanoseconds) }
        let compareTotalCPUNanoseconds = allCompare.reduce(0.0) { $0 + Double($1.cpuNanoseconds) }
        if let calibration = calibrated?[first.workload] {
            let minimumTotalCPU = Double(calibration.targetNanoseconds) * Double(calibration.supercycles * 4)
            guard
                baseTotalCPUNanoseconds >= minimumTotalCPU,
                compareTotalCPUNanoseconds >= minimumTotalCPU
            else {
                throw AnalyzerError.invalid("Timed CPU budget is below target for block \(first.block), workload \(first.workload)")
            }
        }
        measurements.append(ProcessMeasurement(
            block: first.block,
            workload: first.workload,
            z: processValue,
            baseNormalizedCPU: median(allBase.map { Double($0.cpuNanoseconds) / operations }),
            compareNormalizedCPU: median(allCompare.map { Double($0.cpuNanoseconds) / operations }),
            baseTotalCPUNanoseconds: baseTotalCPUNanoseconds,
            compareTotalCPUNanoseconds: compareTotalCPUNanoseconds,
            baseWallCPURatio: median(allBase.map { Double($0.wallNanoseconds) / Double($0.cpuNanoseconds) }),
            compareWallCPURatio: median(allCompare.map { Double($0.wallNanoseconds) / Double($0.cpuNanoseconds) }),
            withinProcessScaledMAD: scaledMAD(supercycleValues),
            orientationDelta: orientationDelta,
            supercycleCount: expectedSupercycles,
            legCount: group.count
        ))
    }

    let unexpectedPreflights = Set(preflights.keys).subtracting(workloads)
    guard unexpectedPreflights.isEmpty else {
        throw AnalyzerError.invalid("Preflight contains unmeasured workloads: \(unexpectedPreflights.sorted().joined(separator: ", "))")
    }
    return (measurements, schedules, phases, moduleAssignments)
}

private func median(_ values: [Double]) -> Double {
    precondition(!values.isEmpty)
    let sorted = values.sorted()
    if sorted.count.isMultiple(of: 2) {
        return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
    }
    return sorted[sorted.count / 2]
}

private func trimmedMean(_ values: [Double]) throws -> Double {
    guard !values.isEmpty else {
        throw AnalyzerError.invalid("Cannot estimate an empty measurement set")
    }
    let sorted = values.sorted()
    let trimCount = Int(floor(0.2 * Double(sorted.count)))
    let retained = sorted[trimCount..<sorted.count - trimCount]
    guard !retained.isEmpty else {
        throw AnalyzerError.invalid("Too few measurements remain after trimming")
    }
    return retained.reduce(0, +) / Double(retained.count)
}

private func scaledMAD(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let middle = median(values)
    return median(values.map { abs($0 - middle) }) * 1.4826
}

private func betaContinuedFraction(a: Double, b: Double, x: Double) -> Double {
    let maximumIterations = 200
    let epsilon = 3e-14
    let minimum = 1e-300
    let qab = a + b
    let qap = a + 1
    let qam = a - 1
    var c = 1.0
    var d = 1 - qab * x / qap
    if abs(d) < minimum {
        d = minimum
    }
    d = 1 / d
    var result = d

    for iteration in 1...maximumIterations {
        let m = Double(iteration)
        let m2 = 2 * m
        var aa = m * (b - m) * x / ((qam + m2) * (a + m2))
        d = 1 + aa * d
        if abs(d) < minimum {
            d = minimum
        }
        c = 1 + aa / c
        if abs(c) < minimum {
            c = minimum
        }
        d = 1 / d
        result *= d * c

        aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))
        d = 1 + aa * d
        if abs(d) < minimum {
            d = minimum
        }
        c = 1 + aa / c
        if abs(c) < minimum {
            c = minimum
        }
        d = 1 / d
        let delta = d * c
        result *= delta
        if abs(delta - 1) < epsilon {
            break
        }
    }
    return result
}

private func regularizedIncompleteBeta(x: Double, a: Double, b: Double) -> Double {
    if x <= 0 {
        return 0
    }
    if x >= 1 {
        return 1
    }
    let factor = exp(lgamma(a + b) - lgamma(a) - lgamma(b) + a * log(x) + b * log1p(-x))
    if x < (a + 1) / (a + b + 2) {
        return factor * betaContinuedFraction(a: a, b: b, x: x) / a
    }
    return 1 - factor * betaContinuedFraction(a: b, b: a, x: 1 - x) / b
}

private func studentTCDF(_ value: Double, degreesOfFreedom: Int) -> Double {
    let degrees = Double(degreesOfFreedom)
    let x = degrees / (degrees + value * value)
    let tail = 0.5 * regularizedIncompleteBeta(x: x, a: degrees / 2, b: 0.5)
    return value >= 0 ? 1 - tail : tail
}

private func studentTCritical95(degreesOfFreedom: Int) -> Double {
    precondition(degreesOfFreedom > 0)
    var lower = 0.0
    var upper = 1.0
    while studentTCDF(upper, degreesOfFreedom: degreesOfFreedom) < 0.975 {
        upper *= 2
    }
    for _ in 0..<80 {
        let midpoint = (lower + upper) / 2
        if studentTCDF(midpoint, degreesOfFreedom: degreesOfFreedom) < 0.975 {
            lower = midpoint
        } else {
            upper = midpoint
        }
    }
    return (lower + upper) / 2
}

private func estimate(_ values: [Double]) throws -> Estimate {
    guard values.count >= 2 else {
        throw AnalyzerError.invalid("At least two process measurements are required for an estimate")
    }
    let sorted = values.sorted()
    let trimCount = Int(floor(0.2 * Double(sorted.count)))
    let retained = Array(sorted[trimCount..<sorted.count - trimCount])
    guard retained.count >= 2 else {
        throw AnalyzerError.invalid("Too few measurements remain after trimming")
    }
    let center = retained.reduce(0, +) / Double(retained.count)

    let low = sorted[trimCount]
    let high = sorted[sorted.count - trimCount - 1]
    let winsorized = sorted.enumerated().map { index, value in
        if index < trimCount {
            return low
        }
        if index >= sorted.count - trimCount {
            return high
        }
        return value
    }
    let winsorizedMean = winsorized.reduce(0, +) / Double(winsorized.count)
    let sumSquares = winsorized.reduce(0) { $0 + ($1 - winsorizedMean) * ($1 - winsorizedMean) }
    let standardError = sqrt(sumSquares / (Double(retained.count) * Double(retained.count - 1)))
    let critical = studentTCritical95(degreesOfFreedom: retained.count - 1)

    let middle = median(sorted)
    let mad = scaledMAD(sorted)
    return Estimate(
        center: center,
        lower: center - critical * standardError,
        upper: center + critical * standardError,
        median: middle,
        scaledMAD: mad,
        minimum: sorted[0],
        maximum: sorted[sorted.count - 1],
        trimCount: trimCount
    )
}

private func percent(_ logRatio: Double) -> Double {
    expm1(logRatio) * 100
}

private func hasUnstableOrderEffect(_ estimate: Estimate?) -> Bool {
    guard let estimate else { return false }
    let center = abs(percent(estimate.center))
    let excludesZero = estimate.lower > 0 || estimate.upper < 0
    return center > 0.5 && excludesZero
}

private func classify(
    estimate: Estimate?,
    orientationEstimate: Estimate?,
    comparable: Bool,
    profile: Profile
) -> Classification {
    guard comparable else { return .notComparable }
    guard profile.allowsVerdict, let estimate else { return .notEvaluated }
    if hasUnstableOrderEffect(orientationEstimate) {
        return .unstableOrderEffect
    }
    let center = percent(estimate.center)
    let lower = percent(estimate.lower)
    let upper = percent(estimate.upper)
    if center >= 1, lower > 0 {
        return .regression
    }
    if center <= -1, upper < 0 {
        return .improvement
    }
    if lower >= -1, upper <= 1 {
        return .equivalent
    }
    return .inconclusive
}

private func unselectedClassification(comparable: Bool) -> Classification {
    comparable ? .notEvaluated : .notComparable
}

private func aggregateMeasurements(
    _ measurements: [ProcessMeasurement],
    block: Int,
    name: String
) -> ProcessMeasurement {
    precondition(!measurements.isEmpty)
    var z = 0.0
    var baseNormalizedCPU = 0.0
    var compareNormalizedCPU = 0.0
    var baseTotalCPUNanoseconds = 0.0
    var compareTotalCPUNanoseconds = 0.0
    var baseWallCPURatio = 0.0
    var compareWallCPURatio = 0.0
    var withinProcessScaledMAD = 0.0
    var orientationDelta = 0.0
    var supercycleCount = 0
    var legCount = 0

    for measurement in measurements {
        z += measurement.z
        baseNormalizedCPU += measurement.baseNormalizedCPU
        compareNormalizedCPU += measurement.compareNormalizedCPU
        baseTotalCPUNanoseconds += measurement.baseTotalCPUNanoseconds
        compareTotalCPUNanoseconds += measurement.compareTotalCPUNanoseconds
        baseWallCPURatio += measurement.baseWallCPURatio
        compareWallCPURatio += measurement.compareWallCPURatio
        withinProcessScaledMAD += measurement.withinProcessScaledMAD
        orientationDelta += measurement.orientationDelta
        supercycleCount += measurement.supercycleCount
        legCount += measurement.legCount
    }

    let count = Double(measurements.count)
    return ProcessMeasurement(
        block: block,
        workload: name,
        z: z / count,
        baseNormalizedCPU: baseNormalizedCPU / count,
        compareNormalizedCPU: compareNormalizedCPU / count,
        baseTotalCPUNanoseconds: baseTotalCPUNanoseconds,
        compareTotalCPUNanoseconds: compareTotalCPUNanoseconds,
        baseWallCPURatio: baseWallCPURatio / count,
        compareWallCPURatio: compareWallCPURatio / count,
        withinProcessScaledMAD: withinProcessScaledMAD / count,
        orientationDelta: orientationDelta / count,
        supercycleCount: supercycleCount,
        legCount: legCount
    )
}

private func analyze(
    legs: [BlockLeg],
    preflights: [String: Preflight],
    metadata: [String: String],
    calibrationHeaders: [String],
    calibrationRows: [[String: String]],
    memoryResults: [MemoryResult]?,
    profile: Profile,
    enforceProfileBlockCount: Bool
) throws -> Analysis {
    let calibrated = try validateCalibration(
        headers: calibrationHeaders,
        rows: calibrationRows,
        legs: legs,
        preflights: preflights,
        profile: profile
    )
    let (measurements, schedules, phases, moduleAssignments) = try buildMeasurements(
        legs: legs,
        preflights: preflights,
        calibrated: calibrated,
        expectedBlockCount: enforceProfileBlockCount ? profile.expectedBlockCount : nil
    )
    let blocks = Set(legs.map(\.block))

    switch metadata["inputs"] {
    case "matching":
        break
    case "shared-base", "shared-compare":
        if let changed = preflights.values.first(where: { !$0.equal }) {
            throw AnalyzerError.invalid("Shared-input preflight mismatch for workload \(changed.workload)")
        }
    default:
        throw AnalyzerError.invalid("Missing or invalid inputs mode in metadata.tsv")
    }

    let orderedPreflights = preflights.values.sorted(by: preflightPrecedes)
    var workloadResults: [ResultRow] = []
    for preflight in orderedPreflights {
        let workload = preflight.workload
        let samples = measurements.filter { $0.workload == workload }.sorted { $0.block < $1.block }
        guard samples.count == blocks.count else {
            throw AnalyzerError.invalid("Workload \(workload) has \(samples.count) process measurements, expected \(blocks.count)")
        }
        let value = try estimate(samples.map(\.z))
        let orientationEstimate = try estimate(samples.map(\.orientationDelta))
        let preflightStatus = preflight.equal ? PreflightStatus.equal : .changed
        workloadResults.append(ResultRow(
            name: workload,
            kind: "workload",
            operation: preflight.operation,
            language: preflight.language,
            preflight: preflightStatus,
            estimate: value,
            processCount: samples.count,
            legCount: samples.reduce(0) { $0 + $1.legCount },
            baseNormalizedCPU: median(samples.map(\.baseNormalizedCPU)),
            compareNormalizedCPU: median(samples.map(\.compareNormalizedCPU)),
            baseTotalCPUNanoseconds: median(samples.map(\.baseTotalCPUNanoseconds)),
            compareTotalCPUNanoseconds: median(samples.map(\.compareTotalCPUNanoseconds)),
            baseWallCPURatio: median(samples.map(\.baseWallCPURatio)),
            compareWallCPURatio: median(samples.map(\.compareWallCPURatio)),
            withinProcessScaledMAD: median(samples.map(\.withinProcessScaledMAD)),
            orientationEstimate: orientationEstimate,
            supercycleCount: samples.reduce(0) { $0 + $1.supercycleCount },
            classification: unselectedClassification(comparable: preflight.equal)
        ))
    }

    var operationResults: [ResultRow] = []
    let operations = Set(preflights.values.map(\.operation))
    for operation in operations.sorted(by: operationPrecedes) {
        let operationPreflights = preflights.values.filter { $0.operation == operation }
        let comparableWorkloads = Set(operationPreflights.filter(\.equal).map(\.workload))
        let status: PreflightStatus = comparableWorkloads.count == operationPreflights.count
            ? .equal
            : comparableWorkloads.isEmpty
            ? .changed
            : .partial(equal: comparableWorkloads.count, total: operationPreflights.count)

        var processSamples: [ProcessMeasurement] = []
        if !comparableWorkloads.isEmpty {
            for block in blocks.sorted() {
                let included = measurements.filter { $0.block == block && comparableWorkloads.contains($0.workload) }
                guard included.count == comparableWorkloads.count else {
                    throw AnalyzerError.invalid("Operation \(operation), block \(block) does not contain every comparable workload")
                }
                processSamples.append(aggregateMeasurements(included, block: block, name: operation))
            }
        }

        let value: Estimate?
        let orientationEstimate: Estimate?
        if processSamples.isEmpty {
            value = nil
            orientationEstimate = nil
        } else {
            value = try estimate(processSamples.map(\.z))
            orientationEstimate = try estimate(processSamples.map(\.orientationDelta))
        }
        operationResults.append(ResultRow(
            name: operation,
            kind: "operation",
            operation: operation,
            language: nil,
            preflight: status,
            estimate: value,
            processCount: processSamples.count,
            legCount: processSamples.reduce(0) { $0 + $1.legCount },
            baseNormalizedCPU: processSamples.isEmpty ? nil : median(processSamples.map(\.baseNormalizedCPU)),
            compareNormalizedCPU: processSamples.isEmpty ? nil : median(processSamples.map(\.compareNormalizedCPU)),
            baseTotalCPUNanoseconds: processSamples.isEmpty ? nil : median(processSamples.map(\.baseTotalCPUNanoseconds)),
            compareTotalCPUNanoseconds: processSamples.isEmpty ? nil : median(processSamples.map(\.compareTotalCPUNanoseconds)),
            baseWallCPURatio: processSamples.isEmpty ? nil : median(processSamples.map(\.baseWallCPURatio)),
            compareWallCPURatio: processSamples.isEmpty ? nil : median(processSamples.map(\.compareWallCPURatio)),
            withinProcessScaledMAD: processSamples.isEmpty ? nil : median(processSamples.map(\.withinProcessScaledMAD)),
            orientationEstimate: orientationEstimate,
            supercycleCount: processSamples.reduce(0) { $0 + $1.supercycleCount },
            classification: unselectedClassification(comparable: status.comparable)
        ))
    }

    let comparableOverallWorkloads = Set(preflights.values.filter(\.equal).map(\.workload))
    let overallPreflight: PreflightStatus = comparableOverallWorkloads.count == preflights.count
        ? .equal
        : comparableOverallWorkloads.isEmpty
        ? .changed
        : .partial(equal: comparableOverallWorkloads.count, total: preflights.count)
    var overallProcessSamples: [ProcessMeasurement] = []
    if !comparableOverallWorkloads.isEmpty {
        for block in blocks.sorted() {
            let included = measurements.filter {
                $0.block == block && comparableOverallWorkloads.contains($0.workload)
            }
            guard included.count == comparableOverallWorkloads.count else {
                throw AnalyzerError.invalid("Overall aggregate, block \(block) does not contain every comparable workload")
            }
            overallProcessSamples.append(aggregateMeasurements(included, block: block, name: "overall"))
        }
    }
    let overallEstimate: Estimate?
    let overallOrientationEstimate: Estimate?
    if overallProcessSamples.isEmpty {
        overallEstimate = nil
        overallOrientationEstimate = nil
    } else {
        overallEstimate = try estimate(overallProcessSamples.map(\.z))
        overallOrientationEstimate = try estimate(overallProcessSamples.map(\.orientationDelta))
    }
    let overallResult = ResultRow(
        name: "overall",
        kind: "overall",
        operation: "overall",
        language: nil,
        preflight: overallPreflight,
        estimate: overallEstimate,
        processCount: overallProcessSamples.count,
        legCount: overallProcessSamples.reduce(0) { $0 + $1.legCount },
        baseNormalizedCPU: nil,
        compareNormalizedCPU: nil,
        baseTotalCPUNanoseconds: overallProcessSamples.isEmpty ? nil : median(overallProcessSamples.map(\.baseTotalCPUNanoseconds)),
        compareTotalCPUNanoseconds: overallProcessSamples.isEmpty ? nil : median(overallProcessSamples.map(\.compareTotalCPUNanoseconds)),
        baseWallCPURatio: nil,
        compareWallCPURatio: nil,
        withinProcessScaledMAD: overallProcessSamples.isEmpty ? nil : median(overallProcessSamples.map(\.withinProcessScaledMAD)),
        orientationEstimate: overallOrientationEstimate,
        supercycleCount: overallProcessSamples.reduce(0) { $0 + $1.supercycleCount },
        classification: unselectedClassification(comparable: overallPreflight.comparable)
    )

    let verdict = profile.allowsVerdict
        ? classify(
            estimate: overallResult.estimate,
            orientationEstimate: overallResult.orientationEstimate,
            comparable: overallResult.preflight.comparable,
            profile: profile
        )
        : nil

    return Analysis(
        profile: profile,
        verdict: verdict,
        metadata: metadata,
        calibrationHeaders: calibrationHeaders,
        calibrationRows: calibrationRows,
        blockCount: blocks.count,
        supercycleCount: measurements.reduce(0) { $0 + $1.supercycleCount },
        legCount: legs.count,
        schedules: schedules,
        phases: phases,
        moduleAssignments: moduleAssignments,
        thermalStates: Set(legs.flatMap { [$0.thermalBefore, $0.thermalAfter] }).sorted(),
        lowPowerObserved: legs.contains(where: \.lowPower),
        preflights: orderedPreflights,
        overallResult: overallResult,
        workloadResults: workloadResults,
        operationResults: operationResults,
        memoryResults: memoryResults
    )
}

private func number(_ value: Double?) -> Any {
    value.map { NSNumber(value: $0) } ?? NSNull()
}

private func resultJSON(_ result: ResultRow) -> [String: Any] {
    var object: [String: Any] = [
        "name": result.name,
        "kind": result.kind,
        "operation": result.operation,
        "language": result.language ?? NSNull(),
        "preflight": result.preflight.label,
        "classification": result.classification.rawValue,
        "processes": result.processCount,
        "replicates": result.processCount,
        "cycles": result.supercycleCount,
        "supercycles": result.supercycleCount,
        "legs": result.legCount,
        "absoluteCPU": [
            "baseNanosecondsPerOperation": number(result.baseNormalizedCPU),
            "compareNanosecondsPerOperation": number(result.compareNormalizedCPU),
            "baseTimedNanosecondsPerProcess": number(result.baseTotalCPUNanoseconds),
            "compareTimedNanosecondsPerProcess": number(result.compareTotalCPUNanoseconds),
            "baseWallCPURatio": number(result.baseWallCPURatio),
            "compareWallCPURatio": number(result.compareWallCPURatio)
        ]
    ]
    if let estimate = result.estimate {
        object["paired"] = [
            "estimatePercent": percent(estimate.center),
            "confidenceInterval95Percent": ["lower": percent(estimate.lower), "upper": percent(estimate.upper)],
            "medianPercent": percent(estimate.median),
            "scaledMADPercent": percent(estimate.scaledMAD),
            "rangePercent": ["minimum": percent(estimate.minimum), "maximum": percent(estimate.maximum)],
            "trimmedProcessesPerTail": estimate.trimCount
        ]
    } else {
        object["paired"] = NSNull()
    }
    let orientationBias: Any = if let estimate = result.orientationEstimate {
        [
            "estimatePercent": percent(estimate.center),
            "confidenceInterval95Percent": ["lower": percent(estimate.lower), "upper": percent(estimate.upper)],
            "scaledMADPercent": percent(estimate.scaledMAD)
        ]
    } else {
        NSNull()
    }
    object["quality"] = [
        "withinProcessScaledMADPercent": number(result.withinProcessScaledMAD.map(percent)),
        "orientationBiasABBAminusBAAB": orientationBias,
        "unstableOrderEffect": hasUnstableOrderEffect(result.orientationEstimate)
    ]
    return object
}

private func summaryJSON(_ analysis: Analysis) -> [String: Any] {
    let primary: Any = if let verdict = analysis.verdict {
        [
            "name": analysis.overallResult.name,
            "kind": analysis.overallResult.kind,
            "verdict": verdict.rawValue
        ]
    } else {
        NSNull()
    }
    return [
        "schemaVersion": 2,
        "generatedAt": ISO8601DateFormatter().string(from: Date()),
        "profile": analysis.profile.rawValue,
        "practicalMarginPercent": 1.0,
        "primary": primary,
        "metadata": analysis.metadata,
        "calibration": [
            "headers": analysis.calibrationHeaders,
            "recordCount": analysis.calibrationRows.count,
            "records": analysis.calibrationRows
        ],
        "preflight": analysis.preflights.map { preflight in
            [
                "workload": preflight.workload,
                "operation": preflight.operation,
                "language": preflight.language,
                "baseDigest": preflight.baseDigest,
                "compareDigest": preflight.compareDigest,
                "baseCount": preflight.baseCount,
                "compareCount": preflight.compareCount,
                "equal": preflight.equal
            ] as [String: Any]
        },
        "integrity": [
            "processes": analysis.blockCount,
            "replicateGroups": analysis.blockCount,
            "freshWorkerProcesses": analysis.blockCount * analysis.preflights.count * 2,
            "workerProcessesPerReplicate": analysis.preflights.count * 2,
            "supercycles": analysis.supercycleCount,
            "legs": analysis.legCount,
            "schedules": analysis.schedules,
            "phases": analysis.phases,
            "moduleAssignments": analysis.moduleAssignments,
            "thermalStates": analysis.thermalStates,
            "lowPowerModeObserved": analysis.lowPowerObserved,
            "changedOutputWorkloads": analysis.workloadResults.filter { !$0.preflight.comparable }.map(\.name)
        ],
        "retainedMemory": analysis.memoryResults.map { results in
            results.map { result in
                [
                    "side": String(result.side),
                    "language": result.language,
                    "medianDeltaBytes": result.medianDeltaBytes,
                    "samples": result.sampleCount,
                    "dictionaryCount": result.dictionaryCount
                ] as [String: Any]
            }
        } ?? NSNull(),
        "results": [
            "overall": resultJSON(analysis.overallResult),
            "operations": analysis.operationResults.map(resultJSON),
            "workloads": analysis.workloadResults.map(resultJSON)
        ]
    ]
}

private func signedNumber(_ value: Double, decimals: Int) -> String {
    let scale = pow(10, Double(decimals))
    let rounded = (value * scale).rounded() / scale
    return String(format: "%+.\(decimals)f", rounded == 0 ? 0 : rounded)
}

private func displayPercent(_ value: Double, decimals: Int = 3) -> String {
    "\(signedNumber(value, decimals: decimals))%"
}

private func displayInterval(_ estimate: Estimate, decimals: Int = 2) -> String {
    "\(displayPercent(percent(estimate.lower), decimals: decimals)) … \(displayPercent(percent(estimate.upper), decimals: decimals))"
}

private func leftAligned(_ value: String, width: Int) -> String {
    value + String(repeating: " ", count: max(0, width - value.count))
}

private func rightAligned(_ value: String, width: Int) -> String {
    String(repeating: " ", count: max(0, width - value.count)) + value
}

private enum ColumnAlignment {
    case left
    case right
}

private func alignedTable(headers: [String], rows: [[String]], alignments: [ColumnAlignment]) -> [String] {
    let widths = headers.indices.map { column in
        ([headers] + rows).map { $0[column].count }.max() ?? 0
    }
    func line(_ cells: [String]) -> String {
        var text = "  " + cells.enumerated().map { column, cell in
            alignments[column] == .left
                ? leftAligned(cell, width: widths[column])
                : rightAligned(cell, width: widths[column])
        }.joined(separator: "  ")
        while text.last == " " {
            text.removeLast()
        }
        return text
    }
    return [line(headers)] + rows.map(line)
}

private struct VerdictHeadline {
    let title: String
    let explanation: String
}

private func verdictHeadline(_ analysis: Analysis) -> VerdictHeadline {
    switch analysis.verdict {
    case nil, .notEvaluated:
        VerdictHeadline(
            title: "not evaluated (\(analysis.profile.rawValue) profile)",
            explanation: "This profile reports no verdict; use the default decision profile for one."
        )
    case .regression:
        VerdictHeadline(
            title: "REGRESSION",
            explanation: "Compare is slower: the estimate is at least +1% and the interval excludes zero."
        )
    case .improvement:
        VerdictHeadline(
            title: "IMPROVEMENT",
            explanation: "Compare is faster: the estimate is at most -1% and the interval excludes zero."
        )
    case .equivalent:
        VerdictHeadline(
            title: "EQUIVALENT",
            explanation: "No practical difference: the whole interval lies within the ±1% margin."
        )
    case .inconclusive:
        VerdictHeadline(
            title: "INCONCLUSIVE",
            explanation: "The interval crosses the ±1% margin without showing a 1% change; re-run with --profile confirm."
        )
    case .unstableOrderEffect:
        VerdictHeadline(
            title: "UNSTABLE ORDER EFFECT",
            explanation: "ABBA and BAAB orders differ by more than 0.5%; re-run on an idle machine on AC power."
        )
    case .notComparable:
        VerdictHeadline(
            title: "NOT COMPARABLE",
            explanation: "Every workload produced different output, so no timing can be compared."
        )
    }
}

private func dictionaryLabel(_ language: String) -> String {
    switch language {
    case "en_GB_CSW": "CSW"
    case "en_US_NWL": "NWL"
    case "en_WOW": "WOW"
    case "fr_ODS": "ODS"
    case "pl_OSPS": "OSPS"
    default: language
    }
}

private struct PairedTiming {
    let base: String
    let compare: String
}

private func pairedTiming(for result: ResultRow) -> PairedTiming? {
    guard
        let estimate = result.estimate,
        let observedBase = result.baseNormalizedCPU,
        let observedCompare = result.compareNormalizedCPU,
        observedBase > 0,
        observedCompare > 0
    else {
        return nil
    }

    let ratio = exp(estimate.center)
    let midpoint = sqrt(observedBase * observedCompare)
    let pairedBase = midpoint / sqrt(ratio)
    let pairedCompare = midpoint * sqrt(ratio)
    let scale: (divisor: Double, unit: String) = if midpoint >= 1_000_000 {
        (1_000_000, "ms")
    } else if midpoint >= 1_000 {
        (1_000, "µs")
    } else {
        (1, "ns")
    }
    let scaledMidpoint = midpoint / scale.divisor
    let decimals = scaledMidpoint >= 100 ? 1 : scaledMidpoint >= 10 ? 2 : 3

    return PairedTiming(
        base: "\(String(format: "%.\(decimals)f", pairedBase / scale.divisor)) \(scale.unit)",
        compare: "\(String(format: "%.\(decimals)f", pairedCompare / scale.divisor)) \(scale.unit)"
    )
}

private func comparisonCells(for result: ResultRow) -> [String] {
    let timing = pairedTiming(for: result)
    return [
        timing?.base ?? "n/a",
        timing?.compare ?? "n/a",
        result.estimate.map { displayPercent(percent($0.center), decimals: 2) } ?? "n/a",
        result.estimate.map { displayInterval($0) } ?? "n/a"
    ]
}

private func operationRows(_ analysis: Analysis) -> [[String]] {
    analysis.operationResults.map { result in
        [result.preflight.comparable ? result.name : "\(result.name)*"] + comparisonCells(for: result)
    }
}

private func workloadLanguages(_ analysis: Analysis) -> [String] {
    var languages: [String] = []
    for language in analysis.workloadResults.compactMap(\.language) where !languages.contains(language) {
        languages.append(language)
    }
    return languages
}

private struct WorkloadGrid {
    let headers: [String]
    let rows: [[String]]
    let hasChangedOutput: Bool
}

private func workloadGrid(_ analysis: Analysis) -> WorkloadGrid {
    let languages = workloadLanguages(analysis)
    let rows = analysis.operationResults.map(\.operation).map { operation in
        [operation] + languages.map { language in
            guard
                let result = analysis.workloadResults.first(where: {
                    $0.operation == operation && $0.language == language
                })
            else {
                return "—"
            }
            guard result.preflight.comparable else { return "changed*" }
            guard let estimate = result.estimate else { return "n/a" }
            let halfWidth = (percent(estimate.upper) - percent(estimate.lower)) / 2
            return "\(signedNumber(percent(estimate.center), decimals: 1)) ±\(String(format: "%.1f", halfWidth))"
        }
    }
    return WorkloadGrid(
        headers: ["Operation"] + languages.map(dictionaryLabel),
        rows: rows,
        hasChangedOutput: analysis.workloadResults.contains { !$0.preflight.comparable }
    )
}

private struct MemoryRow {
    let language: String
    let base: MemoryResult?
    let compare: MemoryResult?

    var deltaBytes: Double? {
        guard let base, let compare else { return nil }
        return compare.medianDeltaBytes - base.medianDeltaBytes
    }
}

private func memoryRows(_ results: [MemoryResult], analysis: Analysis) -> [MemoryRow] {
    let resultsByLanguage = Dictionary(grouping: results, by: \.language)
    let knownLanguages = workloadLanguages(analysis).filter { resultsByLanguage[$0] != nil }
    let otherLanguages = resultsByLanguage.keys.filter { !knownLanguages.contains($0) }.sorted()
    return (knownLanguages + otherLanguages).map { language in
        let languageResults = resultsByLanguage[language, default: []]
        return MemoryRow(
            language: language,
            base: languageResults.first { $0.side == "A" },
            compare: languageResults.first { $0.side == "B" }
        )
    }
}

private func mebibytes(_ bytes: Double?, signed: Bool = false) -> String {
    bytes.map { signed ? signedNumber($0 / 1_048_576, decimals: 3) : String(format: "%.3f", $0 / 1_048_576) } ?? "n/a"
}

private struct HealthItem {
    let label: String
    let value: String
    let warning: Bool
}

private func runHealthItems(_ analysis: Analysis) -> [HealthItem] {
    let overall = analysis.overallResult
    return [
        HealthItem(
            label: "thermal",
            value: analysis.thermalStates.joined(separator: "/"),
            warning: analysis.thermalStates.contains { $0 != "nominal" }
        ),
        HealthItem(
            label: "Low Power Mode",
            value: analysis.lowPowerObserved ? "on" : "off",
            warning: analysis.lowPowerObserved
        ),
        HealthItem(
            label: "order bias",
            value: overall.orientationEstimate.map { displayPercent(percent($0.center), decimals: 2) } ?? "n/a",
            warning: hasUnstableOrderEffect(overall.orientationEstimate)
        ),
        HealthItem(
            label: "within-process noise",
            value: overall.withinProcessScaledMAD.map { String(format: "%.2f%%", percent($0)) } ?? "n/a",
            warning: false
        )
    ]
}

private func markdownEscape(_ value: String) -> String {
    value.replacingOccurrences(of: "|", with: "\\|")
}

private func markdownTable(headers: [String], rows: [[String]], alignments: [ColumnAlignment]) -> [String] {
    [
        "| \(headers.map(markdownEscape).joined(separator: " | ")) |",
        "| \(alignments.map { $0 == .left ? "---" : "---:" }.joined(separator: " | ")) |"
    ] + rows.map { "| \($0.map(markdownEscape).joined(separator: " | ")) |" }
}

private func reportMarkdown(_ analysis: Analysis) -> String {
    let metadata = analysis.metadata
    let baseRef = metadata["base_ref"] ?? "unknown"
    let compareRef = metadata["compare_ref"] ?? "unknown"
    let headline = verdictHeadline(analysis)
    let overall = analysis.overallResult
    let processCount = analysis.blockCount * analysis.preflights.count * 2
    let comparisonAlignments: [ColumnAlignment] = [.left, .right, .right, .right, .right]

    var lines: [String] = [
        "# DAWG Performance: `\(baseRef)` → `\(compareRef)`",
        ""
    ]
    if metadata["diagnostic_snapshot"] == "1" {
        lines += [
            "> **Diagnostic snapshot:** use this invocation only for local inspection. Results from separate invocations are not comparable.",
            ""
        ]
    }
    let overallText = overall.estimate.map {
        "overall \(displayPercent(percent($0.center), decimals: 2)) (95% CI \(displayInterval($0)))"
    } ?? "overall n/a"
    lines += [
        "**Verdict: \(headline.title)** — \(overallText). \(headline.explanation)",
        "",
        "## Run",
        ""
    ]
    lines += markdownTable(
        headers: ["", "Base", "Compare"],
        rows: [
            ["Ref", "`\(baseRef)`", "`\(compareRef)`"],
            ["DAWG format", "`\(metadata["base_format"] ?? "unknown")`", "`\(metadata["compare_format"] ?? "unknown")`"]
        ],
        alignments: [.left, .left, .left]
    )
    lines += [
        "",
        "- Profile: `\(analysis.profile.rawValue)` · \(analysis.blockCount) replicates · \(processCount) fresh worker processes",
        "- Inputs: `\(metadata["inputs"] ?? "matching")`"
    ]
    let machine = ["hardware_model", "cpu_model"].compactMap { metadata[$0] }
        + [metadata["macos"].map { "macOS \($0)" }, metadata["xcode"].map { "Xcode \($0)" }].compactMap { $0 }
    if !machine.isEmpty {
        lines.append("- Machine: \(machine.joined(separator: " · "))")
    }

    lines += [
        "",
        "## Results",
        "",
        "CPU time per operation. Negative change means compare is faster.",
        "",
        "### By operation",
        ""
    ]
    lines += markdownTable(
        headers: ["Operation", "Base", "Compare", "Change", "95% CI"],
        rows: operationRows(analysis),
        alignments: comparisonAlignments
    )
    let grid = workloadGrid(analysis)
    lines += [
        "",
        "### By workload",
        "",
        "Change in %, ± 95% CI half-width.",
        ""
    ]
    lines += markdownTable(
        headers: grid.headers,
        rows: grid.rows,
        alignments: [.left] + Array(repeating: .right, count: grid.headers.count - 1)
    )
    if grid.hasChangedOutput {
        lines += ["", "\\* Changed output: timed end to end but excluded from operation and overall estimates."]
    }
    lines += ["", "<details>", "<summary>Workload timings</summary>", ""]
    lines += markdownTable(
        headers: ["Workload", "Dictionary", "Base", "Compare", "Change", "95% CI", "Output"],
        rows: analysis.workloadResults.map { result in
            [result.name, result.language.map(dictionaryLabel) ?? "n/a"]
                + comparisonCells(for: result)
                + [result.preflight.comparable ? "equal" : "changed"]
        },
        alignments: [.left, .left, .right, .right, .right, .right, .left]
    )
    lines += ["", "</details>"]

    lines += ["", "## Run health", ""]
    for item in runHealthItems(analysis) {
        let label = item.label.prefix(1).uppercased() + item.label.dropFirst()
        lines.append("- \(label): \(item.value)\(item.warning ? " — **warning**" : "")")
    }
    let changed = analysis.workloadResults.filter { !$0.preflight.comparable }.map(\.name)
    if !changed.isEmpty {
        lines.append("- Changed-output workloads: \(changed.map { "`\(markdownEscape($0))`" }.joined(separator: ", "))")
    }

    lines += [
        "",
        "## Retained memory",
        "",
        "Median fresh-process physical-footprint delta after loading each dictionary. Diagnostic only; it never affects the verdict.",
        ""
    ]
    if let memoryResults = analysis.memoryResults {
        lines += markdownTable(
            headers: ["Dictionary", "Base (MiB)", "Compare (MiB)", "Delta (MiB)", "Samples A/B", "Words"],
            rows: memoryRows(memoryResults, analysis: analysis).map { row in
                let words = [row.base, row.compare].compactMap { $0 }.map(\.dictionaryCount)
                return [
                    dictionaryLabel(row.language),
                    mebibytes(row.base?.medianDeltaBytes),
                    mebibytes(row.compare?.medianDeltaBytes),
                    mebibytes(row.deltaBytes, signed: true),
                    "\(row.base.map { String($0.sampleCount) } ?? "-")/\(row.compare.map { String($0.sampleCount) } ?? "-")",
                    Set(words).count == 1 ? String(words[0]) : words.map(String.init).joined(separator: "/")
                ]
            },
            alignments: [.left, .right, .right, .right, .right, .right]
        )
    } else {
        lines.append("_Retained-memory probe was not requested._")
    }

    lines += [
        "",
        "## How to read",
        "",
        "- **Change** compares paired thread CPU time of compare against base; negative means compare is faster.",
        "- **95% CI** is the one-sample Yuen interval of the 20% trimmed mean across replicates.",
        "- **Verdict** uses only the `overall` estimate against a ±1% practical margin; per-operation and per-workload rows are diagnostic.",
        "- **Base/Compare** times are paired estimates from this run. Never compare absolute timings across runs, machines, or toolchains.",
        "",
        "<details>",
        "<summary>Statistical diagnostics</summary>",
        "",
        "Each workload replicate pairs fresh normal and crossed workers. They split the locally balanced ABBA+BAAB supercycles and both measure the bridge supercycle, whose module-specific values are averaged. The workload value is the 20% trimmed mean of logical supercycles. Aggregate metrics then average workload values within the same replicate index, and the run estimate uses a 20% trimmed mean with a one-sample 95% Yuen interval.",
        "",
        "- Harness fingerprint: `\(String((metadata["harness_hash"] ?? "unknown").prefix(12)))`",
        "- Replicate groups / logical supercycles / measured legs: \(analysis.blockCount) / \(analysis.supercycleCount) / \(analysis.legCount)",
        "- Timed quartets: ABBA \(analysis.schedules["ABBA"] ?? 0), BAAB \(analysis.schedules["BAAB"] ?? 0)",
        "- First-orientation phases: ABBA-first \(analysis.phases["ABBA-first"] ?? 0), BAAB-first \(analysis.phases["BAAB-first"] ?? 0)",
        "- Module assignments: normal \(analysis.moduleAssignments["normal"] ?? 0), crossed \(analysis.moduleAssignments["crossed"] ?? 0)",
        "- Calibration records: \(analysis.calibrationRows.count)",
        ""
    ]
    lines += markdownTable(
        headers: [
            "Metric", "Estimate", "95% CI", "Replicate MAD", "Within-process MAD", "ABBA − BAAB",
            "Timed CPU A/B", "Preflight", "N (replicates/supercycles)"
        ],
        rows: analysis.displayedResults.map { result in
            let orientationText = result.orientationEstimate.map {
                "\(displayPercent(percent($0.center))) [\(displayPercent(percent($0.lower))), \(displayPercent(percent($0.upper)))]"
            } ?? "n/a"
            let totalCPUText = if
                let base = result.baseTotalCPUNanoseconds,
                let compare = result.compareTotalCPUNanoseconds
            {
                String(format: "%.1f/%.1f ms", base / 1_000_000, compare / 1_000_000)
            } else {
                "n/a"
            }
            return [
                result.name,
                result.estimate.map { displayPercent(percent($0.center)) } ?? "n/a",
                result.estimate.map { displayInterval($0, decimals: 3) } ?? "n/a",
                result.estimate.map { displayPercent(percent($0.scaledMAD)) } ?? "n/a",
                result.withinProcessScaledMAD.map { displayPercent(percent($0)) } ?? "n/a",
                orientationText,
                totalCPUText,
                result.preflight.label,
                "\(result.processCount)/\(result.supercycleCount)"
            ]
        },
        alignments: [.left, .right, .right, .right, .right, .right, .right, .left, .right]
    )
    lines += [""]
    lines += markdownTable(
        headers: ["Metric", "Median", "Range", "Trimmed per tail", "Base (ns/op)", "Compare (ns/op)", "Base wall/CPU", "Compare wall/CPU"],
        rows: analysis.displayedResults.map { result in
            func display(_ value: Double?) -> String {
                value.map { String(format: "%.3f", $0) } ?? "n/a"
            }
            return [
                result.name,
                result.estimate.map { displayPercent(percent($0.median)) } ?? "n/a",
                result.estimate.map { "\(displayPercent(percent($0.minimum))) … \(displayPercent(percent($0.maximum)))" } ?? "n/a",
                result.estimate.map { String($0.trimCount) } ?? "n/a",
                display(result.baseNormalizedCPU),
                display(result.compareNormalizedCPU),
                display(result.baseWallCPURatio),
                display(result.compareWallCPURatio)
            ]
        },
        alignments: [.left, .right, .right, .right, .right, .right, .right, .right]
    )
    lines += ["", "</details>", ""]
    return lines.joined(separator: "\n")
}

private func conciseText(_ analysis: Analysis, outputDirectory: URL) -> String {
    let metadata = analysis.metadata
    let headline = verdictHeadline(analysis)
    let processCount = analysis.blockCount * analysis.preflights.count * 2
    var lines: [String] = [
        "DAWG performance: \(metadata["base_ref"] ?? "unknown") (\(metadata["base_format"] ?? "unknown")) → \(metadata["compare_ref"] ?? "unknown") (\(metadata["compare_format"] ?? "unknown"))",
        "\(analysis.profile.rawValue) profile · \(analysis.blockCount) replicates (\(processCount) processes) · \(metadata["inputs"] ?? "matching") inputs"
    ]
    if metadata["diagnostic_snapshot"] == "1" {
        lines.append("DIAGNOSTIC SNAPSHOT: use only for local inspection; separate invocations are not comparable.")
    }

    lines += ["", "Verdict: \(headline.title)"]
    if let estimate = analysis.overallResult.estimate {
        lines.append("  overall \(displayPercent(percent(estimate.center), decimals: 2))  95% CI \(displayInterval(estimate))")
    }
    lines.append("  \(headline.explanation)")

    lines += ["", "By operation (CPU time per operation; negative change = compare is faster)"]
    lines += alignedTable(
        headers: ["Operation", "Base", "Compare", "Change", "95% CI"],
        rows: operationRows(analysis),
        alignments: [.left, .right, .right, .right, .right]
    )

    let grid = workloadGrid(analysis)
    lines += ["", "Change by workload (%, ± 95% CI half-width)"]
    lines += alignedTable(
        headers: grid.headers,
        rows: grid.rows,
        alignments: [.left] + Array(repeating: .right, count: grid.headers.count - 1)
    )
    if grid.hasChangedOutput {
        lines.append("  * changed output: excluded from operation and overall estimates")
    }

    if let memoryResults = analysis.memoryResults {
        let rows = memoryRows(memoryResults, analysis: analysis)
        let sampleCounts = Set(memoryResults.map(\.sampleCount))
        let samplesText = sampleCounts.count == 1
            ? "median of \(sampleCounts.first!) fresh-process sample\(sampleCounts.first! == 1 ? "" : "s")"
            : "median of fresh-process samples"
        lines += ["", "Retained memory (MiB, \(samplesText); diagnostic only)"]
        lines += alignedTable(
            headers: ["Dictionary", "Base", "Compare", "Delta"],
            rows: rows.map { row in
                [
                    dictionaryLabel(row.language),
                    mebibytes(row.base?.medianDeltaBytes),
                    mebibytes(row.compare?.medianDeltaBytes),
                    mebibytes(row.deltaBytes, signed: true)
                ]
            },
            alignments: [.left, .right, .right, .right]
        )
    }

    let healthItems = runHealthItems(analysis)
    lines += [
        "",
        "Run health: " + healthItems.map { "\($0.warning ? "! " : "")\($0.label) \($0.value)" }.joined(separator: " · ")
    ]
    if healthItems.contains(where: \.warning) {
        lines.append("  ! may distort timings; consider re-running")
    }
    if metadata["artifacts_persisted"] == "false" {
        lines.append("Detailed artifacts: not saved (use --save-artifacts or --output-dir DIR)")
    } else {
        lines += [
            "Details: \(outputDirectory.appendingPathComponent("report.md").path)",
            "Data:    \(outputDirectory.appendingPathComponent("summary.json").path)"
        ]
    }
    return lines.joined(separator: "\n")
}

private func parseOptions(_ arguments: [String]) throws -> Options {
    var inputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    var outputDirectory: URL?
    var profile: Profile?
    var format = OutputFormat.text
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        func nextValue() throws -> String {
            guard index + 1 < arguments.count else { throw AnalyzerError.usage("\(argument) requires a value") }
            index += 1
            return arguments[index]
        }
        switch argument {
        case "--input-dir": inputDirectory = try URL(fileURLWithPath: nextValue())
        case "--output-dir": outputDirectory = try URL(fileURLWithPath: nextValue())
        case "--profile":
            let raw = try nextValue()
            guard let parsedProfile = Profile(rawValue: raw) else { throw AnalyzerError.usage("Unknown profile: \(raw)") }
            profile = parsedProfile
        case "--format":
            let raw = try nextValue()
            guard let parsedFormat = OutputFormat(rawValue: raw) else { throw AnalyzerError.usage("Unknown output format: \(raw)") }
            format = parsedFormat
        case "-h", "--help": throw AnalyzerError.usage(usage)
        default: throw AnalyzerError.usage("Unknown argument: \(argument)")
        }
        index += 1
    }
    return Options(
        inputDirectory: inputDirectory,
        outputDirectory: outputDirectory ?? inputDirectory,
        profile: profile,
        format: format
    )
}

private let usage = """
Usage: Analyzer [--input-dir DIR] [--output-dir DIR]
                [--profile decision|quick|confirm]
                [--format text|markdown|none]
       Analyzer --self-test

Reads preflight.tsv, calibration.tsv, blocks.tsv, and metadata.tsv. Every normal
run writes summary.json and report.md. Markdown format also prints report.md;
text prints a concise summary.
"""

private func run(options: Options) throws {
    let input = options.inputDirectory.standardizedFileURL
    let output = options.outputDirectory.standardizedFileURL
    let blockDocument = try TSVDocument(url: input.appendingPathComponent("blocks.tsv"), requiredHeaders: blocksHeaders)
    let preflightDocument = try TSVDocument(url: input.appendingPathComponent("preflight.tsv"), requiredHeaders: preflightHeaders)
    let calibrationDocument = try TSVDocument(url: input.appendingPathComponent("calibration.tsv"))
    let metadataDocument = try TSVDocument(url: input.appendingPathComponent("metadata.tsv"))
    let memoryURL = input.appendingPathComponent("memory.tsv")
    let memoryResults: [MemoryResult]? = if FileManager.default.fileExists(atPath: memoryURL.path) {
        try readMemory(from: TSVDocument(url: memoryURL, requiredHeaders: memoryHeaders))
    } else {
        nil
    }
    let metadataValues = try metadata(from: metadataDocument)
    guard metadataValues["schema_version"] == "2" else {
        throw AnalyzerError.invalid("metadata.tsv must declare schema_version 2")
    }
    let profile: Profile = if let requested = options.profile {
        requested
    } else if let raw = metadataValues["profile"], let recorded = Profile(rawValue: raw) {
        recorded
    } else {
        throw AnalyzerError.invalid("Missing or invalid profile in metadata.tsv")
    }

    let analysis = try analyze(
        legs: readLegs(from: blockDocument),
        preflights: readPreflights(from: preflightDocument),
        metadata: metadataValues,
        calibrationHeaders: calibrationDocument.headers,
        calibrationRows: calibrationDocument.rows,
        memoryResults: memoryResults,
        profile: profile,
        enforceProfileBlockCount: true
    )
    let json = try JSONSerialization.data(withJSONObject: summaryJSON(analysis), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    let markdown = reportMarkdown(analysis)

    do {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try json.write(to: output.appendingPathComponent("summary.json"), options: .atomic)
        try Data(markdown.utf8).write(to: output.appendingPathComponent("report.md"), options: .atomic)
    } catch {
        throw AnalyzerError.invalid("Could not write analysis artifacts to \(output.path): \(error.localizedDescription)")
    }

    switch options.format {
    case .text: print(conciseText(analysis, outputDirectory: output))
    case .markdown: print(markdown, terminator: "")
    case .none: break
    }
}

private func testLegs(
    ratios: [Double],
    supercycles: Int,
    includeChanged: Bool = false,
    orientationBias: Double = 0,
    moduleBias: Double = 0,
    balancesTimeline: Bool = true
) -> ([BlockLeg], [String: Preflight]) {
    let workloads = includeChanged ? [("contains-en", true), ("contains-fr", false)] : [("contains-en", true)]
    let cells = [
        (phase: "ABBA-first", assignment: "normal"),
        (phase: "BAAB-first", assignment: "crossed"),
        (phase: "ABBA-first", assignment: "crossed"),
        (phase: "BAAB-first", assignment: "normal")
    ]
    let timelineBalancedCells = [
        cells[0], cells[1], cells[2], cells[3],
        cells[3], cells[2], cells[1], cells[0],
        cells[0], cells[1], cells[2], cells[3],
        cells[3], cells[2], cells[1], cells[0],
        cells[0], cells[1], cells[2], cells[3],
        cells[3], cells[2], cells[1], cells[0],
        cells[0], cells[1], cells[2], cells[3],
        cells[3], cells[2], cells[1], cells[0]
    ]
    let selectedCells = balancesTimeline ? timelineBalancedCells : cells
    var legs: [BlockLeg] = []
    for (blockIndex, ratio) in ratios.enumerated() {
        let cell = selectedCells[blockIndex % selectedCells.count]
        for (workload, outputsEqual) in workloads {
            let base = workload == "contains-en" ? 20_000_000.0 : 30_000_000.0
            for supercycle in 1...supercycles {
                let bridgeSupercycle = supercycles / 2 + 1
                let workers = supercycle == bridgeSupercycle
                    ? [1, 2]
                    : supercycle < bridgeSupercycle ? [1] : [2]
                let startsWithABBA = cell.phase == "ABBA-first"
                    ? !supercycle.isMultiple(of: 2)
                    : supercycle.isMultiple(of: 2)
                let schedules = startsWithABBA ? ["ABBA", "BAAB"] : ["BAAB", "ABBA"]
                for worker in workers {
                    let assignment = worker == 1
                        ? cell.assignment
                        : cell.assignment == "normal" ? "crossed" : "normal"
                    for schedule in schedules {
                        let scheduleRatio = ratio
                            * exp(schedule == "ABBA" ? orientationBias / 2 : -orientationBias / 2)
                            * exp(worker == 1 ? moduleBias / 2 : -moduleBias / 2)
                        for (position, side) in Array(schedule).enumerated() {
                            let cpu = side == "A" ? base : base * scheduleRatio
                            legs.append(BlockLeg(
                                block: blockIndex + 1, phase: cell.phase,
                                moduleAssignment: assignment, worker: worker, supercycle: supercycle,
                                schedule: schedule, position: position + 1,
                                workload: workload, operation: "contains", side: side,
                                cpuNanoseconds: UInt64(cpu.rounded()), wallNanoseconds: UInt64((cpu * 1.1).rounded()),
                                checksum: outputsEqual ? "equal-\(workload)" : "\(side)-\(workload)", operations: 1,
                                thermalBefore: "nominal", thermalAfter: "nominal", lowPower: false
                            ))
                        }
                    }
                }
            }
        }
    }
    let preflights = Dictionary(uniqueKeysWithValues: workloads.map { workload, equal in
        (workload, Preflight(
            workload: workload, operation: "contains", language: workload.hasSuffix("en") ? "en" : "fr",
            baseDigest: "a", compareDigest: equal ? "a" : "b", baseCount: 1, compareCount: 1, equal: equal
        ))
    })
    return (legs, preflights)
}

private func replacing(
    _ leg: BlockLeg,
    phase: String? = nil,
    moduleAssignment: String? = nil,
    worker: Int? = nil,
    supercycle: Int? = nil,
    schedule: String? = nil,
    position: Int? = nil,
    side: Character? = nil,
    cpuNanoseconds: UInt64? = nil,
    wallNanoseconds: UInt64? = nil,
    checksum: String? = nil,
    operations: UInt64? = nil
) -> BlockLeg {
    BlockLeg(
        block: leg.block,
        phase: phase ?? leg.phase,
        moduleAssignment: moduleAssignment ?? leg.moduleAssignment,
        worker: worker ?? leg.worker,
        supercycle: supercycle ?? leg.supercycle,
        schedule: schedule ?? leg.schedule,
        position: position ?? leg.position,
        workload: leg.workload,
        operation: leg.operation,
        side: side ?? leg.side,
        cpuNanoseconds: cpuNanoseconds ?? leg.cpuNanoseconds,
        wallNanoseconds: wallNanoseconds ?? leg.wallNanoseconds,
        checksum: checksum ?? leg.checksum,
        operations: operations ?? leg.operations,
        thermalBefore: leg.thermalBefore,
        thermalAfter: leg.thermalAfter,
        lowPower: leg.lowPower
    )
}

private func testCalibration(
    preflights: [String: Preflight],
    profile: Profile
) throws -> (headers: [String], rows: [[String: String]]) {
    let headers = ["workload", "operation", "operations", "supercycles", "target_ns", "base_cpu_ns", "compare_cpu_ns"]
    let rows = try preflights.values.map { preflight in
        let configuration = try profile.samplingConfiguration(for: preflight.operation)
        return [
            "workload": preflight.workload,
            "operation": preflight.operation,
            "operations": "1",
            "supercycles": String(configuration.supercycles),
            "target_ns": String(configuration.targetNanoseconds),
            "base_cpu_ns": String(configuration.targetNanoseconds * 2),
            "compare_cpu_ns": String(configuration.targetNanoseconds * 2)
        ]
    }
    return (headers, rows)
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw AnalyzerError.invalid("Self-test failed: \(message)") }
}

private func expectFailure(_ message: String, _ body: () throws -> Void) throws {
    do {
        try body()
    } catch is AnalyzerError {
        return
    } catch {
        throw AnalyzerError.invalid("Self-test failed with unexpected error for \(message): \(error)")
    }
    throw AnalyzerError.invalid("Self-test failed: expected failure for \(message)")
}

private func runSelfTests() throws {
    try expect(
        ["pattern", "contains", "load", "words"].sorted(by: operationPrecedes) == operationPresentationOrder,
        "results use the workload presentation order"
    )
    let (balancedLegs, preflights) = testLegs(
        ratios: [1.1, 1.1, 1.1, 1.1],
        supercycles: 3
    )
    let (measurements, schedules, phases, moduleAssignments) = try buildMeasurements(
        legs: balancedLegs,
        preflights: preflights,
        expectedBlockCount: 4
    )
    try expect(measurements.count == 4, "supercycles produce one sample per process/workload")
    try expect(abs(measurements[0].z - log(1.1)) < 0.006, "paired log ratio")
    try expect(measurements[0].supercycleCount == 3, "process sample records supercycles")
    try expect(measurements[0].legCount == 32, "bridge supercycle is measured in both module workers")
    try expect(abs(measurements[0].orientationDelta) < 1e-12, "balanced orientations cancel locally")
    try expect(measurements[0].baseTotalCPUNanoseconds == 320_000_000, "total timed CPU is recorded per side")
    try expect(schedules == ["ABBA": 12, "BAAB": 12], "balanced timed quartets")
    try expect(phases == ["ABBA-first": 2, "BAAB-first": 2], "balanced first-orientation phases")
    try expect(moduleAssignments == ["normal": 2, "crossed": 2], "balanced module assignments")

    let (moduleBiasedLegs, moduleBiasedPreflights) = testLegs(
        ratios: [1.1, 1.1, 1.1, 1.1],
        supercycles: 3,
        moduleBias: log(1.3)
    )
    let (moduleCorrected, _, _, _) = try buildMeasurements(
        legs: moduleBiasedLegs,
        preflights: moduleBiasedPreflights,
        expectedBlockCount: 4
    )
    try expect(abs(moduleCorrected[0].z - log(1.1)) < 1e-7, "bridge correction removes persistent local module bias")
    try expect(moduleCorrected[0].withinProcessScaledMAD < 1e-7, "module correction aligns split supercycles")

    let quickBalancedCalibration = try testCalibration(preflights: preflights, profile: .quick)
    var oneShortLeg = balancedLegs
    oneShortLeg[0] = replacing(
        oneShortLeg[0],
        cpuNanoseconds: 8_000_000,
        wallNanoseconds: 8_800_000
    )
    _ = try analyze(
        legs: oneShortLeg,
        preflights: preflights,
        metadata: ["inputs": "matching"],
        calibrationHeaders: quickBalancedCalibration.headers,
        calibrationRows: quickBalancedCalibration.rows,
        memoryResults: nil,
        profile: .quick,
        enforceProfileBlockCount: true
    )
    let insufficientTotalCPU = balancedLegs.map {
        replacing($0, cpuNanoseconds: 6_000_000, wallNanoseconds: 6_600_000)
    }
    try expectFailure("insufficient aggregate timed CPU") {
        _ = try analyze(
            legs: insufficientTotalCPU,
            preflights: preflights,
            metadata: ["inputs": "matching"],
            calibrationHeaders: quickBalancedCalibration.headers,
            calibrationRows: quickBalancedCalibration.rows,
            memoryResults: nil,
            profile: .quick,
            enforceProfileBlockCount: true
        )
    }

    let decisionRatios = [Double](repeating: 1, count: 16)
    let (timelineBalancedLegs, timelinePreflights) = testLegs(ratios: decisionRatios, supercycles: 7)
    _ = try buildMeasurements(
        legs: timelineBalancedLegs,
        preflights: timelinePreflights,
        expectedBlockCount: 16
    )
    let (confirmTimelineLegs, confirmTimelinePreflights) = testLegs(
        ratios: [Double](repeating: 1, count: 32),
        supercycles: 7
    )
    _ = try buildMeasurements(
        legs: confirmTimelineLegs,
        preflights: confirmTimelinePreflights,
        expectedBlockCount: 32
    )
    let (timelineConfoundedLegs, _) = testLegs(
        ratios: decisionRatios,
        supercycles: 7,
        balancesTimeline: false
    )
    try expectFailure("timeline-confounded process cells") {
        _ = try buildMeasurements(
            legs: timelineConfoundedLegs,
            preflights: timelinePreflights,
            expectedBlockCount: 16
        )
    }

    var locallyRobustLegs = timelineBalancedLegs
    for index in locallyRobustLegs.indices where
        locallyRobustLegs[index].block == 1
        && locallyRobustLegs[index].supercycle == 7
        && locallyRobustLegs[index].side == "B"
    {
        let leg = locallyRobustLegs[index]
        locallyRobustLegs[index] = replacing(
            leg,
            cpuNanoseconds: leg.cpuNanoseconds * 10,
            wallNanoseconds: leg.wallNanoseconds * 10
        )
    }
    let (locallyRobust, _, _, _) = try buildMeasurements(
        legs: locallyRobustLegs,
        preflights: timelinePreflights,
        expectedBlockCount: 16
    )
    try expect(abs(locallyRobust.first { $0.block == 1 }!.z) < 1e-12, "one extreme supercycle is trimmed within a process")

    let robust = try estimate([-100, 1, 2, 3, 100])
    try expect(abs(robust.center - 2) < 1e-12, "20% trimmed mean")
    try expect(abs(robust.median - 2) < 1e-12, "median")
    try expect(abs(robust.scaledMAD - 1.4826) < 1e-12, "scaled MAD")
    let yuenHalfWidth = 4.302_652_729_75 * sqrt(2.0 / 3.0)
    try expect(abs(robust.lower - (2 - yuenHalfWidth)) < 1e-9, "Yuen lower confidence bound")
    try expect(abs(robust.upper - (2 + yuenHalfWidth)) < 1e-9, "Yuen upper confidence bound")
    try expect(abs(studentTCritical95(degreesOfFreedom: 3) - 3.182446) < 0.00001, "Student t critical value")

    let regression = Estimate(center: log(1.02), lower: log(1.005), upper: log(1.03), median: 0, scaledMAD: 0, minimum: 0, maximum: 0, trimCount: 3)
    let improvement = Estimate(center: log(0.98), lower: log(0.97), upper: log(0.995), median: 0, scaledMAD: 0, minimum: 0, maximum: 0, trimCount: 3)
    let equivalent = Estimate(center: 0, lower: log(0.995), upper: log(1.005), median: 0, scaledMAD: 0, minimum: 0, maximum: 0, trimCount: 3)
    let uncertain = Estimate(center: log(1.02), lower: log(0.99), upper: log(1.04), median: 0, scaledMAD: 0, minimum: 0, maximum: 0, trimCount: 3)
    let unstableOrder = Estimate(center: log(1.01), lower: log(1.006), upper: log(1.014), median: 0, scaledMAD: 0, minimum: 0, maximum: 0, trimCount: 3)
    try expect(classify(estimate: regression, orientationEstimate: nil, comparable: true, profile: .decision) == .regression, "regression status")
    try expect(classify(estimate: improvement, orientationEstimate: nil, comparable: true, profile: .decision) == .improvement, "improvement status")
    try expect(classify(estimate: equivalent, orientationEstimate: nil, comparable: true, profile: .decision) == .equivalent, "equivalence status")
    try expect(classify(estimate: uncertain, orientationEstimate: nil, comparable: true, profile: .decision) == .inconclusive, "inconclusive status")
    try expect(classify(estimate: regression, orientationEstimate: unstableOrder, comparable: true, profile: .decision) == .unstableOrderEffect, "unstable order effect suppresses verdict")
    try expect(classify(estimate: regression, orientationEstimate: nil, comparable: false, profile: .decision) == .notComparable, "noncomparable status")
    try expect(classify(estimate: regression, orientationEstimate: unstableOrder, comparable: true, profile: .quick) == .notEvaluated, "quick profile status")

    var missing = balancedLegs
    missing.removeLast()
    try expectFailure("missing leg") { _ = try buildMeasurements(legs: missing, preflights: preflights, expectedBlockCount: nil) }

    var duplicated = balancedLegs
    duplicated.append(balancedLegs[0])
    try expectFailure("duplicated leg") { _ = try buildMeasurements(legs: duplicated, preflights: preflights, expectedBlockCount: nil) }

    var missingBridgeWorker = balancedLegs
    missingBridgeWorker.removeAll { $0.block == 1 && $0.supercycle == 2 && $0.worker == 2 }
    try expectFailure("missing bridge module worker") {
        _ = try buildMeasurements(legs: missingBridgeWorker, preflights: preflights, expectedBlockCount: nil)
    }

    let unbalancedSchedules = balancedLegs.map { leg in
        leg.schedule == "BAAB" ? replacing(leg, schedule: "ABBA") : leg
    }
    try expectFailure("missing BAAB quartets") {
        _ = try buildMeasurements(legs: unbalancedSchedules, preflights: preflights, expectedBlockCount: nil)
    }

    let unbalancedAssignments = balancedLegs.map { leg in
        replacing(leg, moduleAssignment: "normal")
    }
    try expectFailure("unbalanced module assignments") {
        _ = try buildMeasurements(legs: unbalancedAssignments, preflights: preflights, expectedBlockCount: nil)
    }

    var unbalanced = balancedLegs
    let original = unbalanced[0]
    unbalanced[0] = replacing(original, side: "B")
    try expectFailure("unbalanced legs") { _ = try buildMeasurements(legs: unbalanced, preflights: preflights, expectedBlockCount: nil) }

    var inconsistent = balancedLegs
    inconsistent[3] = replacing(inconsistent[3], checksum: "changed")
    try expectFailure("checksum inconsistency") { _ = try buildMeasurements(legs: inconsistent, preflights: preflights, expectedBlockCount: nil) }

    var crossBlockChecksum = balancedLegs
    for index in crossBlockChecksum.indices where crossBlockChecksum[index].block == 2 && crossBlockChecksum[index].side == "A" {
        let leg = crossBlockChecksum[index]
        crossBlockChecksum[index] = replacing(leg, checksum: "cross-block-change")
    }
    try expectFailure("cross-block checksum inconsistency") {
        _ = try buildMeasurements(legs: crossBlockChecksum, preflights: preflights, expectedBlockCount: nil)
    }

    let crossSideChecksum = balancedLegs.map { leg in
        leg.side == "B" ? replacing(leg, checksum: "different-side") : leg
    }
    try expectFailure("cross-side checksum mismatch for equal output") {
        _ = try buildMeasurements(legs: crossSideChecksum, preflights: preflights, expectedBlockCount: nil)
    }

    var crossBlockOperations = balancedLegs
    for index in crossBlockOperations.indices where crossBlockOperations[index].block == 2 {
        let leg = crossBlockOperations[index]
        crossBlockOperations[index] = replacing(leg, operations: 2)
    }
    try expectFailure("cross-block operation-count inconsistency") {
        _ = try buildMeasurements(legs: crossBlockOperations, preflights: preflights, expectedBlockCount: nil)
    }

    var missingSupercycle = balancedLegs
    missingSupercycle.removeAll { $0.block == 1 && $0.supercycle == 3 }
    try expectFailure("missing whole supercycle") {
        _ = try buildMeasurements(
            legs: missingSupercycle,
            preflights: preflights,
            calibrated: ["contains-en": CalibratedWorkload(operations: 1, supercycles: 3, targetNanoseconds: 9_000_000)],
            expectedBlockCount: nil
        )
    }

    let (changedLegs, changedPreflights) = testLegs(
        ratios: [1.1, 1.1, 1.1, 1.1],
        supercycles: 3,
        includeChanged: true
    )
    let quickCalibration = try testCalibration(preflights: changedPreflights, profile: .quick)
    let changedAnalysis = try analyze(
        legs: changedLegs, preflights: changedPreflights, metadata: ["inputs": "matching"],
        calibrationHeaders: quickCalibration.headers, calibrationRows: quickCalibration.rows,
        memoryResults: [
            MemoryResult(side: "A", language: "en", medianDeltaBytes: 1_048_576, sampleCount: 3, dictionaryCount: 42),
            MemoryResult(side: "B", language: "en", medianDeltaBytes: 1_572_864, sampleCount: 3, dictionaryCount: 42)
        ],
        profile: .quick, enforceProfileBlockCount: false
    )
    try expect(changedAnalysis.verdict == nil, "quick profile has no run-level verdict")
    try expect(changedAnalysis.operationResults[0].preflight.label == "partial (1/2 equal)", "changed output excluded from aggregate")
    let expectedComparableZ = try estimate(measurements.map(\.z))
    try expect(abs(changedAnalysis.operationResults[0].estimate!.center - expectedComparableZ.center) < 1e-12, "aggregate includes comparable workload only")
    try expect(changedAnalysis.overallResult.preflight.label == "partial (1/2 equal)", "overall records partial preflight")
    try expect(abs(changedAnalysis.overallResult.estimate!.center - expectedComparableZ.center) < 1e-12, "overall excludes changed output")
    let summary = summaryJSON(changedAnalysis)
    try expect(JSONSerialization.isValidJSONObject(summary), "summary JSON is serializable")
    let integrity = summary["integrity"] as? [String: Any]
    try expect(integrity?["freshWorkerProcesses"] as? Int == 16, "summary reports fresh module-paired workload processes")
    let absoluteCPU = resultJSON(changedAnalysis.workloadResults[0])["absoluteCPU"] as? [String: Any]
    try expect(absoluteCPU?["baseTimedNanosecondsPerProcess"] is NSNumber, "summary reports total timed CPU per side")
    _ = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
    let markdown = reportMarkdown(changedAnalysis)
    try expect(markdown.contains("## Retained memory") && markdown.contains("| en | 1.000 | 1.500 | +0.500 | 3/3 | 42 |"), "Markdown pivots retained memory by dictionary")
    try expect(markdown.contains("<summary>Statistical diagnostics</summary>"), "Markdown collapses statistical diagnostics")
    try expect(markdown.contains("**Verdict: not evaluated (quick profile)**"), "Markdown leads with the verdict")
    try expect(!markdown.contains("| Status |"), "main table omits per-result status")
    let memoryText = conciseText(changedAnalysis, outputDirectory: URL(fileURLWithPath: "/tmp"))
    try expect(memoryText.contains("Retained memory (MiB, median of 3 fresh-process samples; diagnostic only)"), "text prints retained-memory diagnostics")
    try expect(memoryText.contains("1.000") && memoryText.contains("1.500"), "text prints retained memory for both sides")
    try expect(memoryText.contains("+0.500"), "text prints retained-memory delta")

    let diagnosticAnalysis = try analyze(
        legs: changedLegs,
        preflights: changedPreflights,
        metadata: ["inputs": "matching", "diagnostic_snapshot": "1", "artifacts_persisted": "false"],
        calibrationHeaders: quickCalibration.headers,
        calibrationRows: quickCalibration.rows,
        memoryResults: nil,
        profile: .quick,
        enforceProfileBlockCount: false
    )
    try expect(reportMarkdown(diagnosticAnalysis).contains("**Diagnostic snapshot:**"), "Markdown labels diagnostic snapshots")
    let diagnosticText = conciseText(diagnosticAnalysis, outputDirectory: URL(fileURLWithPath: "/tmp"))
    try expect(diagnosticText.contains("DIAGNOSTIC SNAPSHOT"), "text labels diagnostic snapshots")
    try expect(diagnosticText.contains("By operation") && diagnosticText.contains("Change by workload"), "text prints comparison tables")
    try expect(diagnosticText.contains("Base") && diagnosticText.contains("Compare") && diagnosticText.contains("Change"), "text prints comparison columns")
    try expect(diagnosticText.contains("changed*") && diagnosticText.contains("* changed output"), "text marks changed-output workloads")
    try expect(!diagnosticText.contains("Paired estimates:"), "text omits verbose per-result diagnostics")
    try expect(diagnosticText.contains("Verdict: not evaluated (quick profile)"), "text explains the quick-profile verdict")
    try expect(diagnosticText.contains("Detailed artifacts: not saved"), "text reports ephemeral local artifacts")
    try expect(!diagnosticText.contains("/tmp/report.md"), "text does not print temporary artifact paths")

    let (decisionLegs, decisionPreflights) = testLegs(
        ratios: [Double](repeating: 1.02, count: 16),
        supercycles: 7,
        includeChanged: true
    )
    let decisionCalibration = try testCalibration(preflights: decisionPreflights, profile: .decision)
    let selectedAnalysis = try analyze(
        legs: decisionLegs, preflights: decisionPreflights, metadata: ["inputs": "matching"],
        calibrationHeaders: decisionCalibration.headers, calibrationRows: decisionCalibration.rows,
        memoryResults: nil,
        profile: .decision, enforceProfileBlockCount: false
    )
    try expect(selectedAnalysis.overallResult.name == "overall", "decision profile fixes the primary metric to overall")
    try expect(selectedAnalysis.verdict == .regression, "overall primary receives the run-level verdict")
    try expect(
        selectedAnalysis.workloadResults.first { $0.name == "contains-en" }?.classification == .notEvaluated,
        "comparable per-result classification remains diagnostic"
    )
    try expect(selectedAnalysis.operationResults.allSatisfy { $0.classification == .notEvaluated }, "operation rows do not receive verdicts")
    try expect(selectedAnalysis.overallResult.classification == .notEvaluated, "displayed overall row remains diagnostic")
    let selectedText = conciseText(selectedAnalysis, outputDirectory: URL(fileURLWithPath: "/tmp"))
    try expect(selectedText.contains("Verdict: REGRESSION") && selectedText.contains("Compare is slower"), "text highlights the fixed overall verdict")
    try expect(selectedText.components(separatedBy: "  overall ").count == 2 && !selectedText.contains("Primary overall"), "text reports the overall estimate once")
    try expect(!selectedText.contains("not-evaluated"), "text metric rows omit per-result status")

    let (orderBiasedLegs, orderBiasedPreflights) = testLegs(
        ratios: [Double](repeating: 1.02, count: 16),
        supercycles: 7,
        orientationBias: log(1.01)
    )
    let orderBiasedCalibration = try testCalibration(preflights: orderBiasedPreflights, profile: .decision)
    let orderBiasedAnalysis = try analyze(
        legs: orderBiasedLegs, preflights: orderBiasedPreflights, metadata: ["inputs": "matching"],
        calibrationHeaders: orderBiasedCalibration.headers, calibrationRows: orderBiasedCalibration.rows,
        memoryResults: nil, profile: .decision, enforceProfileBlockCount: true
    )
    try expect(orderBiasedAnalysis.verdict == .unstableOrderEffect, "order bias suppresses the primary verdict")
    try expectFailure("shared-input changed output") {
        _ = try analyze(
            legs: changedLegs, preflights: changedPreflights, metadata: ["inputs": "shared-base"],
            calibrationHeaders: quickCalibration.headers, calibrationRows: quickCalibration.rows,
            memoryResults: nil,
            profile: .quick, enforceProfileBlockCount: false
        )
    }
    var mismatchedCalibration = quickCalibration.rows
    mismatchedCalibration[0]["operations"] = "2"
    try expectFailure("frozen calibration mismatch") {
        _ = try analyze(
            legs: changedLegs, preflights: changedPreflights, metadata: ["inputs": "matching"],
            calibrationHeaders: quickCalibration.headers, calibrationRows: mismatchedCalibration,
            memoryResults: nil,
            profile: .quick, enforceProfileBlockCount: false
        )
    }
    var underTargetCalibration = quickCalibration.rows
    underTargetCalibration[0]["base_cpu_ns"] = "8999999"
    try expectFailure("calibration below target") {
        _ = try analyze(
            legs: changedLegs, preflights: changedPreflights, metadata: ["inputs": "matching"],
            calibrationHeaders: quickCalibration.headers, calibrationRows: underTargetCalibration,
            memoryResults: nil,
            profile: .quick, enforceProfileBlockCount: false
        )
    }

    print("Analyzer self-tests passed (supercycles, timeline balance, hierarchical statistics, order bias, calibration, integrity, presentation order, console output, changed outputs).")
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--self-test"] {
        try runSelfTests()
    } else if arguments == ["-h"] || arguments == ["--help"] {
        print(usage)
    } else {
        try run(options: parseOptions(arguments))
    }
} catch let error as AnalyzerError {
    FileHandle.standardError.write(Data("Analyzer error: \(error.description)\n".utf8))
    switch error {
    case .usage: exit(64)
    case .invalid: exit(1)
    }
} catch {
    FileHandle.standardError.write(Data("Analyzer error: \(error.localizedDescription)\n".utf8))
    exit(1)
}
