import Foundation
import Testing
import UIKit

@Suite(.serialized) @MainActor struct NativePresentationTests {
    @discardableResult
    func verifyText(in image: CGImage, languages: [String], expectation: RenderedTextExpectation) throws -> [RecognizedFragment]? {
        if ProcessInfo.processInfo.environment["NATIVE_TEXT_CAPTURE"] == "1" {
            if #available(iOS 26.1, *) {
                try #require(ProcessInfo.processInfo.isiOSAppOnVision)
            } else {
                throw RenderedTextFailure.unavailableRecognition
            }
            let check = RenderedTextCheck(id: UUID(), languages: languages, expectation: expectation)
            Attachment.record(try JSONEncoder().encode(check), named: RenderedTextCheck.requestPrefix + check.id.uuidString + ".json")
            Attachment.record(try #require(UIImage(cgImage: image).pngData()),
                              named: RenderedTextCheck.imagePrefix + check.id.uuidString + ".png")
            return nil
        }
        let caption: String?
        if case .caption(let label, _) = expectation { caption = label } else { caption = nil }
        let fragments = try NativeTextRecognition.recognize(image, languages: languages, caption: caption)
        try expectation.verify(fragments)
        return fragments
    }

    func requiredTextEnlargement() throws -> CGFloat {
        guard ProcessInfo.processInfo.isiOSAppOnMac else { return 2 }
        let normal = UIFont.preferredFont(forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)).pointSize
        let maximum = UIFont.preferredFont(forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)).pointSize
        try #require(normal > 0 && maximum >= normal)
        return maximum / normal
    }

    @Test func nativeRecognitionReadsAnExactDateAndRejectsABlankImage() throws {
        for text in ["2025/04/01", ""] {
            let size = CGSize(width: 480, height: 100)
            let image = UIGraphicsImageRenderer(size: size).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                (text as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 40), .foregroundColor: UIColor.black
                ])
            }
            Attachment.record(try #require(image.pngData()), named: text.isEmpty ? "Blank recognition fixture.png" : "Date recognition fixture.png")
            try verifyText(in: #require(image.cgImage), languages: ["en-US"],
                           expectation: .exact(text.isEmpty ? [] : [text]))
        }
    }
}
