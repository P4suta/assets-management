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
        let normal = try propertyCaptionBounds(in: standard)
        let enlarged = try propertyCaptionBounds(in: largest)
        for label in ["部屋を追加", "写真"] {
            let initial = try #require(normal[label])
            let scaled = try #require(enlarged[label])
            #expect(scaled.height >= initial.height * 2, "\(label) glyph heights: \(initial.height), \(scaled.height)")
        }
    }

    @Test func propertyCaptionMeasurementRejectsAStandardSizeOverride() async throws {
        let standard = try await propertyCaptionImage(width: 420, dark: false, category: .large)
        let frozen = try await propertyCaptionImage(width: 420, dark: false, category: .accessibilityExtraExtraExtraLarge, forcedStandardText: true)
        let normal = try propertyCaptionBounds(in: standard)
        let unchanged = try propertyCaptionBounds(in: frozen)
        for label in ["部屋を追加", "写真"] {
            #expect(try #require(unchanged[label]).height < #require(normal[label]).height * 2)
        }
    }

    @Test func propertyCaptionRecognitionRejectsMissingAndAmbiguousText() throws {
        let first = CGRect(x: 10, y: 70, width: 80, height: 20)
        let second = CGRect(x: 10, y: 40, width: 60, height: 20)
        #expect(try PropertyCaptionRecognition.bounds(label: "部屋を追加", observations: [
            ("＋部屋を", first), ("追加", second)
        ]) == first.union(second))
        #expect(throws: PropertyCaptionRecognition.Failure.missing) {
            try PropertyCaptionRecognition.bounds(label: "部屋を追加", observations: [("部屋を…", first)])
        }
        #expect(throws: PropertyCaptionRecognition.Failure.ambiguous) {
            try PropertyCaptionRecognition.bounds(label: "写真", observations: [("写真", first), ("写真", second)])
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
        let regions = ["部屋を追加": room, "写真": header].mapValues {
            CGRect(x: $0.minX * format.scale, y: (window.bounds.height - $0.maxY) * format.scale,
                width: $0.width * format.scale, height: $0.height * format.scale)
        }
        return (image, regions)
    }

    private func propertyCaptionDescendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(propertyCaptionDescendants)
    }

    private func propertyCaptionBounds(in capture: (image: UIImage, regions: [String: CGRect])) throws -> [String: CGRect] {
        let image = try #require(capture.image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let observations: [(String, CGRect)] = (request.results ?? []).compactMap { observation in
            guard let value = observation.topCandidates(1).first?.string else { return nil }
            return (value, CGRect(x: observation.boundingBox.minX * CGFloat(image.width),
                y: observation.boundingBox.minY * CGFloat(image.height), width: observation.boundingBox.width * CGFloat(image.width),
                height: observation.boundingBox.height * CGFloat(image.height)))
        }
        return try Dictionary(uniqueKeysWithValues: ["部屋を追加", "写真"].map { label in
            let region = try #require(capture.regions[label])
            return (label, try PropertyCaptionRecognition.bounds(label: label, observations: observations.filter { region.contains($0.1) }))
        })
    }
}

private enum PropertyCaptionRecognition {
    enum Failure: Error, Equatable { case missing, ambiguous, invalidGeometry }

    static func bounds(label: String, observations: [(String, CGRect)]) throws -> CGRect {
        guard observations.allSatisfy({
            !$0.1.isEmpty && !$0.1.isInfinite && [$0.1.minX, $0.1.minY, $0.1.maxX, $0.1.maxY].allSatisfy(\.isFinite)
        }) else { throw Failure.invalidGeometry }
        let ordered = observations.sorted { $0.1.midY > $1.1.midY }
        var matches: [CGRect] = []
        for index in ordered.indices {
            var text = ""
            var frame = CGRect.null
            var previous: CGRect?
            for (fragment, bounds) in ordered[index...].prefix(3) {
                let value = fragment.filter { !$0.isWhitespace && $0 != "+" && $0 != "＋" }
                guard !value.isEmpty else { continue }
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
