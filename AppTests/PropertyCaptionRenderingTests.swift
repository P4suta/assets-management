import PropertyCore
import SwiftUI
import Testing
import UIKit
import Vision
@testable import PropertyRecords

extension NativePresentationTests {
    @Test(arguments: [320, 420, 1032], [false, true])
    func propertyCaptionGlyphsDoubleWithAccessibilityText(width: Int, dark: Bool) async throws {
        let standard = try await propertyCaptionImage(width: width, dark: dark, category: .large)
        let largest = try await propertyCaptionImage(width: width, dark: dark, category: .accessibilityExtraExtraExtraLarge)
        Attachment.record(try #require(standard.image.pngData()), named: "Property captions standard-\(width)-\(dark).png")
        Attachment.record(try #require(largest.image.pngData()), named: "Property captions largest-\(width)-\(dark).png")
        let normal = try propertyCaptionHeights(in: standard)
        let enlarged = try propertyCaptionHeights(in: largest)
        for label in ["部屋を追加", "写真", "写真を追加"] {
            let initial = try #require(normal[label])
            let scaled = try #require(enlarged[label])
            #expect(scaled >= initial * 2, "\(label) glyph heights: \(initial), \(scaled)")
        }
    }

    @Test func propertyCaptionMeasurementRejectsAStandardSizeOverride() async throws {
        let standard = try await propertyCaptionImage(width: 420, dark: false, category: .large)
        let frozen = try await propertyCaptionImage(width: 420, dark: false, category: .accessibilityExtraExtraExtraLarge, forcedStandardText: true)
        let normal = try propertyCaptionHeights(in: standard)
        let unchanged = try propertyCaptionHeights(in: frozen)
        for label in ["部屋を追加", "写真", "写真を追加"] {
            #expect(try #require(unchanged[label]) < #require(normal[label]) * 2)
        }
    }

    @Test func propertyCaptionRecognitionRejectsMissingAndAmbiguousText() throws {
        let first = CGRect(x: 10, y: 70, width: 80, height: 20)
        let second = CGRect(x: 10, y: 40, width: 60, height: 20)
        #expect(try PropertyCaptionRecognition.bounds(label: "部屋を追加", leadingSymbol: .plus, observations: [
            ("＋部屋を", first), ("追加", second)
        ]) == first.union(second))
        #expect(throws: PropertyCaptionRecognition.Failure.missing) {
            try PropertyCaptionRecognition.bounds(label: "部屋を追加", observations: [("部屋を…", first)])
        }
        #expect(throws: PropertyCaptionRecognition.Failure.ambiguous) {
            try PropertyCaptionRecognition.bounds(label: "写真", observations: [("写真", first), ("写真", second)])
        }
        #expect(throws: PropertyCaptionRecognition.Failure.ambiguous) {
            try PropertyCaptionRecognition.bounds(label: "写真", observations: [("写真", first), ("写真", first)])
        }
        #expect(throws: PropertyCaptionRecognition.Failure.missing) {
            try PropertyCaptionRecognition.bounds(label: "部屋を追加", observations: [
                ("部屋を", first), ("追加", second.offsetBy(dx: 0, dy: -200))
            ])
        }
        #expect(throws: PropertyCaptionRecognition.Failure.invalidGeometry) {
            try PropertyCaptionRecognition.bounds(label: "写真", observations: [("写真", .infinite)])
        }
    }

    @Test func propertyCaptionRecognitionAcceptsTheNativePlusObservation() throws {
        let frame = CGRect(x: 77, y: 705, width: 238, height: 45)
        let caption = CGRect(x: 84, y: 58, width: 194, height: 32)
        #expect(try PropertyCaptionRecognition.bounds(label: "写真を追加", leadingSymbol: .plus, observations: [
            ("写真を追加", caption), ("十", CGRect(x: 44, y: 53, width: 44, height: 44))
        ]) == caption)
        for prefix in ["+", "＋", "十", "→"] {
            #expect(try PropertyCaptionRecognition.bounds(label: "部屋を追加", leadingSymbol: .plus,
                observations: [(prefix + "部屋を追加", frame)]) == frame)
        }
        for value in ["十部屋を追加", "大部屋を追加", "部屋を十追加", "十部屋を…", "十十部屋を追加"] {
            #expect(throws: PropertyCaptionRecognition.Failure.missing) {
                try PropertyCaptionRecognition.bounds(label: "部屋を追加", observations: [(value, frame)])
            }
        }
        for value in ["大部屋を追加", "部屋を十追加", "十部屋を…", "十十部屋を追加"] {
            #expect(throws: PropertyCaptionRecognition.Failure.missing) {
                try PropertyCaptionRecognition.bounds(label: "部屋を追加", leadingSymbol: .plus, observations: [(value, frame)])
            }
        }
    }

    @Test(arguments: [false, true])
    func propertyCaptionPixelsExcludeRoundedBackgroundsAndRejectMissingText(dark: Bool) throws {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: 120, height: 60)
        let row = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemGroupedBackground.resolvedColor(with: traits).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.secondarySystemGroupedBackground.resolvedColor(with: traits).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 24).fill()
            UIColor.label.resolvedColor(with: traits).setFill()
            context.fill(CGRect(x: 30, y: 20, width: 40, height: 12))
        }
        let height = try PropertyCaptionPixels.height(in: #require(row.cgImage))
        #expect(height == 12)
        let blank = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        #expect(throws: PropertyCaptionPixels.Failure.missingForeground) {
            try PropertyCaptionPixels.height(in: #require(blank.cgImage))
        }
    }

    private func propertyCaptionImage(width: Int, dark: Bool, category: UIContentSizeCategory,
                                      forcedStandardText: Bool = false) async throws -> (image: UIImage, regions: [String: CGRect]) {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let records = try SampleRecords.make()
        try await repository.save(records)
        let store = RecordsStore(repository: repository)
        await store.load()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: 900)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        let controller = UIHostingController(rootView: NavigationStack {
            BuildingDetailView(buildingID: records.buildings[0].id)
                .transformEnvironment(\.dynamicTypeSize) { if forcedStandardText { $0 = .large } }
        }.environment(store).environment(AppNotices()).environment(\.locale, Locale(identifier: "ja_JP")))
        controller.traitOverrides.horizontalSizeClass = width < 600 ? .compact : .regular
        controller.traitOverrides.preferredContentSizeCategory = category
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        var collection: UICollectionView?
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            controller.view.layoutIfNeeded()
            collection = propertyCaptionDescendants(controller.view).compactMap { $0 as? UICollectionView }
                .first { $0.numberOfSections == 3 && $0.numberOfItems(inSection: 2) > 0 }
            if collection != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        let list = try #require(collection)
        list.scrollToItem(at: IndexPath(item: 0, section: 2), at: .centeredVertically, animated: false)
        list.layoutIfNeeded()
        let roomCell = try #require(list.cellForItem(at: IndexPath(item: list.numberOfItems(inSection: 1) - 1, section: 1)))
        let photoCell = try #require(list.cellForItem(at: IndexPath(item: 0, section: 2)))
        let buttons = propertyCaptionDescendants(photoCell).compactMap { $0 as? UIButton }
        #expect(buttons.count == 1)
        let button = try #require(buttons.first)
        #expect(button.bounds.width >= 44 && button.bounds.height >= 44, "Photo menu target: \(button.bounds)")
        let room = roomCell.convert(roomCell.bounds, to: window)
        let photo = photoCell.convert(photoCell.bounds, to: window)
        #expect(window.bounds.contains(room) && window.bounds.contains(photo))
        let header = CGRect(x: photo.minX, y: room.maxY, width: photo.width, height: photo.minY - room.maxY)
        #expect(!header.isEmpty)
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.traitCollection.displayScale
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { context in
            UIColor.systemBackground.resolvedColor(with: controller.traitCollection).setFill()
            context.fill(window.bounds)
            #expect(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let regions = ["部屋を追加": room, "写真": header, "写真を追加": photo].mapValues {
            CGRect(x: $0.minX * format.scale, y: (window.bounds.height - $0.maxY) * format.scale,
                width: $0.width * format.scale, height: $0.height * format.scale)
        }
        return (image, regions)
    }

    private func propertyCaptionDescendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(propertyCaptionDescendants)
    }

    private func propertyCaptionHeights(in capture: (image: UIImage, regions: [String: CGRect])) throws -> [String: Int] {
        let image = try #require(capture.image.cgImage)
        return try Dictionary(uniqueKeysWithValues: ["部屋を追加", "写真", "写真を追加"].map { label in
            let region = try #require(capture.regions[label])
            let raster = CGRect(x: region.minX, y: CGFloat(image.height) - region.maxY, width: region.width, height: region.height).integral
            let crop = try #require(image.cropping(to: raster))
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: crop).perform([request])
            let fragments: [(String, CGRect)] = (request.results ?? []).compactMap { observation in
                guard let value = observation.topCandidates(1).first?.string else { return nil }
                return (value, CGRect(x: observation.boundingBox.minX * CGFloat(crop.width),
                    y: observation.boundingBox.minY * CGFloat(crop.height), width: observation.boundingBox.width * CGFloat(crop.width),
                    height: observation.boundingBox.height * CGFloat(crop.height)))
            }
            do {
                _ = try PropertyCaptionRecognition.bounds(label: label,
                    leadingSymbol: label == "写真" ? nil : .plus, observations: fragments)
                return (label, try PropertyCaptionPixels.height(in: crop))
            } catch {
                let details = "\(label) region: \(region)\n\(fragments)"
                Attachment.record(Data(details.utf8), named: "Unrecognized property caption.txt")
                throw error
            }
        })
    }
}

