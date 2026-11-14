import UIKit
import Vision
import XCTest

struct RenderedDateValue {
    var value: String
    var recognized: String
    var bounds: CGRect
    var required: CGSize

    var fits: Bool {
        value.range(of: "^[0-9]{4}/[0-9]{2}/[0-9]{2}$", options: .regularExpression) != nil
            && value == recognized
            && [bounds.minX, bounds.minY, bounds.width, bounds.height, required.width, required.height].allSatisfy(\.isFinite)
            && required.width > 0 && required.height > 0
            && bounds.width >= required.width * 0.8 + 24 && bounds.height >= required.height + 10
    }
}

struct NativeDateClippingScope {
    var version: OperatingSystemVersion
    var screen: String
    var auditType: XCUIAccessibilityAuditType
    var detail: String
    var hasElement: Bool
    var largest: Bool
    var viewport: CGRect
    var window: CGRect
    var dates: [RenderedDateValue]
    var reportIndex: Int

    var accepts: Bool {
        version.majorVersion == 27 && version.minorVersion == 2 && version.patchVersion == 0
            && screen == "Contract Editor" && auditType == .textClipped
            && detail == "Text of this UILabel may be clipped at larger Dynamic Type sizes."
            && !hasElement && largest && reportIndex == 1 && dates.count == 2
            && !viewport.isEmpty && !window.isEmpty && window.contains(viewport)
            && dates.allSatisfy { $0.fits && viewport.contains($0.bounds) }
            && !dates[0].bounds.intersects(dates[1].bounds)
    }
}

enum RenderedDateRecognition {
    static func text(in image: CGImage) throws -> String {
        guard image.width <= 2_000, image.height <= 2_000 else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().filter { !$0.isWhitespace }
    }
}
