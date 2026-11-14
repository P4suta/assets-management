import UIKit
import XCTest

struct NativeListTextMeasurement {
    var label: String
    var frame: CGRect
    var renderedHeight: Int
    var minimumHeight: Int
}

struct NativeListTypeScope {
    var version: OperatingSystemVersion
    var idiom: UIUserInterfaceIdiom
    var screen: String
    var auditType: XCUIAccessibilityAuditType
    var compactDescription: String
    var detail: String
    var hasElement: Bool
    var textSize: UIContentSizeCategory
    var listIdentity: String
    var matchingCaptions: Bool
    var measurements: [String: NativeListTextMeasurement]
    var list: CGRect
    var window: CGRect
    var reportIndex = 1

    var accepts: Bool {
        let floorRuntime = version.majorVersion == 26 && version.minorVersion == 5
        let laterRuntime = version.majorVersion == 27 && version.minorVersion == 2
        let contact = screen == "Contact" && listIdentity == "contact.detail"
        guard floorRuntime || laterRuntime, version.patchVersion == 0, contact,
              idiom == .phone, auditType == .dynamicType,
              compactDescription == "Dynamic Type font sizes are partially unsupported",
              detail == "User will not be able to change the font size of this SwiftUI.AccessibilityNode",
              !hasElement, textSize == .accessibilityExtraExtraExtraLarge, matchingCaptions,
              measurements.count == 1, reportIndex == 1 else { return false }
        let frames = [list, window] + measurements.values.map(\.frame)
        return frames.allSatisfy {
            !$0.isEmpty && !$0.isInfinite && [$0.minX, $0.minY, $0.width, $0.height].allSatisfy(\.isFinite)
        } && window.containsWithRoundingTolerance(list) && measurements.allSatisfy { identifier, measurement in
            identifier.hasPrefix("contact.related.") && !measurement.label.isEmpty
                && list.containsWithRoundingTolerance(measurement.frame) && window.containsWithRoundingTolerance(measurement.frame)
                && measurement.minimumHeight > 0 && measurement.renderedHeight >= measurement.minimumHeight
        }
    }
}
