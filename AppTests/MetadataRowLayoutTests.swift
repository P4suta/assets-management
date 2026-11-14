import PropertyCore
import SwiftUI
import Testing
import UIKit
@testable import PropertyRecords

private enum MetadataScreen: CaseIterable, Sendable {
    case contact, work, building, room, contract

    var section: Int { self == .work || self == .contract ? 1 : 0 }
    var rowCount: Int { self == .contact ? 7 : 3 }

    @MainActor func view(records: Records) -> AnyView {
        switch self {
        case .contact: AnyView(ContactDetailView(contactID: records.contacts[0].id))
        case .work: AnyView(WorkDetailView(workID: records.work[0].id))
        case .building: AnyView(BuildingDetailView(buildingID: records.buildings[0].id))
        case .room: AnyView(RoomDetailView(roomID: records.rooms[0].id))
        case .contract: AnyView(ContractDetailView(roomID: records.rooms[0].id))
        }
    }
}

private struct MetadataLayoutProfile: Sendable {
    let width: Int
    let dark: Bool
    let largest: Bool

    static var all: [Self] {
        [320, 420, 600, 1024].flatMap { width in
            [false, true].flatMap { dark in
                [false, true].map { Self(width: width, dark: dark, largest: $0) }
            }
        }
    }
}

@Suite(.serialized) @MainActor struct MetadataRowLayoutTests {
    @Test(arguments: MetadataScreen.allCases, MetadataLayoutProfile.all)
    fileprivate func metadataSeparatorsAlignAcrossWidthsAndTextSizes(screen: MetadataScreen, profile: MetadataLayoutProfile) async throws {
        let (width, dark, largest) = (profile.width, profile.dark, profile.largest)
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        var records = try SampleRecords.make()
        records.contacts[0].phone = "03-0000-0000"
        records.contacts[0].email = "maintenance@example.com"
        try await repository.save(records)
        let store = RecordsStore(repository: repository)
        await store.load()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: 900)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        let controller = UIHostingController(rootView: NavigationStack {
            screen.view(records: records)
        }.environment(store).environment(AppNotices()).environment(\.locale, Locale(identifier: "ja_JP")))
        controller.traitOverrides.horizontalSizeClass = width < 600 ? .compact : .regular
        controller.traitOverrides.preferredContentSizeCategory = largest ? .accessibilityExtraExtraExtraLarge : .large
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let collection = try #require(await waitForCollection(in: controller.view, screen: screen))
        var starts: [CGFloat] = []
        var previous: CGRect?
        for item in 0..<screen.rowCount {
            let index = IndexPath(item: item, section: screen.section)
            collection.scrollToItem(at: index, at: .centeredVertically, animated: false)
            let cell = try #require(await waitForCell(at: index, in: collection))
            let frame = cell.convert(cell.bounds, to: window)
            #expect(!frame.isEmpty && window.bounds.contains(frame))
            if let previous { #expect(previous.maxY <= cell.frame.minY + 1) }
            previous = cell.frame
            guard item < screen.rowCount - 1 else { continue }
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            do {
                starts.append(try RowSeparatorMeasurement.leading(image: image, row: frame))
            } catch {
                Attachment.record(try #require(image.pngData()), named: "\(screen)-\(width)-\(dark)-\(largest)-row-\(item).png")
                throw error
            }
        }
        #expect(starts.count == screen.rowCount - 1)
        let reference = try #require(starts.first)
        #expect(reference > 0, "Separators must start at the content inset: \(starts)")
        #expect(starts.allSatisfy { abs($0 - reference) <= 1 }, "Metadata separators must align: \(starts)")
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        Attachment.record(try #require(image.pngData()), named: "\(screen)-\(width)-\(dark)-\(largest).png")
    }

    @Test func separatorMeasurementRejectsMissingAndAmbiguousLines() throws {
        func fixture(_ lines: [(CGFloat, CGFloat)]) -> UIImage {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = true
            return UIGraphicsImageRenderer(size: CGSize(width: 320, height: 80), format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 320, height: 80))
                UIColor.lightGray.setFill()
                for (leading, top) in lines { context.fill(CGRect(x: leading, y: top, width: 320 - leading, height: 0.5)) }
            }
        }
        let row = CGRect(x: 0, y: 0, width: 320, height: 44)
        for inset in [CGFloat(20), CGFloat(60)] {
            #expect(try RowSeparatorMeasurement.leading(image: fixture([(inset, 43.5)]), row: row) == inset)
            #expect(try RowSeparatorMeasurement.leading(image: fixture([(inset, 43.5), (0, 44)]), row: row) == inset)
        }
        #expect(throws: RowSeparatorMeasurementError.missing) {
            try RowSeparatorMeasurement.leading(image: fixture([]), row: row)
        }
        #expect(throws: RowSeparatorMeasurementError.ambiguous) {
            try RowSeparatorMeasurement.leading(image: fixture([(20, 42), (60, 43.5)]), row: row)
        }
        #expect(throws: RowSeparatorMeasurementError.missing) {
            try RowSeparatorMeasurement.leading(image: fixture([(0, 44)]), row: row)
        }
    }

    private func waitForCollection(in view: UIView, screen: MetadataScreen) async -> UICollectionView? {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            view.layoutIfNeeded()
            if let collection = collection(in: view), collection.numberOfSections > screen.section,
               collection.numberOfItems(inSection: screen.section) == screen.rowCount, !collection.visibleCells.isEmpty { return collection }
            try? await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        return nil
    }

    private func waitForCell(at index: IndexPath, in collection: UICollectionView) async -> UICollectionViewCell? {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        repeat {
            collection.layoutIfNeeded()
            if let cell = collection.cellForItem(at: index), !cell.bounds.isEmpty { return cell }
            try? await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        return nil
    }

    private func collection(in view: UIView) -> UICollectionView? {
        if let collection = view as? UICollectionView { return collection }
        for child in view.subviews {
            if let collection = collection(in: child) { return collection }
        }
        return nil
    }
}

