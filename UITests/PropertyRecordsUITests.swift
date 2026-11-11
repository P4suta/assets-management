import XCTest
import UIKit

@MainActor
final class PropertyRecordsUITests: XCTestCase {
    func testPropertyRegistrationPersistsAfterRelaunch() {
        let app = launch()
        app.buttons["property.add"].tap()
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["建物名を入力してください。"].waitForExistence(timeout: 5))
        enter("桜通りレジデンス", into: "property.name", app: app)
        enter("203", into: "property.room", app: app)
        app.buttons["editor.cancel"].tap()
        app.alerts.buttons["編集を続ける"].tap()
        XCTAssertEqual(app.textFields["property.name"].value as? String, "桜通りレジデンス")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(row("桜通りレジデンス", app: app).waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["物件"].tap()
        XCTAssertTrue(row("桜通りレジデンス", app: app).waitForExistence(timeout: 5))
    }

    func testFailedSavePreservesInputAndRetrySucceeds() {
        let app = launch(failFirstSave: true)
        app.buttons["property.add"].tap()
        enter("青葉コート", into: "property.name", app: app)
        enter("201", into: "property.room", app: app)
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["editor.error"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["property.name"].value as? String, "青葉コート")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(row("青葉コート", app: app).waitForExistence(timeout: 5))
    }

    func testDiscardDoesNotCreateAProperty() {
        let app = launch()
        app.buttons["property.add"].tap()
        enter("破棄する入力", into: "property.name", app: app)
        app.buttons["editor.cancel"].tap()
        app.alerts.buttons["変更を破棄"].tap()
        XCTAssertTrue(app.buttons["property.add"].waitForExistence(timeout: 5))
        XCTAssertFalse(row("破棄する入力", app: app).exists)
    }

