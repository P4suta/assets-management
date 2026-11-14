import PropertyCore
import SwiftUI
import Testing
import UIKit
import Vision
@testable import PropertyRecords

extension NativePresentationTests {
    @Test(arguments: [420, 1032])
    func contractDatesRemainCompleteAtStandardAndLargestTextSizes(width: Int) async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let records = try SampleRecords.make()
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
            let recognized = try recognizedDateStrings(in: #require(image.cgImage))
            for value in ["2025/04/01", "2027/03/31"] {
                #expect(recognized.contains(where: { $0.contains(value) }), "Missing complete rendered date \(value): \(recognized)")
            }
        }
    }

    @Test(arguments: [320, 420, 1032], [false, true])
    func calendarDateValueGlyphsDoubleWithAccessibilityText(width: Int, dark: Bool) async throws {
        let standard = try await dateCard(width: width, dark: dark, category: .large)
        let largest = try await dateCard(width: width, dark: dark, category: .accessibilityExtraExtraExtraLarge)
        let standardHeight = try dateGlyphHeight(in: #require(standard.cgImage), dark: dark)
        let largestHeight = try dateGlyphHeight(in: #require(largest.cgImage), dark: dark)
        Attachment.record(try #require(standard.pngData()), named: "Date value standard-\(width)-\(dark).png")
        Attachment.record(try #require(largest.pngData()), named: "Date value largest-\(width)-\(dark).png")
        #expect(largestHeight >= standardHeight * 2, "Rendered glyph heights: \(standardHeight), \(largestHeight)")
    }

    @Test func dateGlyphMeasurementRejectsAStandardSizeOverride() async throws {
        let standard = try await dateCard(width: 420, dark: false, category: .large)
        let frozen = try await dateCard(width: 420, dark: false, category: .accessibilityExtraExtraExtraLarge, forcedStandardText: true)
        let standardHeight = try dateGlyphHeight(in: #require(standard.cgImage), dark: false)
        let frozenHeight = try dateGlyphHeight(in: #require(frozen.cgImage), dark: false)
        #expect(frozenHeight < standardHeight * 2)
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
            let plain = try dateGlyphHeight(in: #require(capture(rounded: false).cgImage), dark: false)
            let rounded = try dateGlyphHeight(in: #require(capture(rounded: true).cgImage), dark: false)
            #expect(plain == rounded)
            #expect(plain > 0)
        }
    }

    @Test func dateRecognitionRejectsNativeEllipsis() throws {
        for width in [CGFloat(197), CGFloat(320)] {
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: 80))
            label.text = "2025/04/01"
            label.font = .preferredFont(forTextStyle: .body,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
            label.textColor = .black
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            label.lineBreakMode = .byTruncatingTail
            let image = UIGraphicsImageRenderer(size: label.bounds.size).image { context in
                UIColor.white.setFill()
                context.fill(label.bounds)
                label.drawText(in: label.bounds)
            }
            let values = try recognizedDateStrings(in: #require(image.cgImage))
            #expect(values.contains(where: { $0.contains("2025/04/01") }) == (width == 320), "Recognized: \(values)")
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

    private func recognizedDateStrings(in image: CGImage) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string.filter { !$0.isWhitespace } }
    }

    private func dateGlyphHeight(in image: CGImage, dark: Bool) throws -> Int {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        let target = dark ? 255 : 0
        var foreground = (0..<(image.width * image.height)).map { pixel in
            let offset = pixel * 4
            return pixels[offset + 3] == 255 && (0..<3).allSatisfy { abs(Int(pixels[offset + $0]) - target) <= 1 }
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
        var rows: [Int] = []
        for row in 0..<image.height {
            let count = foreground[(row * image.width)..<((row + 1) * image.width)].filter { $0 }.count
            if count >= 2 { rows.append(row) }
        }
        return try #require(rows.last) - #require(rows.first) + 1
    }
}
