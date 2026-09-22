//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SnapshotTesting
import UIKit
import XCTest

final class SnapshotImageDiffingTests: XCTestCase {
    private let diffing = Diffing<UIImage>.sRGBImage(
        precision: 0.9995,
        scale: 1
    )

    func testIdenticalImagesMatch() {
        let image = makeImage()

        XCTAssertNil(diffing.diffV2(image, image))
    }

    func testOneStepChannelDifferenceMatchesForEveryPixel() {
        let reference = makeImage()
        let actual = makeImage(difference: 1, differingPixelCount: 10_000)

        XCTAssertNil(diffing.diffV2(reference, actual))
    }

    func testDifferencesAboveToleranceMatchWithinPrecisionBudget() {
        let reference = makeImage()
        let actual = makeImage(difference: 2, differingPixelCount: 4)

        XCTAssertNil(diffing.diffV2(reference, actual))
    }

    func testDifferencesAboveToleranceFailBeyondPrecisionBudget() throws {
        let reference = makeImage()
        let actual = makeImage(difference: 2, differingPixelCount: 6)

        let failure = try XCTUnwrap(diffing.diffV2(reference, actual))

        XCTAssertTrue(failure.0.contains("Actual image precision 0.9994"))
        XCTAssertTrue(failure.0.contains("6 of 10000 pixels"))
        XCTAssertTrue(failure.0.contains("tolerance 1/255"))
        XCTAssertTrue(failure.0.contains("Maximum channel difference: 2/255"))
        XCTAssertEqual(failure.1.count, 3)
    }

    func testDifferentImageSizesFail() throws {
        let reference = makeImage(width: 1, height: 1)
        let actual = makeImage(width: 2, height: 1)

        let failure = try XCTUnwrap(diffing.diffV2(reference, actual))

        XCTAssertTrue(failure.0.contains("snapshot@2x1"))
        XCTAssertTrue(failure.0.contains("reference@1x1"))
        XCTAssertEqual(failure.1.count, 3)
    }
}

private extension SnapshotImageDiffingTests {
    func makeImage(
        width: Int = 100,
        height: Int = 100,
        difference: UInt8 = 0,
        differingPixelCount: Int = 0
    ) -> UIImage {
        let pixelCount = width * height
        var bytes = [UInt8]()
        bytes.reserveCapacity(pixelCount * 4)

        for pixelIndex in 0..<pixelCount {
            bytes.append(100 + (pixelIndex < differingPixelCount ? difference : 0))
            bytes.append(120)
            bytes.append(140)
            bytes.append(255)
        }

        let data = Data(bytes) as CFData
        let provider = CGDataProvider(data: data)!
        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
