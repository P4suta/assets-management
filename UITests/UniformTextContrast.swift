import UIKit

enum TextContrastError: Error {
    case unsupportedImage, transparentPixels, insufficientColors, insufficientForeground, ambiguousColors, changedFrame
}

enum TextContrastBackground {
    case uniform, shaded
}

struct UniformTextContrast {
    let ratio: Double
    let foregroundPixels: Int

    init(image: CGImage, background model: TextContrastBackground = .uniform) throws {
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
        var border: Set<UInt32> = []
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            guard pixels[offset + 3] == 255 else { throw TextContrastError.transparentPixels }
            let rgb = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            colors[rgb, default: 0] += 1
            let pixel = offset / 4
            let x = pixel % image.width
            let y = pixel / image.width
            if x == 0 || y == 0 || x == image.width - 1 || y == image.height - 1 { border.insert(rgb) }
        }
        let modes = colors.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        guard let dominant = modes.first else { throw TextContrastError.insufficientColors }
        let background: [(key: UInt32, value: Int)]
        switch model {
        case .uniform: background = modes.filter { Self.neighbors($0.key, dominant.key) }
        case .shaded:
            let palette = try Self.shadedPalette(border)
            background = modes.filter { palette.contains($0.key) }
        }
        guard background.reduce(0, { $0 + $1.value }) > count / 2 else { throw TextContrastError.insufficientColors }
        let backgroundKeys = Set(background.map(\.key))
        let foreground = modes.filter { !backgroundKeys.contains($0.key) }
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

    private static func shadedPalette(_ border: Set<UInt32>) throws -> Set<UInt32> {
        guard !border.isEmpty, border.count <= 256 else { throw TextContrastError.ambiguousColors }
        for shift in [0, 8, 16] {
            let channels = border.map { Int(($0 >> shift) & 255) }
            guard let low = channels.min(), let high = channels.max(), high - low <= 16 else {
                throw TextContrastError.ambiguousColors
            }
        }
        var palette: Set<UInt32> = []
        for color in border {
            let red = Int((color >> 16) & 255)
            let green = Int((color >> 8) & 255)
            let blue = Int(color & 255)
            for rValue in max(0, red - 1)...min(255, red + 1) {
                for gValue in max(0, green - 1)...min(255, green + 1) {
                    for bValue in max(0, blue - 1)...min(255, blue + 1) {
                        palette.insert(UInt32(rValue) << 16 | UInt32(gValue) << 8 | UInt32(bValue))
                    }
                }
            }
        }
        return palette
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
