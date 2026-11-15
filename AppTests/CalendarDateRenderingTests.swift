import PropertyCore
import SwiftUI
import Testing
import UIKit
@testable import PropertyRecords

extension NativePresentationTests {
    @Test(arguments: [420, 1032])
    func contractDatesRemainCompleteAtStandardAndLargestTextSizes(width: Int) async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        var records = try SampleRecords.make()
        let start = try #require(ContractDates.calendar.date(from: DateComponents(year: 2025, month: 4, day: 1)))
        let end = try #require(ContractDates.calendar.date(from: DateComponents(year: 2027, month: 3, day: 31)))
        records.rooms[0].contract = Contract(start: start, end: end, monthlyRent: 82_000)
        try await repository.save(records)
        let store = RecordsStore(repository: repository)
        await store.load()
        let categories: [UIContentSizeCategory] = [.large, .accessibilityExtraExtraExtraLarge]
        for category in categories {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: 1376)
            window.overrideUserInterfaceStyle = .light
            let session = EditorSession(ContractFields(start: Date(), end: Date()))
            let controller = UIHostingController(rootView: ContractEditor(session: session, roomID: records.rooms[0].id)
                .environment(store).environment(AppNotices()).environment(\.locale, Locale(identifier: "ja_JP")))
            controller.traitOverrides.preferredContentSizeCategory = category
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true; window.rootViewController = nil }
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            repeat {
                controller.view.layoutIfNeeded()
                if dateDescendants(controller.view).contains(where: { $0 is UICollectionView }) { break }
                try await Task.sleep(for: .milliseconds(10))
            } while ContinuousClock.now < deadline
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                #expect(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            Attachment.record(try #require(image.pngData()), named: "Contract dates \(width)-\(category.rawValue).png")
            try verifyText(in: #require(image.cgImage), languages: ["en-US"],
                           expectation: .dates(["2025/04/01", "2027/03/31"], present: true))
        }
    }

    @Test(arguments: [320, 420, 1032], [false, true])
    func calendarDateValueGlyphsRespectNativeTextMetrics(width: Int, dark: Bool) async throws {
        let standard = try await dateCard(width: width, dark: dark, category: .large)
        let largest = try await dateCard(width: width, dark: dark, category: .accessibilityExtraExtraExtraLarge)
        Attachment.record(try #require(standard.pngData()), named: "Date value standard-\(width)-\(dark).png")
        Attachment.record(try #require(largest.pngData()), named: "Date value largest-\(width)-\(dark).png")
        let standardHeight = try dateGlyphHeight(in: #require(standard.cgImage))
        let largestHeight = try dateGlyphHeight(in: #require(largest.cgImage))
        #expect(try CGFloat(largestHeight) >= CGFloat(standardHeight) * requiredTextEnlargement(),
                "Rendered glyph heights: \(standardHeight), \(largestHeight)")
    }

    @Test func dateGlyphMeasurementTracksAStandardSizeOverride() async throws {
        let standard = try await dateCard(width: 420, dark: false, category: .large)
        let frozen = try await dateCard(width: 420, dark: false, category: .accessibilityExtraExtraExtraLarge, forcedStandardText: true)
        let standardHeight = try dateGlyphHeight(in: #require(standard.cgImage))
        let frozenHeight = try dateGlyphHeight(in: #require(frozen.cgImage))
        if ProcessInfo.processInfo.isiOSAppOnMac {
            #expect(frozenHeight == standardHeight)
        } else {
            #expect(frozenHeight < standardHeight * 2)
        }
    }

    @Test func dateGlyphMeasurementExcludesConnectedBorderPixels() throws {
        for size in [CGFloat(17), CGFloat(53)] {
            func capture(rounded: Bool) -> UIImage {
                let format = UIGraphicsImageRendererFormat()
                format.opaque = true
                return UIGraphicsImageRenderer(size: CGSize(width: 400, height: 160), format: format).image { context in
                    UIColor.black.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 400, height: 160))
                    UIColor.white.setFill()
                    UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 400, height: 160),
                        cornerRadius: rounded ? 60 : 0).fill()
                    ("2025/04/01" as NSString).draw(at: CGPoint(x: 80, y: 40),
                        withAttributes: [.font: UIFont.systemFont(ofSize: size), .foregroundColor: UIColor.black])
                }
            }
            let plain = try dateGlyphHeight(in: #require(capture(rounded: false).cgImage))
            let rounded = try dateGlyphHeight(in: #require(capture(rounded: true).cgImage))
            #expect(plain == rounded)
            #expect(plain > 0)
        }
    }

    @Test(arguments: [false, true])
    func dateGlyphMeasurementRequiresVisibleNeutralInk(dark: Bool) throws {
        let base = dark ? UIColor.white : .black
        func capture(_ color: UIColor?) throws -> CGImage {
            let size = CGSize(width: 400, height: 160)
            let image = UIGraphicsImageRenderer(size: size).image { context in
                (dark ? UIColor.black : .white).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                if let color {
                    ("2025/04/01" as NSString).draw(at: CGPoint(x: 40, y: 40),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 32), .foregroundColor: color])
                }
            }
            return try #require(image.cgImage)
        }
        let opaque = try dateGlyphHeight(in: capture(base))
        for alpha in [CGFloat(0.55), CGFloat(0.85)] {
            #expect(try dateGlyphHeight(in: capture(base.withAlphaComponent(alpha))) == opaque)
        }
        #expect(throws: DateGlyphFailure.missingForeground) { try dateGlyphHeight(in: capture(nil)) }
        #expect(throws: DateGlyphFailure.missingForeground) { try dateGlyphHeight(in: capture(.systemIndigo)) }
    }

    @Test func dateRecognitionRejectsNativeEllipsis() throws {
        let value = "2025/04/01"
        let font = UIFont.preferredFont(forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
        let completeWidth = (value as NSString).size(withAttributes: [.font: font]).width
        for factor in [CGFloat(0.55), CGFloat(1.25)] {
            let width = ceil(completeWidth * factor)
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: 80))
            label.text = value
            label.font = font
            label.textColor = .black
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            label.lineBreakMode = .byTruncatingTail
            let image = UIGraphicsImageRenderer(size: label.bounds.size).image { context in
                UIColor.white.setFill()
                context.fill(label.bounds)
                label.drawText(in: label.bounds)
            }
            try verifyText(in: #require(image.cgImage), languages: ["en-US"],
                           expectation: .dates([value], present: factor > 1))
        }
    }

    private func dateCard(width: Int, dark: Bool, category: UIContentSizeCategory, forcedStandardText: Bool = false) async throws -> UIImage {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: 900)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        let controller = UIHostingController(rootView: Form {
            CalendarDateField("日付", selection: .constant(Date(timeIntervalSince1970: 1_743_462_000)))
                .transformEnvironment(\.dynamicTypeSize) { if forcedStandardText { $0 = .large } }
        }.environment(\.locale, Locale(identifier: "ja_JP")))
        controller.traitOverrides.preferredContentSizeCategory = category
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        var cell: UICollectionViewCell?
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            controller.view.layoutIfNeeded()
            cell = dateDescendants(controller.view).compactMap { $0 as? UICollectionView }.first?.visibleCells.first
            if let cell, !cell.bounds.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        let row = try #require(cell)
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.traitCollection.displayScale
        format.opaque = true
        return UIGraphicsImageRenderer(size: row.bounds.size, format: format).image { context in
            UIColor.systemGroupedBackground.resolvedColor(with: controller.traitCollection).setFill()
            context.fill(row.bounds)
            #expect(row.drawHierarchy(in: row.bounds, afterScreenUpdates: true))
        }
    }

    private func dateDescendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(dateDescendants) }

    private enum DateGlyphFailure: Error { case missingForeground, ambiguousForeground }

    private func dateGlyphHeight(in image: CGImage) throws -> Int {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var tones: [UInt32: Int] = [:]
        for pixel in 0..<(image.width * image.height) {
            let offset = pixel * 4
            try #require(pixels[offset + 3] == 255)
            let rgb = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            tones[rgb, default: 0] += 1
        }
        let background = try #require(tones.max { $0.value < $1.value }?.key)
        func luminance(_ rgb: UInt32) -> Double {
            func linear(_ shift: Int) -> Double {
                let value = Double((rgb >> shift) & 255) / 255
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0)
        }
        let backgroundLight = luminance(background)
        let candidates = Set(tones.keys.filter { rgb in
            let channels = [16, 8, 0].map { Int((rgb >> $0) & 255) }
            let light = luminance(rgb)
            let contrast = (max(light, backgroundLight) + 0.05) / (min(light, backgroundLight) + 0.05)
            return (channels.max() ?? 0) - (channels.min() ?? 0) <= 1 && contrast >= 4.5
        })
        var foreground = (0..<(image.width * image.height)).map { pixel in
            let offset = pixel * 4
            let rgb = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            return candidates.contains(rgb)
        }
        var border: [Int] = []
        func remove(_ pixel: Int) {
            if foreground[pixel] {
                foreground[pixel] = false
                border.append(pixel)
            }
        }
        for column in 0..<image.width {
            remove(column)
            remove((image.height - 1) * image.width + column)
        }
        for row in 0..<image.height {
            remove(row * image.width)
            remove((row + 1) * image.width - 1)
        }
        while let pixel = border.popLast() {
            let column = pixel % image.width
            if column > 0 { remove(pixel - 1) }
            if column + 1 < image.width { remove(pixel + 1) }
            if pixel >= image.width { remove(pixel - image.width) }
            if pixel + image.width < foreground.count { remove(pixel + image.width) }
        }
        var ink: [UInt32: Int] = [:]
        for pixel in foreground.indices where foreground[pixel] {
            let offset = pixel * 4
            let rgb = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            ink[rgb, default: 0] += 1
        }
        let modes = ink.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        guard let tone = modes.first else { throw DateGlyphFailure.missingForeground }
        guard modes.dropFirst().first?.value != tone.value else { throw DateGlyphFailure.ambiguousForeground }
        for pixel in foreground.indices where foreground[pixel] {
            let offset = pixel * 4
            foreground[pixel] = [16, 8, 0].enumerated().allSatisfy { channel, shift in
                abs(Int(pixels[offset + channel]) - Int((tone.key >> shift) & 255)) <= 1
            }
        }
        var rows: [Int] = []
        for row in 0..<image.height {
            let count = foreground[(row * image.width)..<((row + 1) * image.width)].filter { $0 }.count
            if count >= 2 { rows.append(row) }
        }
        guard let first = rows.first, let last = rows.last else { throw DateGlyphFailure.missingForeground }
        return last - first + 1
    }
}
