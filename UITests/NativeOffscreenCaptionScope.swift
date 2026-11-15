import UIKit
import XCTest

struct NativeOffscreenCaptionScope {
    var version: OperatingSystemVersion
    var screen: String
    var auditType: XCUIAccessibilityAuditType
    var detail: String
    var elementType: XCUIElement.ElementType
    var label: String
    var matchingCaption: Bool
    var element: CGRect
    var listIdentity: String
    var list: CGRect
    var window: CGRect
    var bars: [CGRect]
    var measurement: NativeCaptionClippingScope?

    @MainActor var accepts: Bool {
        guard screen == "Contact", listIdentity == "contact.detail", label == "緊急連絡先",
              auditType == .textClipped, elementType == .staticText, matchingCaption,
              detail == "Text of this SwiftUI.AccessibilityNode may be clipped at larger Dynamic Type sizes.",
              let measurement, measurement.accepts,
              measurement.version.majorVersion == version.majorVersion,
              measurement.version.minorVersion == version.minorVersion,
              measurement.version.patchVersion == version.patchVersion,
              measurement.screen == screen, measurement.label == label,
              measurement.viewport == list, measurement.window == window, measurement.bars == bars,
              [element, list, window].allSatisfy({
                  !$0.isEmpty && !$0.isInfinite
                      && [$0.minX, $0.minY, $0.maxX, $0.maxY].allSatisfy(\.isFinite)
              }),
              window.containsWithRoundingTolerance(list), element.intersects(list),
              abs(element.width - measurement.element.width) <= 1 / measurement.scale,
              abs(element.height - measurement.element.height) <= 1 / measurement.scale else { return false }
        return !window.containsWithRoundingTolerance(element) || bars.contains { $0.intersects(element) }
    }
}
