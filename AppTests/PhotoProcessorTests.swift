import Foundation
import ImageIO
import PropertyCore
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import PropertyRecords

@Suite @MainActor struct PhotoProcessorTests {
    @Test func largeImagesShrinkAndSmallImagesKeepTheirDimensions() throws {
        for size in [CGSize(width: 9_000, height: 30), CGSize(width: 32, height: 18)] {
            let data = try PhotoProcessor.prepare(data: fixture(size: size))
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width > 0 && image.height > 0)
            #expect(max(image.width, image.height) <= PhotoProcessor.maximumPixelDimension)
            #expect(data.count <= FileRecordsRepository.maximumAttachmentBytes)
            if size.width < CGFloat(PhotoProcessor.maximumPixelDimension) {
                #expect(image.width == Int(size.width))
                #expect(image.height == Int(size.height))
            }
        }
    }

    @Test func thumbnailsApplyImageOrientationAndDropLocationMetadata() throws {
        let original = try #require(CGImageSourceCreateWithData(fixture(size: CGSize(width: 48, height: 24)) as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(original, 0, nil))
        let bytes = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 35.0, kCGImagePropertyGPSLatitudeRef: "N"]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let prepared = try PhotoProcessor.prepare(data: bytes as Data)
        let source = try #require(CGImageSourceCreateWithData(prepared as CFData, nil))
        let rotated = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(rotated.width == 24)
        #expect(rotated.height == 48)
        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        #expect(metadata?[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test func invalidAndOversizedSourcesFailBeforeImageDecoding() throws {
        #expect(throws: PhotoProcessingError.invalidImage) { try PhotoProcessor.prepare(data: Data()) }
        #expect(throws: PhotoProcessingError.invalidImage) { try PhotoProcessor.prepare(data: Data("not an image".utf8)) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("large-photo.jpg")
        #expect(FileManager.default.createFile(atPath: file.path, contents: Data()))
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(PhotoProcessor.maximumSourceBytes) + 1)
        try handle.close()
        #expect(throws: PhotoProcessingError.sourceTooLarge) { try PhotoProcessor.prepare(file: file) }
        let valid = directory.appendingPathComponent("valid.png")
        try fixture(size: CGSize(width: 32, height: 18)).write(to: valid)
        let link = directory.appendingPathComponent("linked-photo.jpg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: valid)
        #expect(throws: PhotoProcessingError.invalidImage) { try PhotoProcessor.prepare(file: link) }
        #expect(throws: PhotoProcessingError.invalidImage) { try PhotoProcessor.prepare(file: directory) }
        let remote = try #require(URL(string: "https://example.com/photo.jpg"))
        #expect(throws: PhotoProcessingError.invalidImage) { try PhotoProcessor.prepare(file: remote) }
    }

    @Test func fileImportsAndDisplayThumbnailsStayBounded() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: file) }
        try fixture(size: CGSize(width: 6_000, height: 40)).write(to: file)
        let data = try PhotoProcessor.prepare(file: file)
        #expect(!data.isEmpty)
        let thumbnail = try PhotoProcessor.thumbnail(file: file)
        #expect(max(thumbnail.width, thumbnail.height) <= 2_048)
    }

    private func fixture(size: CGSize) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.systemIndigo.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
