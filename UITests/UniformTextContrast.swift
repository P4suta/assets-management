import CoreGraphics
import Foundation

enum TextContrastError: Error {
    case unsupportedImage, transparentPixels, insufficientColors, insufficientForeground, ambiguousColors, changedFrame
}

enum TextContrastBackground {
    case uniform, shaded, sampledBorder
}

enum TextContrastForeground {
    case sampledPaints, recordCaption(RecordCaptionRole, text: String)

    var usesSinglePaint: Bool {
        guard case .recordCaption(_, let text) = self else { return false }
        return text.unicodeScalars.allSatisfy {
            ($0.isASCII || !$0.properties.isEmoji) && $0.value != 0xFE0F && $0.value != 0x20E3
        }
    }
}

struct UniformTextContrast {
    let ratio: Double
    let dominantRatio: Double
    let foregroundPixels: Int
    let foregroundHeight: Int

    init(image: CGImage, background model: TextContrastBackground = .uniform,
         foreground foregroundModel: TextContrastForeground = .sampledPaints) throws {
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
        guard !modes.isEmpty else { throw TextContrastError.insufficientColors }
        let background: [(key: UInt32, value: Int)]
        switch model {
        case .uniform:
            let channels = try Self.cornerChannels(pixels, width: image.width, height: image.height)
            background = modes.filter { sample in
                [16, 8, 0].enumerated().allSatisfy { channel, shift in
                    channels[channel].contains(Int((sample.key >> shift) & 255))
                }
            }
        case .shaded:
            let palette = try Self.shadedPalette(border)
            background = modes.filter { palette.contains($0.key) }
        case .sampledBorder:
            let palette = try Self.borderPalette(border)
            background = modes.filter { palette.contains($0.key) }
        }
        guard background.reduce(0, { $0 + $1.value }) > count / 2 else { throw TextContrastError.insufficientColors }
        let backgroundKeys = Set(background.map(\.key))
        let foreground = modes.filter { !backgroundKeys.contains($0.key) }
        guard let tone = foreground.first else { throw TextContrastError.insufficientColors }
        guard tone.value >= 8 else { throw TextContrastError.insufficientForeground }
        guard foreground.dropFirst().first?.value != tone.value else { throw TextContrastError.ambiguousColors }
        let ink: Set<UInt32> = try foregroundModel.usesSinglePaint ? [tone.key]
            : Self.inkPaints(pixels, width: image.width, height: image.height, background: backgroundKeys, ink: tone.key)
        let ratios = ink.flatMap { foreground in
            background.map { Self.contrast(foreground, $0.key) }
        }
        guard let minimum = ratios.min(), let dominant = background.map({ Self.contrast(tone.key, $0.key) }).min()
        else { throw TextContrastError.insufficientColors }
        ratio = minimum
        dominantRatio = dominant
        foregroundPixels = tone.value
        var firstRow = image.height
        var lastRow = -1
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let rgb = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            if rgb == tone.key {
                let row = offset / 4 / image.width
                firstRow = min(firstRow, row)
                lastRow = max(lastRow, row)
            }
        }
        guard lastRow >= firstRow else { throw TextContrastError.insufficientForeground }
        foregroundHeight = lastRow - firstRow + 1
    }

    private static func inkPaints(_ pixels: [UInt8], width: Int, height: Int, background: Set<UInt32>, ink: UInt32) throws -> Set<UInt32> {
        let colors = stride(from: 0, to: pixels.count, by: 4).map {
            UInt32(pixels[$0]) << 16 | UInt32(pixels[$0 + 1]) << 8 | UInt32(pixels[$0 + 2])
        }
        var paints: Set<UInt32> = [ink]
        guard width >= 3, height >= 3 else { return paints }
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let color = colors[y * width + x]
                guard !background.contains(color) else { continue }
                let solid = ((y - 1)...(y + 1)).allSatisfy { row in
                    ((x - 1)...(x + 1)).allSatisfy { column in
                        Self.similar(colors[row * width + column], color, tolerance: 1)
                    }
                }
                let narrow = [(2, 3), (3, 2)].contains { columns, rows in
                    guard x + columns <= width, y + rows <= height else { return false }
                    return (y..<(y + rows)).allSatisfy { row in
                        (x..<(x + columns)).allSatisfy { column in colors[row * width + column] == color }
                    }
                }
                if solid || narrow { paints.insert(color) }
            }
        }
        for _ in 0..<16 {
            let additional = componentPaints(colors, width: width, height: height, background: background, known: paints).subtracting(paints)
            if additional.isEmpty { return paints }
            paints.formUnion(additional)
        }
        throw TextContrastError.ambiguousColors
    }

    private static func componentPaints(_ colors: [UInt32], width: Int, height: Int,
                                        background: Set<UInt32>, known: Set<UInt32>) -> Set<UInt32> {
        let interior = colors.map { known.contains($0) }
        let unexplained = colors.indices.map { index in
            guard !background.contains(colors[index]), !interior[index] else { return false }
            let x = index % width
            let y = index / width
            return (max(0, y - 2)...min(height - 1, y + 2)).allSatisfy { row in
                (max(0, x - 2)...min(width - 1, x + 2)).allSatisfy { column in !interior[row * width + column] }
            }
        }
        var visited = [Bool](repeating: false, count: colors.count)
        var paints: Set<UInt32> = []
        for seed in colors.indices where !visited[seed] && unexplained[seed] {
            var component = [seed]
            visited[seed] = true
            var counts: [UInt32: Int] = [:]
            var cursor = 0
            while cursor < component.count {
                let index = component[cursor]
                cursor += 1
                let color = colors[index]
                counts[color, default: 0] += 1
                let x = index % width
                let y = index / width
                for row in max(0, y - 1)...min(height - 1, y + 1) {
                    for column in max(0, x - 1)...min(width - 1, x + 1) {
                        let neighbor = row * width + column
                        if !visited[neighbor] && unexplained[neighbor] {
                            visited[neighbor] = true
                            component.append(neighbor)
                        }
                    }
                }
            }
            guard let maximum = counts.values.max(), maximum >= 8 else { continue }
            paints.formUnion(counts.filter { $0.value == maximum }.keys)
        }
        return paints
    }

    private static func similar(_ first: UInt32, _ second: UInt32, tolerance: Int) -> Bool {
        [0, 8, 16].allSatisfy { abs(Int((first >> $0) & 255) - Int((second >> $0) & 255)) <= tolerance }
    }

    private static func cornerChannels(_ pixels: [UInt8], width: Int, height: Int) throws -> [ClosedRange<Int>] {
        let corners = [0, width - 1, (height - 1) * width, width * height - 1]
        return try (0..<3).map { channel in
            let values = corners.map { Int(pixels[$0 * 4 + channel]) }
            let low = values.reduce(255, min)
            let high = values.reduce(0, max)
            guard high - low <= 16 else { throw TextContrastError.ambiguousColors }
            return max(0, low - 1)...min(255, high + 1)
        }
    }

    private static func shadedPalette(_ border: Set<UInt32>) throws -> Set<UInt32> {
        for shift in [0, 8, 16] {
            let channels = border.map { Int(($0 >> shift) & 255) }
            guard let low = channels.min(), let high = channels.max(), high - low <= 16 else {
                throw TextContrastError.ambiguousColors
            }
        }
        return try borderPalette(border)
    }

    private static func borderPalette(_ border: Set<UInt32>) throws -> Set<UInt32> {
        guard !border.isEmpty, border.count <= 256 else { throw TextContrastError.ambiguousColors }
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

    private static func contrast(_ foreground: UInt32, _ background: UInt32) -> Double {
        let ink = luminance(foreground)
        let field = luminance(background)
        return (max(ink, field) + 0.05) / (min(ink, field) + 0.05)
    }

    private static func luminance(_ rgb: UInt32) -> Double {
        func linear(_ channel: UInt32) -> Double {
            let value = Double(channel & 255) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb >> 16) + 0.7152 * linear(rgb >> 8) + 0.0722 * linear(rgb)
    }
}