private enum PropertyCaptionPixels {
    enum Failure: Error { case unsupportedImage, missingForeground, ambiguousForeground }

    static func height(in image: CGImage) throws -> Int {
        let (count, overflow) = image.width.multipliedReportingOverflow(by: image.height)
        guard !overflow, count > 0, count <= 1_000_000,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw Failure.unsupportedImage }
        var pixels = [UInt8](repeating: 0, count: count * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var colors: [UInt32: Int] = [:]
        var border: Set<UInt32> = []
        for pixel in 0..<count {
            let offset = pixel * 4
            guard pixels[offset + 3] == 255 else { throw Failure.unsupportedImage }
            let rgb = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            colors[rgb, default: 0] += 1
            let x = pixel % image.width
            let y = pixel / image.width
            if x == 0 || y == 0 || x == image.width - 1 || y == image.height - 1 { border.insert(rgb) }
        }
        let background = Set(colors.keys.filter { rgb in border.contains { neighbors(rgb, $0) } })
        guard colors.filter({ background.contains($0.key) }).values.reduce(0, +) > count / 2 else { throw Failure.unsupportedImage }
        let foreground = colors.filter { !background.contains($0.key) }.sorted {
            $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
        }
        guard let tone = foreground.first, tone.value >= 8 else { throw Failure.missingForeground }
        guard foreground.dropFirst().first?.value != tone.value else { throw Failure.ambiguousForeground }
        var firstRow = image.height
        var lastRow = -1
        for pixel in 0..<count {
            let offset = pixel * 4
            let rgb = UInt32(pixels[offset]) << 16 | UInt32(pixels[offset + 1]) << 8 | UInt32(pixels[offset + 2])
            if neighbors(rgb, tone.key) {
                firstRow = min(firstRow, pixel / image.width)
                lastRow = max(lastRow, pixel / image.width)
            }
        }
        guard lastRow >= firstRow else { throw Failure.missingForeground }
        return lastRow - firstRow + 1
    }

