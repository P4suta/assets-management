import UIKit
import XCTest

struct NativeCalendarTextScope {
    var version: OperatingSystemVersion
    var idiom: UIUserInterfaceIdiom
    var screen: String
    var auditType: XCUIAccessibilityAuditType
    var compactDescription: String
    var detail: String
    var hasElement: Bool
    var calendar: CGRect
    var done: CGRect
    var window: CGRect
    var dayCount: Int
    var allDaysLabeled: Bool
    var reportIndex = 1

    var accepts: Bool {
        guard version.majorVersion == 27, version.minorVersion == 2, version.patchVersion == 0,
              idiom == .pad, screen == "Calendar Date Picker", auditType == .elementDetection,
              compactDescription == "Potentially inaccessible text",
              detail == "This element appears to display text that should be represented using the accessibility API.",
              !hasElement, (28...42).contains(dayCount), allDaysLabeled, reportIndex == 1 else { return false }
        return [calendar, done, window].allSatisfy {
            !$0.isEmpty && !$0.isInfinite && [$0.minX, $0.minY, $0.width, $0.height].allSatisfy(\.isFinite)
        } && window.contains(calendar) && window.contains(done) && !calendar.intersects(done)
            && calendar.minX > window.minX && calendar.maxX < window.maxX
    }
}
