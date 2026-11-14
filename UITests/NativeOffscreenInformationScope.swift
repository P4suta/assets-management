import UIKit
import XCTest

struct InformationTextMeasurement {
    let label: String
    let visibleFrame: CGRect
    let ratio: Double
}

struct NativeOffscreenInformationScope {
    var version: OperatingSystemVersion
    var idiom: UIUserInterfaceIdiom
    var screen: String
    var auditType: XCUIAccessibilityAuditType
    var compactDescription: String
    var elementType: XCUIElement.ElementType
    var identifier: String
    var label: String
    var matchingElement: Bool
    var element: CGRect
    var list: CGRect
    var window: CGRect
    var measurement: InformationTextMeasurement

    var accepts: Bool {
        guard version.majorVersion == 27, version.minorVersion == 2, version.patchVersion == 0,
              idiom == .pad, screen == "App information", auditType == .contrast,
              compactDescription == "Contrast failed", elementType == .staticText,
              ["app-info.records", "app-info.support", "app-info.copyright"].contains(identifier), matchingElement,
              label == measurement.label, element.size == measurement.visibleFrame.size,
              measurement.ratio.isFinite, measurement.ratio >= 4.5 else { return false }
        let frames = [element, list, window, measurement.visibleFrame]
        return frames.allSatisfy { !$0.isEmpty && [$0.minX, $0.minY, $0.width, $0.height].allSatisfy(\.isFinite) }
            && window.contains(list) && list.minX > window.minX && list.maxX < window.maxX
            && !list.contains(element) && list.contains(measurement.visibleFrame)
    }
}
