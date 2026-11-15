import CoreTransferable
import Foundation
import ImageIO
import PropertyCore
import UniformTypeIdentifiers

nonisolated enum PhotoProcessingError: Error, Equatable {
    case invalidImage, sourceTooLarge
}

nonisolated struct ImportedPhoto: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let data = try await Task.detached(priority: .userInitiated) {
                try PhotoProcessor.prepare(file: received.file)
            }.value
            return Self(data: data)
        }
    }
}

nonisolated enum PhotoProcessor {
    static let maximumPixelDimension = 4_096
    static let maximumSourceBytes = 100 * 1_024 * 1_024

    static func prepare(file: URL) throws -> Data {
        let source = try source(file: file)
        return try encoded(thumbnail(source: source, maximumPixelDimension: maximumPixelDimension))
    }

    static func prepare(data: Data) throws -> Data {
        guard data.count <= maximumSourceBytes else { throw PhotoProcessingError.sourceTooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw PhotoProcessingError.invalidImage
        }
        return try encoded(thumbnail(source: source, maximumPixelDimension: maximumPixelDimension))
    }

    static func thumbnail(file: URL) throws -> CGImage {
        try thumbnail(source: source(file: file), maximumPixelDimension: 2_048)
    }

    private static func source(file: URL) throws -> CGImageSource {
        guard file.isFileURL else { throw PhotoProcessingError.invalidImage }
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, let bytes = values.fileSize, bytes >= 0 else {
            throw PhotoProcessingError.invalidImage
        }
        guard bytes <= maximumSourceBytes else { throw PhotoProcessingError.sourceTooLarge }
        guard let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw PhotoProcessingError.invalidImage
        }
        return source
    }

    private static func thumbnail(source: CGImageSource, maximumPixelDimension: Int) throws -> CGImage {
        guard let identifier = CGImageSourceGetType(source), UTType(identifier as String)?.conforms(to: .image) == true else {
            throw PhotoProcessingError.invalidImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              image.width > 0, image.height > 0, max(image.width, image.height) <= maximumPixelDimension else {
            throw PhotoProcessingError.invalidImage
        }
        return image
    }

    private static func encoded(_ image: CGImage) throws -> Data {
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw PhotoProcessingError.invalidImage
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination), bytes.length > 0 else { throw PhotoProcessingError.invalidImage }
        guard bytes.length <= FileRecordsRepository.maximumAttachmentBytes else { throw PhotoProcessingError.sourceTooLarge }
        return bytes as Data
    }
}
