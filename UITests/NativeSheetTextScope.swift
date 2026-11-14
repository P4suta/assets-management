import CoreGraphics
import Foundation
import UIKit
import XCTest

struct NativeSheetTextScope {
    var version: OperatingSystemVersion
    var idiom: UIUserInterfaceIdiom
    var screen: String
    var auditType: XCUIAccessibilityAuditType
    var compactDescription: String
    var hasElement: Bool
    var controlsReadable: Bool
    var editor: CGRect
    var window: CGRect
    var reportIndex = 1

    var accepts: Bool {
        let reproducedVersion = (version.majorVersion == 26 && version.minorVersion == 0)
            || (version.majorVersion == 27 && version.minorVersion == 2)
        let reproducedScreen = ["Repair Editor", "Renewal Editor", "Building Editor"].contains(screen)
            || (version.majorVersion == 27 && ["History Editor", "Room Editor", "Contract Editor"].contains(screen))
            || (version.majorVersion == 26 && ["Schedule Editor", "Equipment Editor"].contains(screen))
        guard reproducedVersion, version.patchVersion == 0,
              idiom == .pad, reproducedScreen,
              auditType == .elementDetection, compactDescription == "Potentially inaccessible text",
              !hasElement, controlsReadable else { return false }
        let coordinates = [editor.minX, editor.minY, editor.width, editor.height,
                           window.minX, window.minY, window.width, window.height]
        guard coordinates.allSatisfy(\.isFinite), !editor.isEmpty, !window.isEmpty,
              window.contains(editor), editor.minX >= window.minX + 16,
              editor.maxX <= window.maxX - 16 else { return false }
        let maximumReports: Int
        switch (version.majorVersion, screen) {
        case (26, "Repair Editor"), (27, "Renewal Editor"): maximumReports = 2
        default: maximumReports = 1
        }
        return (1...maximumReports).contains(reportIndex)
    }
}

struct NativeScheduleControls {
    var dateType: XCUIElement.ElementType
    var dateLabel: String
    var captionLabel: String
    var buttonLabel: String
    var buttonValue: String
    var enabledLabel: String
    var enabledValue: String
    var reminderLabel: String
    var reminderValue: String
    var reachable: Bool

    var accepts: Bool {
        dateType == .datePicker && dateLabel.isEmpty && captionLabel == "予定日時"
            && buttonLabel == "日付と時間ピッカー" && !buttonValue.isEmpty
            && enabledLabel == "予定を設定" && enabledValue == "1"
            && reminderLabel == "予定を通知" && reminderValue == "0" && reachable
    }
}
