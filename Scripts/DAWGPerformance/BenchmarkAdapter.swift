//
//  DAWGPerformance
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import Darwin
import Dispatch
import Foundation

public enum BenchmarkAdapter {
    public enum Operation: String {
        case load
        case contains
        case words
        case pattern
    }

    public struct Measurement {
        public let cpuNanoseconds: UInt64
        public let wallNanoseconds: UInt64
        public let checksum: UInt64
    }

    public struct PreflightResult {
        public let values: [String]
        public let digest: String
        public let count: Int
    }

    public enum BenchmarkError: Error, CustomStringConvertible {
        case clockFailure(Int32)
        case invalidOperationCount(Int)

        public var description: String {
            switch self {
            case let .clockFailure(code):
                "clock_gettime(CLOCK_THREAD_CPUTIME_ID) failed with errno \(code)"
            case let .invalidOperationCount(count):
                "Operation count must be positive, got \(count)"
            }
        }
    }

    public static func preflight(
        operation: Operation,
        url: URL,
        query: String
    ) throws -> PreflightResult {
        let dawg = try DAWG(url: url)
        let values: [String]
        let count: Int

        switch operation {
        case .load:
            values = [String(dawg.count)]
            count = dawg.count
        case .contains:
            let contains = dawg.contains(query)
            values = [contains ? "1" : "0"]
            count = contains ? 1 : 0
        case .words:
            values = dawg.words(from: query, minLength: 2)
            count = values.count
        case .pattern:
            values = dawg.words(matching: query)
            count = values.count
        }

        return PreflightResult(
            values: values,
            digest: stableDigest(values: values, count: count),
            count: count
        )
    }

    @inline(never)
    public static func measure(
        operation: Operation,
        url: URL,
        query: String,
        operations: Int
    ) throws -> Measurement {
        guard operations > 0 else {
            throw BenchmarkError.invalidOperationCount(operations)
        }

        switch operation {
        case .load:
            return try measureLoad(url: url, operations: operations)
        case .contains:
            return try measureContains(url: url, query: query, operations: operations)
        case .words:
            return try measureWords(url: url, query: query, operations: operations)
        case .pattern:
            return try measurePattern(url: url, query: query, operations: operations)
        }
    }
}

private extension BenchmarkAdapter {
    static let nanosecondsPerSecond: UInt64 = 1_000_000_000
    static let fnvOffsetBasis: UInt64 = 14_695_981_039_346_656_037
    static let fnvPrime: UInt64 = 1_099_511_628_211

    static func threadCPUTime() throws -> UInt64 {
        var time = timespec()
        guard clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time) == 0 else {
            throw BenchmarkError.clockFailure(errno)
        }

        return UInt64(time.tv_sec) * nanosecondsPerSecond + UInt64(time.tv_nsec)
    }

    static func finishMeasurement(
        cpuStart: UInt64,
        wallStart: UInt64,
        checksum: UInt64
    ) throws -> Measurement {
        let cpuEnd = try threadCPUTime()
        let wallEnd = DispatchTime.now().uptimeNanoseconds
        return Measurement(
            cpuNanoseconds: cpuEnd - cpuStart,
            wallNanoseconds: wallEnd - wallStart,
            checksum: checksum
        )
    }

    @inline(never)
    static func measureLoad(url: URL, operations: Int) throws -> Measurement {
        var checksum: UInt64 = 0
        let cpuStart = try threadCPUTime()
        let wallStart = DispatchTime.now().uptimeNanoseconds

        for _ in 0..<operations {
            let dawg = try DAWG(url: url)
            checksum &+= UInt64(truncatingIfNeeded: dawg.count)
        }

        return try finishMeasurement(
            cpuStart: cpuStart,
            wallStart: wallStart,
            checksum: checksum
        )
    }

    @inline(never)
    static func measureContains(
        url: URL,
        query: String,
        operations: Int
    ) throws -> Measurement {
        let dawg = try DAWG(url: url)
        var checksum: UInt64 = 0
        let cpuStart = try threadCPUTime()
        let wallStart = DispatchTime.now().uptimeNanoseconds

        for _ in 0..<operations {
            checksum &+= dawg.contains(query) ? 1 : 0
        }

        return try finishMeasurement(
            cpuStart: cpuStart,
            wallStart: wallStart,
            checksum: checksum
        )
    }

    @inline(never)
    static func measureWords(
        url: URL,
        query: String,
        operations: Int
    ) throws -> Measurement {
        let dawg = try DAWG(url: url)
        var checksum: UInt64 = 0
        let cpuStart = try threadCPUTime()
        let wallStart = DispatchTime.now().uptimeNanoseconds

        for _ in 1..<operations {
            checksum &+= UInt64(truncatingIfNeeded: dawg.words(from: query, minLength: 2).count)
        }
        let finalValues = dawg.words(from: query, minLength: 2)
        checksum &+= UInt64(truncatingIfNeeded: finalValues.count)

        let measurement = try finishMeasurement(
            cpuStart: cpuStart,
            wallStart: wallStart,
            checksum: checksum
        )
        return addingSemanticChecksum(to: measurement, values: finalValues)
    }

    @inline(never)
    static func measurePattern(
        url: URL,
        query: String,
        operations: Int
    ) throws -> Measurement {
        let dawg = try DAWG(url: url)
        var checksum: UInt64 = 0
        let cpuStart = try threadCPUTime()
        let wallStart = DispatchTime.now().uptimeNanoseconds

        for _ in 1..<operations {
            checksum &+= UInt64(truncatingIfNeeded: dawg.words(matching: query).count)
        }
        let finalValues = dawg.words(matching: query)
        checksum &+= UInt64(truncatingIfNeeded: finalValues.count)

        let measurement = try finishMeasurement(
            cpuStart: cpuStart,
            wallStart: wallStart,
            checksum: checksum
        )
        return addingSemanticChecksum(to: measurement, values: finalValues)
    }

    static func stableDigest(values: [String], count: Int) -> String {
        String(format: "%016llx", stableDigestValue(values: values, count: count))
    }

    static func addingSemanticChecksum(to measurement: Measurement, values: [String]) -> Measurement {
        // Hash a complete timed result after the clocks stop so integrity checks
        // cover element values and order without measuring checksum work.
        Measurement(
            cpuNanoseconds: measurement.cpuNanoseconds,
            wallNanoseconds: measurement.wallNanoseconds,
            checksum: measurement.checksum ^ stableDigestValue(values: values, count: values.count)
        )
    }

    static func stableDigestValue(values: [String], count: Int) -> UInt64 {
        var hash = fnvOffsetBasis
        update(&hash, integer: UInt64(truncatingIfNeeded: count))
        update(&hash, integer: UInt64(values.count))

        for value in values {
            let bytes = value.utf8
            update(&hash, integer: UInt64(bytes.count))
            for byte in bytes {
                hash ^= UInt64(byte)
                hash &*= fnvPrime
            }
        }

        return hash
    }

    static func update(_ hash: inout UInt64, integer: UInt64) {
        var value = integer.littleEndian
        withUnsafeBytes(of: &value) { bytes in
            for byte in bytes {
                hash ^= UInt64(byte)
                hash &*= fnvPrime
            }
        }
    }
}
