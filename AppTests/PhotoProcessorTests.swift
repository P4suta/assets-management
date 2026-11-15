import Foundation
import ImageIO
import PropertyCore
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import PropertyRecords

@Suite @MainActor struct PhotoProcessorTests {
    @Test(.timeLimit(.minutes(1))) func cameraEncodingRunsOffTheMainActorAndDeliversOnTheMainActor() async throws {
        let image = try #require(UIImage(data: fixture(size: CGSize(width: 32, height: 18))))
        let data = await withCheckedContinuation { continuation in
            let coordinator = CameraCapture.Coordinator(completion: { data in
                MainActor.preconditionIsolated()
                continuation.resume(returning: data)
            }, encode: { image in
                #expect(!Thread.isMainThread)
                return image.jpegData(compressionQuality: 0.85)
            })
            coordinator.imagePickerController(UIImagePickerController(), didFinishPickingMediaWithInfo: [.originalImage: image])
        }
        let encoded = try #require(data)
        let source = try #require(CGImageSourceCreateWithData(encoded as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 32 && decoded.height == 18)
    }

    @Test(.timeLimit(.minutes(1))) func cameraCancellationDiscardsPendingEncodingAndCompletesOnce() async throws {
        let image = try #require(UIImage(data: fixture(size: CGSize(width: 32, height: 18))))
        for waitForEncoding in [false, true] {
            let gate = DispatchSemaphore(value: 0)
            let started = AsyncStream<Void>.makeStream()
            defer { gate.signal(); started.continuation.finish() }
            var completions = 0
            let coordinator = CameraCapture.Coordinator(completion: { data in
                #expect(data == nil)
                completions += 1
            }, encode: { _ in
                started.continuation.yield(())
                #expect(gate.wait(timeout: .now() + 5) == .success)
                return Data([1])
            })
            let picker = UIImagePickerController()
            coordinator.imagePickerController(picker, didFinishPickingMediaWithInfo: [.originalImage: image])
            let task = try #require(coordinator.encodingTask)
            if waitForEncoding {
                var iterator = started.stream.makeAsyncIterator()
                #expect(await iterator.next() != nil)
            }
            coordinator.imagePickerControllerDidCancel(picker)
            gate.signal()
            await task.value
            #expect(completions == 1)
            #expect(coordinator.encodingTask == nil)
        }
    }

    @Test func missingAndCancelledCameraImagesDeliverNilWithoutEncoding() {
        var results = 0
        let coordinator = CameraCapture.Coordinator(completion: { data in
            MainActor.preconditionIsolated()
            #expect(data == nil)
            results += 1
        }, encode: { _ in Issue.record("Missing camera images must not reach the encoder."); return Data() })
        let picker = UIImagePickerController()
        coordinator.imagePickerController(picker, didFinishPickingMediaWithInfo: [:])
        coordinator.imagePickerControllerDidCancel(picker)
        let cancelled = CameraCapture.Coordinator(completion: { data in
            #expect(data == nil)
            results += 1
        }, encode: { _ in Issue.record("Cancelled camera images must not reach the encoder."); return Data() })
        cancelled.imagePickerControllerDidCancel(picker)
        cancelled.imagePickerController(picker, didFinishPickingMediaWithInfo: [:])
        #expect(results == 2)
    }

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
