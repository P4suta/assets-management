import UIKit

enum TextContrastError: Error {
    case unsupportedImage, transparentPixels, insufficientColors, insufficientForeground, ambiguousColors, changedFrame
}

struct UniformTextContrast {
    let ratio: Double
    let foregroundPixels: Int

    init(image: CGImage) throws {
        let (count, overflow) = image.width.multipliedReportingOverflow(by: image.height)
        guard !overflow, count > 0, count <= 1_000_000,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw TextContrastError.unsupportedImage }
        var pixels = [UInt8](repeating: 0, count: count * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
            else { throw TextContrastError.unsupportedImage }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var colors: [UInt32: Int] = [:]
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            guard pixels[offset + 3] == 255 else { throw TextContrastError.transparentPixels }
            let rgb = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            colors[rgb, default: 0] += 1
        }
        let modes = colors.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        guard let dominant = modes.first else { throw TextContrastError.insufficientColors }
        let background = modes.filter { Self.neighbors($0.key, dominant.key) }
        guard background.reduce(0, { $0 + $1.value }) > count / 2 else { throw TextContrastError.insufficientColors }
        let foreground = modes.filter { !Self.neighbors($0.key, dominant.key) }
        guard let tone = foreground.first else { throw TextContrastError.insufficientColors }
        guard tone.value >= 8 else { throw TextContrastError.insufficientForeground }
        guard foreground.dropFirst().first?.value != tone.value else { throw TextContrastError.ambiguousColors }
        let luminance = Self.luminance(tone.key)
        let ratios = background.map { sample in
            let value = Self.luminance(sample.key)
            return (max(value, luminance) + 0.05) / (min(value, luminance) + 0.05)
        }
        guard let minimum = ratios.min() else { throw TextContrastError.insufficientColors }
        ratio = minimum
        foregroundPixels = tone.value
    }

    private static func neighbors(_ first: UInt32, _ second: UInt32) -> Bool {
        [0, 8, 16].allSatisfy { shift in
            abs(Int((first >> shift) & 255) - Int((second >> shift) & 255)) <= 1
        }
    }

    private static func luminance(_ rgb: UInt32) -> Double {
        func linear(_ channel: UInt32) -> Double {
            let value = Double(channel & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb >> 16) + 0.7152 * linear(rgb >> 8) + 0.0722 * linear(rgb)
    }
}
