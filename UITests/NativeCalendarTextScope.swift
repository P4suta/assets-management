import UIKit
import XCTest

struct NativeCalendarMonth {
    let year: Int
    let month: Int

    init?(heading: String) {
        let value = heading.filter { !$0.isWhitespace }
        guard value.range(of: #"^[0-9]{4}年[0-9]{1,2}月$"#, options: .regularExpression) != nil else { return nil }
        let parts = value.split(whereSeparator: { $0 == "年" || $0 == "月" })
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]),
              (1...9999).contains(year), (1...12).contains(month) else { return nil }
        self.year = year
        self.month = month
    }

    func containsEveryDay(_ labels: [String]) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let expected = calendar.range(of: .day, in: .month, for: date) else { return false }
        let days = labels.compactMap { label -> Int? in
            guard label.range(of: #"^[0-9]+月[0-9]+日 .+"#, options: .regularExpression) != nil else { return nil }
            let parts = label.prefix(while: { $0 != " " }).split(whereSeparator: { $0 == "月" || $0 == "日" })
            guard parts.count == 2, Int(parts[0]) == month else { return nil }
            return Int(parts[1])
        }
        return days.count == labels.count && Set(days).count == days.count && Set(days) == Set(expected)
    }
}

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
        } && window.containsWithRoundingTolerance(calendar) && window.containsWithRoundingTolerance(done) && !calendar.intersects(done)
            && calendar.minX > window.minX && calendar.maxX < window.maxX
    }
}
