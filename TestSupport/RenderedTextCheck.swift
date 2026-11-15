import CoreGraphics
import Foundation
import Vision

struct RecognizedFragment {
    let text: String
    let bounds: CGRect
}

enum RenderedTextExpectation: Codable {
    case exact([String])
    case dates([String], present: Bool)
    case caption(String, leadingPlus: Bool)

    func verify(_ fragments: [RecognizedFragment]) throws {
        let values = fragments.map { $0.text.filter { !$0.isWhitespace } }
        switch self {
        case .exact(let expected):
            guard values == expected else { throw RenderedTextFailure.unexpectedText(values) }
        case .dates(let dates, let present):
            guard !dates.isEmpty, dates.allSatisfy({ value in
                values.contains(where: { $0.contains(value) }) == present
            }) else { throw RenderedTextFailure.unexpectedText(values) }
        case .caption(let label, let leadingPlus):
            _ = try PropertyCaptionRecognition.bounds(label: label, leadingSymbol: leadingPlus ? .plus : nil,
                observations: fragments.map { ($0.text, $0.bounds) })
        }
    }
}

enum RenderedTextFailure: Error {
    case unexpectedText([String])
    case unavailableRecognition
    case invalidInventory
}

struct RenderedTextCheck: Codable {
    let id: UUID
    let languages: [String]
    let expectation: RenderedTextExpectation

    static let requestPrefix = "NativeTextRequest-"
    static let imagePrefix = "NativeTextImage-"
}

enum RenderedTextInventory {
    static let expected = [
        "NativePresentationTests/nativeRecognitionReadsAnExactDateAndRejectsABlankImage()": 2,
        "NativePresentationTests/contractDatesRemainCompleteAtStandardAndLargestTextSizes(width:)": 4,
        "NativePresentationTests/dateRecognitionRejectsNativeEllipsis()": 2,
        "NativePresentationTests/propertyCaptionGlyphsRespectNativeTextMetrics(width:dark:)": 36,
        "NativePresentationTests/propertyCaptionMeasurementTracksAStandardSizeOverride()": 6
    ]

    static func verify(counts: [String: Int], identifiers: [UUID], imageCount: Int) throws {
        guard counts == expected, identifiers.count == expected.values.reduce(0, +),
              Set(identifiers).count == identifiers.count, imageCount == identifiers.count else {
            throw RenderedTextFailure.invalidInventory
        }
    }
}

enum NativeTextRecognition {
    static func recognize(_ image: CGImage, languages: [String], caption: String? = nil) throws -> [RecognizedFragment] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = false
        guard !languages.isEmpty, Set(languages).isSubset(of: Set(try request.supportedRecognitionLanguages())) else {
            throw RenderedTextFailure.unavailableRecognition
        }
        try VNImageRequestHandler(cgImage: image).perform([request])
        guard let observations = request.results else { throw RenderedTextFailure.unavailableRecognition }
        return try observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            var bounds = observation.boundingBox
            if let caption, let range = candidate.string.range(of: caption), let box = try candidate.boundingBox(for: range) {
                bounds = box.boundingBox
            }
            return RecognizedFragment(text: candidate.string, bounds: CGRect(
                x: bounds.minX * CGFloat(image.width), y: bounds.minY * CGFloat(image.height),
                width: bounds.width * CGFloat(image.width), height: bounds.height * CGFloat(image.height)))
        }
    }
}