    func testRepairHistoryCompletionAndSearch() {
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        app.buttons["work.advance"].tap()
        XCTAssertTrue(app.buttons["完了にする"].waitForExistence(timeout: 5))
        tap("連絡履歴", app: app)
        app.buttons["連絡履歴を追加"].tap()
        enter("業者へ現地確認を依頼", into: "history.text", app: app)
        app.buttons["editor.save"].tap()
        XCTAssertTrue(row("業者へ現地確認を依頼", app: app).waitForExistence(timeout: 5))
        back(app)
        let advance = app.buttons["work.advance"]
        reveal(advance, app: app)
        advance.tap()
        back(app)
        app.buttons["work.completedFilter"].tap()
        XCTAssertTrue(row("給湯器から水漏れ", app: app).waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        reveal(search, app: app)
        search.tap()
        search.typeText("該当なし")
        XCTAssertTrue(app.staticTexts["対応が見つかりません"].waitForExistence(timeout: 5))
    }

    func testRenewalDraftAndExplicitContractConfirmation() {
        let app = launch(seeded: true)
        tap("契約更新の確認", app: app)
        tap("更新内容と期限を編集", app: app)
        replace("85000", in: "renewal.rent", app: app)
        app.buttons["editor.save"].tap()
        tap("更新契約を確定", app: app)
        app.buttons["契約内容を確定"].tap()
        let status = app.buttons["work.status"]
        reveal(status, app: app)
        XCTAssertEqual(status.value as? String, "完了")
    }

    func testCameraRecoveryOffersFiles() {
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        tap("写真・書類", app: app)
        app.buttons["documents.camera"].tap()
        let denial = app.alerts["カメラへのアクセスを許可してください"]
        let unavailable = app.alerts["カメラを使用できません"]
        XCTAssertTrue(denial.waitForExistence(timeout: 2) || unavailable.waitForExistence(timeout: 3))
        if denial.exists { XCTAssertTrue(app.alerts.buttons["設定を開く"].exists) }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = denial.exists ? "Camera denied" : "Camera unavailable"
        capture.lifetime = .keepAlways
        add(capture)
        app.alerts.buttons["ファイルを選択"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    func testDocumentAndPhotographOpenWithTheirNames() {
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        tap("写真・書類", app: app)
        tap("見積書.pdf", app: app)
        XCTAssertTrue(app.buttons["preview.close"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["見積書.pdf"].exists)
        app.buttons["preview.close"].tap()
        tap("給湯器の配管接続部.png", app: app)
        XCTAssertTrue(app.buttons["preview.close"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["給湯器の配管接続部.png"].exists)
        app.buttons["preview.close"].tap()
    }

    func testNativeFilePickerImportsPDF() {
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        tap("写真・書類", app: app)
        app.buttons["documents.import"].tap()
        if app.buttons["ブラウズ"].firstMatch.waitForExistence(timeout: 3) { app.buttons["ブラウズ"].firstMatch.tap() }
        let location = app.cells.containing(.staticText, identifier: "このiPhone内").firstMatch
        if location.waitForExistence(timeout: 3) { location.tap() }
        let folder = app.cells.containing(.staticText, identifier: "物件管理くん").firstMatch
        if folder.waitForExistence(timeout: 3) { folder.tap() }
        let file = app.cells.containing(.staticText, identifier: "修繕依頼書").firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 5), app.debugDescription)
        file.tap()
        XCTAssertTrue(row("修繕依頼書.pdf", app: app).waitForExistence(timeout: 8))
        tap("修繕依頼書.pdf", app: app)
        XCTAssertTrue(app.buttons["preview.close"].waitForExistence(timeout: 8))
    }

    func testNewCommonRepairCanReachCompletion() {
        let app = launch(seeded: true)
        app.buttons["work.add"].tap()
        enter("共用扉の調整", into: "work.title", app: app)
        app.buttons["editor.save"].tap()
        tap("共用扉の調整", app: app)
        app.buttons["work.advance"].tap()
        XCTAssertTrue(app.buttons["完了にする"].waitForExistence(timeout: 5))
        app.buttons["work.advance"].tap()
        XCTAssertEqual(app.buttons["work.status"].value as? String, "完了")
    }

    func testNotificationDenialKeepsTheSavedSchedule() throws {
        let app = saveScheduleWithDeniedNotifications()
        let schedule = app.buttons["work.schedule"]
        let settings = app.buttons["設定を開く"]
        reveal(settings, app: app)
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        // Notification guidance remains in the Repair list with the same native scroll edges.
        try audit(app, name: "Repair")
        reveal(schedule, app: app)
        schedule.tap()
        XCTAssertEqual(app.switches["予定を通知"].value as? String, "1")
        app.buttons["editor.cancel"].tap()
        reveal(settings, app: app)
        let preferences = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.tap()
        XCTAssertTrue(preferences.wait(for: .runningForeground, timeout: 5))
        app.activate()
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        reveal(schedule, app: app)
        schedule.tap()
        XCTAssertEqual(app.switches["予定を通知"].value as? String, "1")
        app.buttons["editor.cancel"].tap()
    }

    func testSavedScheduleAccessibilityAfterClosingTheNotice() throws {
        let app = saveScheduleWithDeniedNotifications()
        let close = app.buttons["閉じる"]
        reveal(close, app: app)
        close.tap()
        try audit(app, name: "Repair")
    }

    private func saveScheduleWithDeniedNotifications() -> XCUIApplication {
        let monitor = addUIInterruptionMonitor(withDescription: "Deny notification access") { alert in
            for title in ["許可しない", "Don’t Allow", "Don't Allow"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        defer { removeUIInterruptionMonitor(monitor) }
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        let schedule = app.buttons["work.schedule"]
        reveal(schedule, app: app)
        schedule.tap()
        XCTAssertTrue(app.navigationBars["次の予定を編集"].waitForExistence(timeout: 5))
        let toggle = app.switches["予定を通知"]
        reveal(toggle, app: app)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["editor.save"].tap()
        app.navigationBars["修繕の詳細"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let denyJapanese = system.buttons["許可しない"]
        let denyEnglish = system.buttons["Don’t Allow"]
        if denyJapanese.waitForExistence(timeout: 3) { denyJapanese.tap() }
        else if denyEnglish.waitForExistence(timeout: 2) { denyEnglish.tap() }
        let settings = app.buttons["設定を開く"]
        reveal(settings, app: app)
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        return app
    }

    func testLongPropertyNameAndKeyboardRemainReachable() throws {
        let app = launch()
        app.buttons["property.add"].tap()
        let name = "桜通りレジデンス東棟・第一管理区画と共用設備を含む長い物件名"
        enter(name, into: "property.name", app: app)
        enter("1203", into: "property.room", app: app)
        XCTAssertTrue(app.buttons["editor.save"].isHittable)
        let keyboard = XCTAttachment(screenshot: app.screenshot())
        keyboard.name = "Long name with keyboard"
        keyboard.lifetime = .keepAlways
        add(keyboard)
        app.buttons["editor.save"].tap()
        let building = row(name, app: app)
        reveal(building, app: app)
        XCTAssertTrue(building.waitForExistence(timeout: 5))
        try audit(app, name: "Long property name")
    }

    func testSystemSettingsAuditProbe() throws {
        for identifier in ["com.apple.Preferences", "com.apple.DocumentsApp"] {
            let stock = XCUIApplication(bundleIdentifier: identifier)
            stock.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
            stock.launch()
            XCTAssertTrue(stock.wait(for: .runningForeground, timeout: 8))
            if stock.buttons["閉じる"].exists { stock.buttons["閉じる"].tap() }
            if stock.buttons["ブラウズ"].firstMatch.exists { stock.buttons["ブラウズ"].firstMatch.tap() }
            for focused in [false, true] {
                let search = stock.searchFields.firstMatch
                if focused, search.exists { search.tap() }
                Thread.sleep(forTimeInterval: 0.7)
                let root = XCTAttachment(string: stock.debugDescription)
                root.name = "Stock tree \(identifier) focused=\(focused)"
                root.lifetime = .keepAlways
                add(root)
                try stock.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped]) { issue in
                    let detail = XCTAttachment(string: "\(identifier) focused=\(focused): \(issue.auditType.rawValue): \(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "no element")")
                    detail.name = "Stock audit detail"
                    detail.lifetime = .keepAlways
                    self.add(detail)
                    return true
                }
            }
        }
    }

    func testScreenTourAccessibility() throws {
        let app = launch(seeded: true)
        try audit(app, name: "Actions")
        tap("給湯器から水漏れ", app: app)
        try audit(app, name: "Repair")
        app.buttons["work.edit"].tap()
        try audit(app, name: "Repair Editor")
        app.buttons["editor.cancel"].tap()
        tap("連絡履歴", app: app)
        try audit(app, name: "History")
        app.buttons["連絡履歴を追加"].tap()
        try audit(app, name: "History Editor")
        app.buttons["editor.cancel"].tap()
        back(app)
        tap("業者", app: app)
        try audit(app, name: "Contractor")
        app.buttons["連絡先を編集"].tap()
        try audit(app, name: "Contact Editor")
        app.buttons["editor.cancel"].tap()
        back(app)
        tap("写真・書類", app: app)
        try audit(app, name: "Documents")
        back(app)
        let schedule = app.buttons["work.schedule"]
        reveal(schedule, app: app)
        schedule.tap()
        try audit(app, name: "Schedule Editor")
        app.buttons["editor.cancel"].tap()
        back(app)
        tap("契約更新の確認", app: app)
        tap("更新内容と期限を編集", app: app)
        try audit(app, name: "Renewal Editor")
        app.buttons["editor.cancel"].tap()
        app.tabBars.buttons["物件"].tap()
        try audit(app, name: "Properties")
        app.buttons["property.add"].tap()
        try audit(app, name: "Property Editor")
        app.buttons["editor.cancel"].tap()
        tap("桜通りレジデンス", app: app)
        try audit(app, name: "Building")
        tap("建物を編集", app: app)
        try audit(app, name: "Building Editor")
        app.buttons["editor.cancel"].tap()
        tap("203号室", app: app)
        try audit(app, name: "Room")
        app.buttons["部屋を編集"].tap()
        try audit(app, name: "Room Editor")
        app.buttons["editor.cancel"].tap()
        tap("賃貸借契約", app: app)
        try audit(app, name: "Contract")
        tap("契約を編集", app: app)
        try audit(app, name: "Contract Editor")
        app.buttons["editor.cancel"].tap()
        back(app)
        tap("設備", app: app)
        try audit(app, name: "Equipment")
        app.buttons["設備を追加"].tap()
        try audit(app, name: "Equipment Editor")
        app.buttons["editor.cancel"].tap()
    }

    func testReminderNoticeAccessibilityAfterLaunch() throws {
        let app = launch(seeded: true, reminderNotice: true)
        tap("給湯器から水漏れ", app: app)
        try audit(app, name: "Repair")
    }

    private func launch(seeded: Bool = false, failFirstSave: Bool = false, reminderNotice: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
            + (seeded ? ["--seeded"] : []) + (failFirstSave ? ["--fail-first-save"] : [])
        app.launchEnvironment["UITEST_STORAGE_ID"] = UUID().uuidString
        if reminderNotice { app.launchEnvironment["UITEST_NOTICE"] = "denied" }
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        return app
    }

    private func enter(_ value: String, into identifier: String, app: XCUIApplication) {
        let element = field(identifier, app: app)
        reveal(element, app: app)
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.tap()
        element.typeText(value)
    }

    private func replace(_ value: String, in identifier: String, app: XCUIApplication) {
        let element = field(identifier, app: app)
        reveal(element, app: app)
        element.tap()
        let count = (element.value as? String)?.count ?? 0
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count))
        element.typeText(value)
    }

    private func field(_ identifier: String, app: XCUIApplication) -> XCUIElement {
        let single = app.textFields[identifier]
        return single.exists ? single : app.textViews[identifier]
    }

    private func row(_ text: String, app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
    }

    private func tap(_ text: String, app: XCUIApplication) {
        let button = row(text, app: app)
        reveal(button, app: app)
        XCTAssertTrue(button.waitForExistence(timeout: 5), text)
        button.tap()
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        if element.exists && element.isHittable { return }
        for _ in 0..<7 {
            app.swipeUp()
            if element.exists && element.isHittable { return }
        }
        for _ in 0..<12 {
            app.swipeDown()
            if element.exists && element.isHittable { return }
        }
    }

    private func back(_ app: XCUIApplication) { app.navigationBars.buttons.firstMatch.tap() }

    private func audit(_ app: XCUIApplication, name: String) throws {
        Thread.sleep(forTimeInterval: 0.7)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
        var types: XCUIAccessibilityAuditType = [.elementDetection, .hitRegion, .sufficientElementDescription, .trait]
        if UIAccessibility.isDarkerSystemColorsEnabled { types.insert(.contrast) }
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            types.formUnion([.dynamicType, .textClipped])
        }
        var unlocatedContrastReports = 0
        try app.performAccessibilityAudit(for: types) { issue in
            print("Accessibility audit: \(name): \(issue.detailedDescription): \(issue.element?.debugDescription ?? "no element")")
            XCTContext.runActivity(named: "Audit \(name)") { activity in
                let detail = XCTAttachment(string: "\(name): \(issue.auditType.rawValue): \(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "no element")")
                detail.name = "App audit detail"
                detail.lifetime = .keepAlways
                activity.add(detail)
            }
            if let reason = self.systemDrawingExclusion(issue, app: app, screen: name) {
                if issue.element == nil {
                    unlocatedContrastReports += 1
                    guard unlocatedContrastReports <= 2 else { return false }
                }
                print("System drawing exclusion: \(reason)")
                return true
            }
            return false
        }
    }

    private func systemDrawingExclusion(_ issue: XCUIAccessibilityAuditIssue, app: XCUIApplication, screen: String) -> String? {
        guard UIDevice.current.systemVersion.hasPrefix("26.") else { return nil }
        // Files reproduces the 124-point native search field prediction at AX5 on iOS 26.
        if issue.auditType == .textClipped, let element = issue.element,
           element.elementType == .searchField, element.label == "検索" {
            return "Native iOS 26 search field; reproduced in Files and inspected at AX5."
        }
        guard issue.auditType == .contrast else { return nil }
        if let element = issue.element {
            let frame = element.frame
            let window = app.windows.firstMatch.frame
            let bars = app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex
            // Settings reproduces contrast sampling of text crossing native glass at AX5.
            if !window.contains(frame) || bars.contains(where: { $0.isHittable && $0.frame.intersects(frame) }) {
                return "Text crosses a native scroll edge; unobscured semantic secondary text measured 5.97:1."
            }
        } else if ["Actions", "Repair", "Contractor", "Documents", "Properties", "Building", "Room", "Long property name"].contains(screen) {
            // Exposing every authored merged row left the same iOS 26 scroll-edge reports without an element.
            return "Unlocated native scroll-edge sample; unchanged with authored accessibility merging removed."
        }
        return nil
    }
}