    private static func neighbors(_ first: UInt32, _ second: UInt32) -> Bool {
        [0, 8, 16].allSatisfy { abs(Int((first >> $0) & 255) - Int((second >> $0) & 255)) <= 1 }
    }
}

private enum PropertyCaptionRecognition {
    enum Failure: Error, Equatable { case missing, ambiguous, invalidGeometry }
    enum Symbol {
        case plus

        var recognizedCharacters: Set<Character> { ["+", "＋", "十", "→"] }
    }

    static func bounds(label: String, leadingSymbol: Symbol? = nil, observations: [(String, CGRect)]) throws -> CGRect {
        guard observations.allSatisfy({
            !$0.1.isEmpty && !$0.1.isInfinite && [$0.1.minX, $0.1.minY, $0.1.maxX, $0.1.maxY].allSatisfy(\.isFinite)
        }) else { throw Failure.invalidGeometry }
        let ordered = observations.sorted { $0.1.midY > $1.1.midY }
        var matches: [CGRect] = []
        for index in ordered.indices {
            var text = ""
            var frame = CGRect.null
            var previous: CGRect?
            var consumedSymbol = false
            for (fragment, bounds) in ordered[index...].prefix(3) {
                var value = fragment.filter { !$0.isWhitespace }
                if text.isEmpty, !consumedSymbol, let first = value.first, leadingSymbol?.recognizedCharacters.contains(first) == true {
                    value.removeFirst()
                    consumedSymbol = true
                }
                guard !value.isEmpty else { break }
                if let previous {
                    let gap = previous.minY - bounds.maxY
                    guard gap >= -1, gap <= max(previous.height, bounds.height) * 1.5,
                          bounds.minX < previous.maxX, bounds.maxX > previous.minX else { break }
                }
                text += value
                guard label.hasPrefix(text) else { break }
                frame = frame.union(bounds)
                if text == label { matches.append(frame); break }
                previous = bounds
            }
        }
        guard !matches.isEmpty else { throw Failure.missing }
        guard matches.count == 1 else { throw Failure.ambiguous }
        return matches[0]
    }
}
