//
//  ScrabbdictTests
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SnapshotTesting
import UIKit

extension Diffing where Value == UIImage {
    static func sRGBImage(
        precision: Float,
        scale: CGFloat? = nil
    ) -> Self {
        let exactImageDiffing = Self.image(
            precision: 1,
            perceptualPrecision: 1,
            scale: scale
        )

        return .diff(
            toData: exactImageDiffing.toData,
            fromData: exactImageDiffing.fromData
        ) { reference, actual in
            guard
                let message = comparisonFailure(
                    reference: reference,
                    actual: actual,
                    precision: precision
                )
            else {
                return nil
            }

            let attachments = exactImageDiffing.diffV2(reference, actual)?.1 ?? []
            return (message, attachments)
        }
    }
}

private struct RGBA8Image {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init?(_ image: UIImage) {
        guard
            let pngData = image.pngData(),
            let decodedImage = UIImage(data: pngData, scale: image.scale),
            let cgImage = decodedImage.cgImage,
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let didRender = bytes.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else {
                return false
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard didRender else {
            return nil
        }

        self.width = width
        self.height = height
        self.bytes = bytes
    }
}

private func comparisonFailure(
    reference: UIImage,
    actual: UIImage,
    precision: Float
) -> String? {
    guard let referenceImage = RGBA8Image(reference) else {
        return "Reference image could not be normalized to 8-bit sRGB."
    }
    guard let actualImage = RGBA8Image(actual) else {
        return "Newly-taken snapshot could not be normalized to 8-bit sRGB."
    }
    guard
        referenceImage.width == actualImage.width,
        referenceImage.height == actualImage.height
    else {
        return "Newly-taken snapshot@\(actualImage.width)x\(actualImage.height) does not match reference@\(referenceImage.width)x\(referenceImage.height)."
    }

    var failingPixelCount = 0
    var maximumChannelDifference: UInt8 = 0
    var pixelOffset = 0

    while pixelOffset < referenceImage.bytes.count {
        var pixelDifference: UInt8 = 0
        var channelOffset = 0

        while channelOffset < 4 {
            let referenceChannel = referenceImage.bytes[pixelOffset + channelOffset]
            let actualChannel = actualImage.bytes[pixelOffset + channelOffset]
            let channelDifference = UInt8(abs(Int(referenceChannel) - Int(actualChannel)))
            pixelDifference = max(pixelDifference, channelDifference)
            channelOffset += 1
        }

        if pixelDifference > 1 {
            failingPixelCount += 1
        }
        maximumChannelDifference = max(maximumChannelDifference, pixelDifference)
        pixelOffset += 4
    }

    let pixelCount = referenceImage.width * referenceImage.height
    let actualPrecision = 1 - Float(failingPixelCount) / Float(pixelCount)
    guard actualPrecision < precision else {
        return nil
    }

    return """
    Actual image precision \(actualPrecision) is less than required \(precision).
    \(failingPixelCount) of \(pixelCount) pixels exceed per-channel tolerance 1/255.
    Maximum channel difference: \(maximumChannelDifference)/255.
    """
}