private enum RowSeparatorMeasurementError: Error, Equatable { case unsupported, missing, ambiguous }

private enum RowSeparatorMeasurement {
    static func leading(image: UIImage, row: CGRect) throws -> CGFloat {
        let scale = image.scale
        guard scale.isFinite, scale > 0, !row.isEmpty, let bitmap = image.cgImage else {
            throw RowSeparatorMeasurementError.unsupported
        }
        let area = CGRect(x: row.minX * scale, y: (row.maxY - 3) * scale,
                          width: row.width * scale, height: 6 * scale).integral
        guard CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height).contains(area),
              let crop = bitmap.cropping(to: area), crop.width * crop.height <= 100_000 else {
            throw RowSeparatorMeasurementError.unsupported
        }
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { throw RowSeparatorMeasurementError.unsupported }
        try bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: crop.width, height: crop.height,
                                          bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: space,
                                          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw RowSeparatorMeasurementError.unsupported
            }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        }
        let distance = max(2, Int(scale))
        func differs(_ x: Int, _ y: Int, _ neighbor: Int) -> Bool {
            let index = (y * crop.width + x) * 4
            let other = (neighbor * crop.width + x) * 4
            return bytes[index + 3] == 255 && bytes[other + 3] == 255
                && (0..<3).contains { abs(Int(bytes[index + $0]) - Int(bytes[other + $0])) >= 3 }
        }
        var starts: [Int] = []
        let rowEnd = min(crop.height - distance, Int(ceil(row.maxY * scale - area.minY)))
        guard rowEnd > distance else { throw RowSeparatorMeasurementError.unsupported }
        for y in distance..<rowEnd {
            var start = 0
            for x in 0...crop.width {
                let part = x < crop.width && differs(x, y, y - distance) && differs(x, y, y + distance)
                if part { continue }
                if x - start > crop.width / 2 { starts.append(start) }
                start = x + 1
            }
        }
        guard let first = starts.first else { throw RowSeparatorMeasurementError.missing }
        guard starts.allSatisfy({ abs($0 - first) <= 1 }) else { throw RowSeparatorMeasurementError.ambiguous }
        return CGFloat(first) / scale
    }
}
