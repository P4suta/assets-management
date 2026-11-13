import CoreGraphics
import Foundation
import UIKit
import XCTest

struct ReminderCaptionMeasurement {
    var label: String
    var formIdentity: String
    var form: CGRect
    var offscreenCaption: CGRect
    var visibleCaption: CGRect
    var anchorIdentity: String
    var originalAnchor: CGRect
    var restoredAnchor: CGRect
    var ratio: Double
}

struct NativeOffscreenReminderScope {
    var version: OperatingSystemVersion
    var idiom: UIUserInterfaceIdiom
    var screen: String
    var auditType: XCUIAccessibilityAuditType
    var compactDescription: String
    var elementType: XCUIElement.ElementType
    var label: String
    var formIdentity: String
    var matchingCaptionInForm: Bool
    var element: CGRect
    var form: CGRect
    var window: CGRect
    var measurement: ReminderCaptionMeasurement?
    var reportIndex = 1

    var accepts: Bool {
        guard version.majorVersion == 27, version.minorVersion == 2, version.patchVersion == 0,
              idiom == .pad, screen == "Repair Editor", auditType == .contrast, compactDescription == "Contrast failed",
              elementType == .staticText, label == "期限を通知", formIdentity == "editor.form",
              matchingCaptionInForm, reportIndex == 1, let measurement,
              measurement.label == label, measurement.formIdentity == formIdentity,
              measurement.form == form,
              measurement.visibleCaption.size == element.size,
              measurement.anchorIdentity == "work.title",
              measurement.originalAnchor == measurement.restoredAnchor,
              measurement.ratio.isFinite, measurement.ratio >= 4.5 else { return false }
        let frames = [element, form, window, measurement.offscreenCaption, measurement.visibleCaption,
                      measurement.originalAnchor, measurement.restoredAnchor]
        guard frames.allSatisfy(Self.valid), window.contains(form), window.contains(element),
              form.minX > window.minX, form.maxX < window.maxX,
              !form.intersects(element), window.contains(measurement.offscreenCaption), !form.intersects(measurement.offscreenCaption),
              form.contains(measurement.visibleCaption),
              form.contains(measurement.originalAnchor) else { return false }
        return true
    }

    private static func valid(_ frame: CGRect) -> Bool {
        !frame.isEmpty && [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite)
    }
}
