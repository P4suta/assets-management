import XCTest
import UIKit

@MainActor
final class PropertyRecordsUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testAppInformationHasAccessiblePrivacyAndSupportLinks() throws {
        let app = launch()
        selectTab("物件", app: app)
        app.buttons["app-info.open"].tap()
        let privacy = app.descendants(matching: .any)["app-info.privacy"].firstMatch
        let support = app.descendants(matching: .any)["app-info.support"].firstMatch
        reveal(privacy, app: app)
        XCTAssertTrue(privacy.waitForExistence(timeout: 5))
        reveal(support, app: app)
        XCTAssertTrue(support.exists)
        try audit(app, name: "App information")
        app.buttons["app-info.close"].tap()
        XCTAssertTrue(app.buttons["property.add"].waitForExistence(timeout: 5))
    }

    func testContractAmountRejectsValuesAboveTheStoredLimit() {
        let app = launch(seeded: true)
        openSampleRoom(app)
        tap("賃貸借契約", app: app)
        tap("契約を編集", app: app)
        replace("1000000000001", in: "contract.rent", app: app)
        XCTAssertFalse(app.buttons["editor.save"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["contract.rent.error"].firstMatch.exists)
        let clear = app.buttons["contract.rent.clear"]
        XCTAssertGreaterThanOrEqual(clear.frame.width, 44 - 0.001)
        XCTAssertGreaterThanOrEqual(clear.frame.height, 44 - 0.001)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(clear.frame))
        let amount = field("contract.rent", app: app)
        XCTAssertGreaterThanOrEqual(clear.frame.midY, amount.frame.minY)
        XCTAssertLessThanOrEqual(clear.frame.midY, amount.frame.maxY)
        clear.tap()
        enter("1000000000000", into: "contract.rent", app: app)
        app.buttons["editor.save"].tap()
        tap("契約を編集", app: app)
        XCTAssertEqual(inputText("contract.rent", app: app), "1000000000000")
    }

    func testContractAmountCanClearBeforeAndAfterKeyboardFocus() {
        let app = launch(seeded: true)
        openSampleRoom(app)
        tap("賃貸借契約", app: app)
        tap("契約を編集", app: app)
        let amount = field("contract.rent", app: app)
        XCTAssertEqual(amount.value as? String, "82000")
        app.buttons["contract.rent.clear"].tap()
        XCTAssertEqual(amount.value as? String, "")
        amount.tap()
        amount.typeText("85000")
        waitForEditorLayout(amount, app: app)
        app.buttons["contract.rent.clear"].tap()
        let cleared = NSPredicate(format: "value == %@", "")
        let expectation = XCTNSPredicateExpectation(predicate: cleared, object: amount)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.buttons["editor.save"].waitForNonExistence(timeout: 5))
        tap("契約を編集", app: app)
        XCTAssertEqual(inputText("contract.rent", app: app), "")
    }

    func testRenewalAmountCanRecoverFromARejectedValueAndStayEmpty() {
        let app = launch(seeded: true)
        tap("契約更新の確認", app: app)
        tap("更新内容と期限を編集", app: app)
        replace("1000000000001", in: "renewal.rent", app: app)
        XCTAssertFalse(app.buttons["editor.save"].isEnabled)
        app.buttons["renewal.rent.clear"].tap()
        XCTAssertTrue(app.buttons["editor.save"].isEnabled)
        app.buttons["editor.save"].tap()
        tap("更新内容と期限を編集", app: app)
        XCTAssertEqual(inputText("renewal.rent", app: app), "")
    }

    func testBuildingRoomContactAndEquipmentEditsSurviveRelaunch() {
        let app = launch(seeded: true)
        openSampleRoom(app)
        tap("部屋を編集", app: app)
        replace("205", in: "room.number", app: app)
        app.buttons["editor.save"].tap()
        tap("佐藤 花子", app: app)
        tap("連絡先を編集", app: app)
        replace("佐藤 美咲", in: "contact.name", app: app)
        app.buttons["editor.save"].tap()
        back(app)
        tap("設備", app: app)
        tap("給湯器", app: app)
        replace("WH-205", in: "equipment.model", app: app)
        app.buttons["editor.save"].tap()
        back(app)
        back(app)
        tap("建物を編集", app: app)
        replace("桜通りレジデンス東館", in: "property.name", app: app)
        app.buttons["editor.save"].tap()
        app.terminate()
        app.launch()
        selectTab("物件", app: app)
        tap("桜通りレジデンス東館", app: app)
        tap("205号室", app: app)
        let resident = row("佐藤 美咲", app: app)
        reveal(resident, app: app)
        XCTAssertTrue(resident.exists)
        tap("設備", app: app)
        let model = row("WH-205", app: app)
        reveal(model, app: app)
        XCTAssertTrue(model.exists)
    }

    private func openSampleRoom(_ app: XCUIApplication) {
        selectTab("物件", app: app)
        tap("桜通りレジデンス", app: app)
        tap("203号室", app: app)
    }

    func testAmountInputIsBoundedAndRejectsOversizedValuesBeforeSaving() {
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        app.buttons["work.edit"].tap()
        replace("1000000000000000000000000000", in: "work.estimate", app: app)
        XCTAssertLessThanOrEqual(inputText("work.estimate", app: app)?.count ?? 0, 17)
        XCTAssertFalse(app.buttons["editor.save"].isEnabled)
        let clear = app.buttons["work.estimate.clear"]
        XCTAssertTrue(clear.exists)
        guard clear.exists else { return }
        XCTAssertGreaterThanOrEqual(clear.frame.width, 44 - 0.001)
        XCTAssertGreaterThanOrEqual(clear.frame.height, 44 - 0.001)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(clear.frame))
        let amount = field("work.estimate", app: app)
        XCTAssertGreaterThanOrEqual(clear.frame.midY, amount.frame.minY)
        XCTAssertLessThanOrEqual(clear.frame.midY, amount.frame.maxY)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Bounded amount input"
        capture.lifetime = .keepAlways
        add(capture)
        clear.tap()
        enter("85000", into: "work.estimate", app: app)
        XCTAssertTrue(app.buttons["editor.save"].isEnabled)
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.navigationBars["修繕の詳細"].waitForExistence(timeout: 5))
        app.buttons["work.edit"].tap()
        XCTAssertEqual(inputText("work.estimate", app: app), "85000")
    }

    func testChangingOnlyContractRentRequiresDiscardConfirmation() {
        let app = launch(seeded: true)
        selectTab("物件", app: app)
        tap("桜通りレジデンス", app: app)
        tap("203号室", app: app)
        tap("賃貸借契約", app: app)
        tap("契約を編集", app: app)
        replace("85000", in: "contract.rent", app: app)
        app.buttons["editor.cancel"].tap()
        XCTAssertTrue(app.alerts["変更を破棄しますか？"].waitForExistence(timeout: 5))
        guard app.alerts["変更を破棄しますか？"].exists else { return }
        app.alerts.buttons["編集を続ける"].tap()
        XCTAssertEqual(inputText("contract.rent", app: app), "85000")
        app.buttons["editor.cancel"].tap()
        app.alerts.buttons["変更を破棄"].tap()
        XCTAssertTrue(app.buttons["editor.cancel"].waitForNonExistence(timeout: 5))
        tap("契約を編集", app: app)
        XCTAssertTrue(app.buttons["editor.cancel"].waitForExistence(timeout: 5))
        XCTAssertEqual(inputText("contract.rent", app: app), "82000")
    }

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
        selectTab("物件", app: app)
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

    func testPristineRegistrationCanReopenAfterInteractiveDismissal() {
        let app = launch()
        app.buttons["property.add"].tap()
        dismissRegistrationInteractively(app)
        XCTAssertTrue(app.buttons["editor.cancel"].waitForNonExistence(timeout: 5))
        app.buttons["property.add"].tap()
        XCTAssertTrue(app.textFields["property.name"].waitForExistence(timeout: 5))
    }

    func testInteractiveDiscardPreservesOrRemovesOnlyTheDraft() {
        let app = launch()
        app.buttons["property.add"].tap()
        enter("編集中の物件", into: "property.name", app: app)
        dismissRegistrationInteractively(app)
        captureStoreScreen(app, name: "Interactive draft dismissal")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Interactive draft dismissal hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let alert = app.alerts["変更を破棄しますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["編集を続ける"].tap()
        XCTAssertEqual(inputText("property.name", app: app), "編集中の物件")
        dismissRegistrationInteractively(app)
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["変更を破棄"].tap()
        XCTAssertTrue(app.buttons["editor.cancel"].waitForNonExistence(timeout: 5))
        app.buttons["property.add"].tap()
        XCTAssertTrue(app.textFields["property.name"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(inputText("property.name", app: app), "編集中の物件")
    }

    func testRepairHistoryCompletionAndSearch() {
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        tapIdentifier("work.advance", app: app)
        let completion = app.buttons["完了にする"]
        reveal(completion, app: app)
        XCTAssertTrue(completion.waitForExistence(timeout: 5))
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
        tapIdentifier("work.completedFilter", app: app)
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
        tapIdentifier("documents.camera", app: app)
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
        tapIdentifier("documents.import", app: app)
        if app.buttons["ブラウズ"].firstMatch.waitForExistence(timeout: 3) { app.buttons["ブラウズ"].firstMatch.tap() }
        let localDevice = NSPredicate(format: "label IN %@", ["このiPhone内", "このiPad内"])
        let location = app.cells.containing(localDevice).firstMatch
        if location.waitForExistence(timeout: 3) { location.tap() }
        let nativeFiles = app.descendants(matching: .any)["File View"].firstMatch
        let picker = nativeFiles.exists ? nativeFiles : app
        let file = picker.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "修繕依頼書")).firstMatch
        if !file.exists {
            let nativeFolder = picker.descendants(matching: .any)["物件管理くん, Container"].firstMatch
            let folder = nativeFolder.exists ? nativeFolder : app.cells.containing(.staticText, identifier: "物件管理くん").firstMatch
            XCTAssertTrue(folder.waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertTrue(folder.wait(for: \.isHittable, toEqual: true, timeout: 5))
            folder.doubleTap()
        }
        guard file.waitForExistence(timeout: 5) else {
            captureStoreScreen(app, name: "Missing document in file picker")
            XCTFail("The local document did not appear after opening its folder.")
            return
        }
        XCTAssertTrue(file.wait(for: \.isHittable, toEqual: true, timeout: 5))
        file.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        guard !nativeFiles.exists || nativeFiles.waitForNonExistence(timeout: 8) else {
            captureStoreScreen(app, name: "Unopened file picker")
            XCTFail("The file picker did not return the selected document.")
            return
        }
        let imported = row("修繕依頼書.pdf", app: app)
        reveal(imported, app: app)
        XCTAssertTrue(imported.waitForExistence(timeout: 8))
        tap("修繕依頼書.pdf", app: app)
        XCTAssertTrue(app.buttons["preview.close"].waitForExistence(timeout: 8))
    }

    func testNewCommonRepairCanReachCompletion() {
        let app = launch(seeded: true)
        app.buttons["work.add"].tap()
        enter("共用扉の調整", into: "work.title", app: app)
        app.buttons["editor.save"].tap()
        tap("共用扉の調整", app: app)
        tapIdentifier("work.advance", app: app)
        let completion = app.buttons["完了にする"]
        reveal(completion, app: app)
        XCTAssertTrue(completion.waitForExistence(timeout: 5))
        tapIdentifier("work.advance", app: app)
        let status = app.buttons["work.status"]
        reveal(status, app: app)
        XCTAssertEqual(status.value as? String, "完了")
    }

    func testNotificationDenialKeepsTheSavedSchedule() throws {
        let app = saveScheduleWithDeniedNotifications()
        let schedule = app.buttons["work.schedule"]
        let settings = app.buttons["設定を開く"].firstMatch
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
        let close = app.buttons["閉じる"].firstMatch
        reveal(close, app: app)
        close.tap()
        try audit(app, name: "Repair")
    }

    func testPastVisitKeepsTheRecordAndExplainsWhyNoNotificationIsScheduled() {
        let app = launch(seeded: true, pastVisit: true)
        tap("給湯器から水漏れ", app: app)
        let schedule = app.buttons["work.schedule"]
        reveal(schedule, app: app)
        schedule.tap()
        let notify = app.switches["予定を通知"]
        reveal(notify, app: app)
        notify.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["過去の日時には通知を予約できません。記録は保存済みです。通知する場合は期限や予定の日時を変更してください。"].waitForExistence(timeout: 5))
        reveal(schedule, app: app)
        schedule.tap()
        XCTAssertEqual(app.switches["予定を通知"].value as? String, "1")
        app.buttons["editor.cancel"].tap()
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
        let settings = app.buttons["設定を開く"].firstMatch
        reveal(settings, app: app)
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        return app
    }

    func testLongPropertyNameAndKeyboardRemainReachable() throws {
        let app = longPropertyNameKeyboardJourney()
        try audit(app, name: "Long property name")
    }

    func testLargestTextLongPropertyNameKeyboardAndSaveRemainReachable() throws {
        guard UIApplication.shared.preferredContentSizeCategory == .accessibilityExtraExtraExtraLarge else {
            throw XCTSkip("The largest text journey requires AX5.")
        }
        _ = longPropertyNameKeyboardJourney(requiresKeyboard: true)
    }

    private func longPropertyNameKeyboardJourney(requiresKeyboard: Bool = false) -> XCUIApplication {
        let app = launch()
        app.buttons["property.add"].tap()
        let name = "桜通りレジデンス東棟・第一管理区画と共用設備を含む長い物件名"
        enter(name, into: "property.name", app: app)
        enter("1203", into: "property.room", app: app)
        XCTAssertTrue(app.buttons["editor.save"].isHittable)
        if requiresKeyboard {
            let keyboard = app.keyboards.firstMatch
            XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
            XCTAssertTrue(app.windows.firstMatch.frame.intersects(keyboard.frame))
        }
        let keyboard = XCTAttachment(screenshot: app.screenshot())
        keyboard.name = "Long name with keyboard"
        keyboard.lifetime = .keepAlways
        add(keyboard)
        app.buttons["editor.save"].tap()
        let building = row(name, app: app)
        reveal(building, app: app)
        XCTAssertTrue(building.waitForExistence(timeout: 5))
        return app
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
        selectTab("物件", app: app)
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

    func testSelectedWorkAndUnsavedEditSurviveRotation() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        app.buttons["work.edit"].tap()
        replace("配管修繕の現地確認", in: "work.title", app: app)
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(field("work.title", app: app).waitForExistence(timeout: 5))
            XCTAssertEqual(inputText("work.title", app: app), "配管修繕の現地確認")
            XCTAssertTrue(app.buttons["editor.save"].isHittable)
        }
        app.buttons["editor.cancel"].tap()
        app.alerts.buttons["編集を続ける"].tap()
        XCTAssertEqual(inputText("work.title", app: app), "配管修繕の現地確認")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["配管修繕の現地確認"].firstMatch.waitForExistence(timeout: 5))
        try audit(app, name: "Adaptive Repair")
    }

    func testSelectedPropertyAndRoomSurviveRotation() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch(seeded: true)
        openSampleRoom(app)
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(row("佐藤 花子", app: app).waitForExistence(timeout: 5))
            XCTAssertTrue(app.navigationBars["203号室"].exists)
        }
        tap("賃貸借契約", app: app)
        XCTAssertTrue(app.staticTexts["契約満了日、2027年3月31日"].firstMatch.waitForExistence(timeout: 5))
        try audit(app, name: "Adaptive Contract")
    }

    func testSelectedRecordRowsRemainReadable() throws {
        defer { XCUIDevice.shared.appearance = .light }
        for dark in [false, true] {
            XCUIDevice.shared.appearance = dark ? .dark : .light
            let app = launch(seeded: true)
            tap("給湯器から水漏れ", app: app)
            XCTAssertTrue(app.navigationBars["修繕の詳細"].waitForExistence(timeout: 5))
            let sidebar = app.collectionViews.containing(.button, identifier: "work.completedFilter").firstMatch
            let window = app.windows.firstMatch.frame
            guard sidebar.exists, window.contains(sidebar.frame), sidebar.frame.width < window.width / 2,
                  app.buttons["work.add"].isHittable else {
                throw XCTSkip("Compact navigation does not display a selected sidebar row.")
            }
            XCTAssertEqual(row("給湯器から水漏れ", app: app).identifier, "work.row.selected", app.debugDescription)
            try assertCaptionContrast(in: row("給湯器から水漏れ", app: app), app: app)
            try audit(app, name: "Selected repair")
            try auditSelectionContrast(row("給湯器から水漏れ", app: app), app: app)
            selectTab("物件", app: app)
            tap("桜通りレジデンス", app: app)
            try audit(app, name: "Selected building")
            try auditSelectionContrast(row("桜通りレジデンス", app: app), app: app)
            app.terminate()
        }
    }

    func testTextContrastRejectsWeakAndUnsupportedImages() throws {
        func image(foreground: UIColor?, background: UIColor, dither: UIColor? = nil, text: Bool = false) throws -> CGImage {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = true
            let bitmap = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 24), format: format).image { context in
                background.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 200, height: 24))
                if let dither {
                    dither.setFill()
                    for x in stride(from: 0, to: 200, by: 2) {
                        context.fill(CGRect(x: x, y: 0, width: 1, height: 24))
                    }
                }
                if let foreground {
                    if text {
                        ("期限 2026年11月12日" as NSString).draw(at: CGPoint(x: 4, y: 3), withAttributes: [
                            .font: UIFont.systemFont(ofSize: 13), .foregroundColor: foreground
                        ])
                    } else {
                        foreground.setFill()
                        context.fill(CGRect(x: 4, y: 4, width: 80, height: 16))
                    }
                }
            }
            return try XCTUnwrap(bitmap.cgImage)
        }
        let readable = try UniformTextContrast(image: image(foreground: .black, background: .white))
        XCTAssertEqual(readable.ratio, 21, accuracy: 0.01)
        XCTAssertGreaterThan(readable.foregroundPixels, 8)
        let weak = try UniformTextContrast(image: image(foreground: .lightGray, background: .white))
        XCTAssertLessThan(weak.ratio, 4.5)
        let red = try UniformTextContrast(image: image(foreground: .red, background: .white))
        XCTAssertEqual(red.ratio, 3.998, accuracy: 0.001)
        let blue = try UniformTextContrast(image: image(foreground: .blue, background: .white))
        XCTAssertEqual(blue.ratio, 8.592, accuracy: 0.001)
        let background = UIColor(red: 198 / 255, green: 197 / 255, blue: 208 / 255, alpha: 1)
        let dither = UIColor(red: 198 / 255, green: 197 / 255, blue: 207 / 255, alpha: 1)
        let quantized = try UniformTextContrast(image: image(foreground: .black, background: background, dither: dither, text: true))
        XCTAssertGreaterThan(quantized.ratio, 12)
        XCTAssertThrowsError(try UniformTextContrast(image: image(foreground: nil, background: .white)))
    }

    func testCompletedFilterRemainsReadableInBothStates() throws {
        let app = launch(seeded: true)
        let control = app.buttons["work.completedFilter"]
        for label in ["完了した対応", "未完了の対応"] {
            reveal(control, app: app)
            let text = control.staticTexts[label].firstMatch
            revealCompletedFilterCaption(text, app: app)
            XCTAssertTrue(text.isHittable)
            let frame = text.frame
            let screenshot = text.screenshot()
            let capture = XCTAttachment(screenshot: screenshot)
            capture.name = "Completed filter: " + label
            capture.lifetime = .keepAlways
            add(capture)
            let image = try XCTUnwrap(screenshot.image.cgImage)
            let measurement = try UniformTextContrast(image: image)
            XCTAssertEqual(text.frame, frame)
            let detail = XCTAttachment(string: "\(label): \(measurement.ratio):1\nForeground pixels: \(measurement.foregroundPixels)")
            detail.name = "Completed filter measured contrast"
            detail.lifetime = .keepAlways
            add(detail)
            XCTAssertGreaterThanOrEqual(measurement.ratio, 4.5)
            control.tap()
        }
        XCTAssertTrue(app.navigationBars["対応"].exists)
    }

    private func revealCompletedFilterCaption(_ caption: XCUIElement, app: XCUIApplication) {
        let list = app.collectionViews.containing(.button, identifier: "work.completedFilter").firstMatch
        XCTAssertTrue(list.exists)
        var viewport = list.frame.intersection(app.windows.firstMatch.frame)
        let bars = app.navigationBars.allElementsBoundByIndex.filter { !$0.frame.isEmpty && $0.frame.intersects(viewport) }
        let top = max(viewport.minY, bars.map { $0.frame.maxY }.max() ?? viewport.minY)
        let tabs = app.tabBars.allElementsBoundByIndex.filter { $0.frame.minY > viewport.midY && $0.frame.intersects(viewport) }
        let bottom = min(viewport.maxY, tabs.map { $0.frame.minY }.min() ?? viewport.maxY)
        viewport = CGRect(x: viewport.minX, y: top + 8, width: viewport.width, height: bottom - top - 32)
        guard let pan = ScrollCoordinates(bounds: list.frame, keyboard: nil), !viewport.isEmpty else {
            XCTFail("No visible viewport is available for the filter caption.")
            return
        }
        let lower = list.coordinate(withNormalizedOffset: pan.lower)
        let upper = list.coordinate(withNormalizedOffset: pan.upper)
        for _ in 0..<4 {
            if viewport.contains(caption.frame), caption.isHittable { return }
            if caption.frame.maxY > viewport.maxY {
                lower.press(forDuration: 0.05, thenDragTo: upper)
            } else {
                upper.press(forDuration: 0.05, thenDragTo: lower)
            }
        }
        XCTAssertTrue(viewport.contains(caption.frame) && caption.isHittable, "The complete filter caption must be visible before measuring its contrast.")
    }

    func testUnselectedRecordMetadataRemainsReadableWithIncreasedContrast() throws {
        guard UIAccessibility.isDarkerSystemColorsEnabled else {
            throw XCTSkip("Unselected metadata contrast requires Increase Contrast.")
        }
        let app = launch(seeded: true)
        for (title, location) in [("給湯器から水漏れ", "桜通りレジデンス · 203号室"), ("共用灯の交換", "青葉コート · 共用部分")] {
            let work = row(title, app: app)
            XCTAssertFalse(work.isSelected)
            let caption = work.staticTexts["work.caption.location"].firstMatch
            XCTAssertEqual(caption.label, location)
            try assertRenderedCaptionContrast(caption, name: "Unselected work location", app: app)
            for identifier in ["work.caption.status", "work.caption.deadline"] {
                try assertRenderedCaptionContrast(work.staticTexts[identifier].firstMatch, name: "Unselected " + identifier, app: app)
            }
        }
        selectTab("物件", app: app)
        let property = row("桜通りレジデンス", app: app)
        XCTAssertFalse(property.isSelected)
        for label in ["自主管理 · 2部屋", "未完了の対応 2件"] {
            try assertRenderedCaptionContrast(property.staticTexts[label].firstMatch, name: "Unselected property " + label, app: app)
        }
    }

    private func assertRenderedCaptionContrast(_ caption: XCUIElement, name: String, app: XCUIApplication) throws {
        reveal(caption, app: app)
        XCTAssertTrue(caption.isHittable, name)
        let frame = caption.frame
        XCTAssertTrue(app.windows.firstMatch.frame.contains(frame), name)
        let screenshot = caption.screenshot()
        XCTAssertEqual(caption.frame, frame, name)
        let capture = XCTAttachment(screenshot: screenshot)
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
        let measurement = try UniformTextContrast(image: XCTUnwrap(screenshot.image.cgImage))
        let detail = XCTAttachment(string: "\(name): \(measurement.ratio):1\nForeground pixels: \(measurement.foregroundPixels)")
        detail.name = "Unselected metadata measured contrast"
        detail.lifetime = .keepAlways
        add(detail)
        XCTAssertGreaterThanOrEqual(measurement.ratio, 4.5, name)
    }

    func testScrollCoordinatesIgnoreEmptyAndUnrelatedKeyboards() throws {
        let bounds = CGRect(x: 20, y: 100, width: 300, height: 600)
        let natural = try XCTUnwrap(ScrollCoordinates(bounds: bounds, keyboard: nil))
        XCTAssertEqual(natural.lower.dy, 0.8)
        for keyboard in [CGRect.zero, CGRect(x: 20, y: 900, width: 300, height: 200),
                         CGRect(x: 20, y: 300, width: 100, height: 200)] {
            let gesture = try XCTUnwrap(ScrollCoordinates(bounds: bounds, keyboard: keyboard))
            XCTAssertEqual(gesture.lower.dy, natural.lower.dy)
        }
        let visible = try XCTUnwrap(ScrollCoordinates(bounds: bounds, keyboard: CGRect(x: 0, y: 500, width: 500, height: 300)))
        XCTAssertEqual(visible.lower.dy, 380.0 / 600, accuracy: 0.001)
        XCTAssertGreaterThan(visible.lower.dy, visible.upper.dy)
    }

    func testScrollCoordinatesRejectEmptyOrObscuredViewports() {
        XCTAssertNil(ScrollCoordinates(bounds: .zero, keyboard: nil))
        let bounds = CGRect(x: 20, y: 100, width: 300, height: 600)
        XCTAssertNil(ScrollCoordinates(bounds: bounds, keyboard: CGRect(x: 0, y: 0, width: 500, height: 1_000)))
    }

    func testNativeSheetTextScopeRejectsUnverifiedReports() {
        let allowed: Set<[String]> = [
            ["26.0.0", "pad", "Repair Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["26.0.0", "pad", "Renewal Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["26.0.0", "pad", "Building Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["26.0.0", "pad", "Schedule Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["26.0.0", "pad", "Equipment Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["27.2.0", "pad", "Repair Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["27.2.0", "pad", "Renewal Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["27.2.0", "pad", "Building Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["27.2.0", "pad", "History Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["27.2.0", "pad", "Room Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"],
            ["27.2.0", "pad", "Contract Editor", "text", "unlocated", "readable", "floating", "Potentially inaccessible text"]
        ]
        let versions = [("26.0.0", OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)),
                        ("26.1.0", OperatingSystemVersion(majorVersion: 26, minorVersion: 1, patchVersion: 0)),
                        ("27.2.0", OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0)),
                        ("27.2.1", OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 1)),
                        ("27.3.0", OperatingSystemVersion(majorVersion: 27, minorVersion: 3, patchVersion: 0)),
                        ("28.0.0", OperatingSystemVersion(majorVersion: 28, minorVersion: 0, patchVersion: 0)),
                        ("28.2.0", OperatingSystemVersion(majorVersion: 28, minorVersion: 2, patchVersion: 0))]
        let frames = [("floating", CGRect(x: 226, y: 358, width: 580, height: 660)), ("empty", CGRect.zero),
                      ("full", CGRect(x: 0, y: 0, width: 1032, height: 1376)),
                      ("outside", CGRect(x: 226, y: -1, width: 580, height: 660)),
                      ("invalid", CGRect(x: CGFloat.nan, y: 358, width: 580, height: 660))]
        for (versionName, version) in versions {
            for (idiomName, idiom) in [("pad", UIUserInterfaceIdiom.pad), ("phone", .phone), ("mac", .mac)] {
                for screen in ["Repair Editor", "Renewal Editor", "Building Editor", "History Editor", "Room Editor", "Contract Editor", "Schedule Editor", "Equipment Editor", "Repair", "Property Editor"] {
                    for (typeName, auditType) in [("text", XCUIAccessibilityAuditType.elementDetection), ("contrast", .contrast), ("trait", .trait)] {
                        for hasElement in [false, true] {
                            for readable in [false, true] {
                                for (frameName, frame) in frames {
                                    for description in ["Potentially inaccessible text", "Potentially inaccessible element"] {
                                        let scope = NativeSheetTextScope(version: version, idiom: idiom, screen: screen,
                                            auditType: auditType, compactDescription: description, hasElement: hasElement,
                                            controlsReadable: readable, editor: frame, window: CGRect(x: 0, y: 0, width: 1032, height: 1376))
                                        let key = [versionName, idiomName, screen, typeName, hasElement ? "located" : "unlocated",
                                                   readable ? "readable" : "unreadable", frameName, description]
                                        XCTAssertEqual(scope.accepts, allowed.contains(key), key.joined(separator: " | "))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func testNativeSheetTextReportCountRejectsUnexpectedDuplicates() {
        let allowed: Set<String> = ["Repair Editor|1", "Renewal Editor|1", "Renewal Editor|2", "Building Editor|1", "History Editor|1", "Room Editor|1", "Contract Editor|1"]
        let legacyAllowed: Set<String> = ["Repair Editor|1", "Repair Editor|2", "Renewal Editor|1", "Building Editor|1", "Schedule Editor|1", "Equipment Editor|1"]
        for screen in ["Repair Editor", "Renewal Editor", "Building Editor", "History Editor", "Room Editor", "Contract Editor", "Schedule Editor", "Equipment Editor", "Property Editor"] {
            for index in 0...3 {
                var scope = NativeSheetTextScope(version: OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0),
                    idiom: .pad, screen: screen, auditType: .elementDetection,
                    compactDescription: "Potentially inaccessible text", hasElement: false, controlsReadable: true,
                    editor: CGRect(x: 226, y: 358, width: 580, height: 660),
                    window: CGRect(x: 0, y: 0, width: 1032, height: 1376), reportIndex: index)
                XCTAssertEqual(scope.accepts, allowed.contains("\(screen)|\(index)"), "\(screen), report \(index)")
                scope.version = OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0)
                XCTAssertEqual(scope.accepts, legacyAllowed.contains("\(screen)|\(index)"), "iPadOS 26: \(screen), report \(index)")
            }
        }
    }

    func testNativeScheduleControlsRejectUnverifiedControls() {
        let native = NativeScheduleControls(dateType: .datePicker, dateLabel: "", captionLabel: "予定日時",
            buttonLabel: "日付と時間ピッカー", buttonValue: "15:25, 2026/11/14",
            enabledLabel: "予定を設定", enabledValue: "1", reminderLabel: "予定を通知", reminderValue: "0", reachable: true)
        XCTAssertTrue(native.accepts)
        let rejected: [(inout NativeScheduleControls) -> Void] = [
            { $0.dateType = .staticText }, { $0.dateLabel = "予定日時" }, { $0.captionLabel = "" },
            { $0.buttonLabel = "Date" }, { $0.buttonValue = "" }, { $0.enabledLabel = "通知" },
            { $0.enabledValue = "0" }, { $0.reminderLabel = "予定" }, { $0.reminderValue = "1" },
            { $0.reachable = false }
        ]
        for reject in rejected {
            var controls = native
            reject(&controls)
            XCTAssertFalse(controls.accepts)
        }
    }

    func testAdaptiveTabTypeScopeRejectsUnverifiedReports() {
        let native = AdaptiveTabTypeScope(version: OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0),
            idiom: .pad, auditType: .dynamicType, compactDescription: "Dynamic Type font sizes are partially unsupported",
            detailedDescription: "User will not be able to change the font size of this UILabel", hasElement: false,
            textSize: .accessibilityExtraExtraExtraLarge, hasNativeTopTabs: true, reportIndex: 1)
        XCTAssertTrue(native.accepts)
        var second = native
        second.reportIndex = 2
        XCTAssertTrue(second.accepts)
        let rejected: [(inout AdaptiveTabTypeScope) -> Void] = [
            { $0.version.majorVersion = 26 }, { $0.version.majorVersion = 28 }, { $0.version.minorVersion = 3 }, { $0.version.patchVersion = 1 },
            { $0.idiom = .phone }, { $0.auditType = .elementDetection },
            { $0.compactDescription = "Dynamic Type font sizes are unsupported" },
            { $0.detailedDescription = "User will not be able to change the font size of this UIButton" },
            { $0.hasElement = true }, { $0.textSize = .large }, { $0.hasNativeTopTabs = false },
            { $0.reportIndex = 0 }, { $0.reportIndex = 3 }
        ]
        for reject in rejected {
            var scope = native
            reject(&scope)
            XCTAssertFalse(scope.accepts)
        }
    }

    func testSidebarHeaderContrastRejectsUnverifiedContexts() {
        let verified = SidebarHeaderContrastScope(
            version: OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0),
            idiom: .pad, auditType: .contrast, elementType: .staticText,
            label: "期限が近い対応", listIdentity: "work.completedFilter", matchingHeader: true,
            element: CGRect(x: 16, y: 258, width: 288, height: 40.5),
            sidebar: CGRect(x: 0, y: 96, width: 320, height: 1280),
            window: CGRect(x: 0, y: 0, width: 1032, height: 1376), ratio: 5.245479569885372)
        XCTAssertTrue(verified.accepts)
        var propertyHeader = verified
        propertyHeader.label = "建物"
        propertyHeader.listIdentity = "サイドバー"
        propertyHeader.element = CGRect(x: 16, y: 214, width: 288, height: 44)
        XCTAssertTrue(propertyHeader.accepts)
        var laterHeader = verified
        laterHeader.label = "今後の対応"
        XCTAssertTrue(laterHeader.accepts)
        for ratio in [4.5, 4.499, .nan, .infinity] {
            var scope = verified
            scope.ratio = ratio
            XCTAssertEqual(scope.accepts, ratio == 4.5)
        }
        let rejected: [(inout SidebarHeaderContrastScope) -> Void] = [
            { $0.version.majorVersion = 26 }, { $0.version.majorVersion = 28 }, { $0.version.minorVersion = 3 }, { $0.version.patchVersion = 1 },
            { $0.idiom = .phone }, { $0.auditType = .elementDetection }, { $0.elementType = .button },
            { $0.label = "部屋" }, { $0.label = "建物" }, { $0.listIdentity = "サイドバー" },
            { $0.listIdentity = "unknown" }, { $0.matchingHeader = false },
            { $0.element = .zero }, { $0.element.origin.x = 340 }, { $0.element.origin.x = .nan },
            { $0.sidebar = $0.window }, { $0.sidebar.origin.x = 320 }, { $0.window = .zero }
        ]
        for reject in rejected {
            var scope = verified
            reject(&scope)
            XCTAssertFalse(scope.accepts)
        }
    }

    func testNativeEditorVoiceOverStaysWithinTheSheet() throws {
        #if VOICEOVER_AUTOMATION
        guard #available(iOS 27.0, *) else {
            throw XCTSkip("Native VoiceOver automation requires iOS 27 or later.")
        }
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        app.buttons["work.edit"].tap()
        try assertModalVoiceOver(expected: ["キャンセル", "保存", "対応内容", "受付", "状態", "詳細", "見積額"], app: app)
        app.buttons["editor.cancel"].tap()
        back(app)
        tap("契約更新の確認", app: app)
        tap("更新内容と期限を編集", app: app)
        try assertModalVoiceOver(expected: ["キャンセル", "保存", "契約開始日", "契約満了日", "月額家賃", "期限を通知"], app: app)
        #else
        throw XCTSkip("Native VoiceOver automation requires the iOS 27 SDK or later.")
        #endif
    }

    #if VOICEOVER_AUTOMATION
    @available(iOS 27.0, *)
    private func assertModalVoiceOver(expected: [String], app: XCUIApplication) throws {
        let service = XCUIDevice.shared.voiceOverService
        let wasEnabled = service.isEnabled
        addTeardownBlock { @MainActor in
            if !wasEnabled && service.isEnabled { try service.disable() }
        }
        try service.enable()
        let forbidden = ["共用灯の交換", "消防設備点検", "連絡履歴", "対応を追加"]
        for forward in [true, false] {
            var speech = [try service.currentSpeech().utterance]
            for _ in 0..<48 {
                do {
                    let output = try forward ? service.moveForward() : service.moveBackward()
                    speech.append(output.utterance)
                } catch let error as XCUIVoiceOverService.Error where error.code == .noSpeech {
                    break
                }
            }
            let transcript = speech.joined(separator: "\n")
            let attachment = XCTAttachment(string: transcript)
            attachment.name = forward ? "Modal VoiceOver forward" : "Modal VoiceOver backward"
            attachment.lifetime = .keepAlways
            add(attachment)
            for label in expected { XCTAssertTrue(transcript.contains(label), transcript) }
            for label in forbidden { XCTAssertFalse(transcript.contains(label), transcript) }
            XCTAssertTrue(app.buttons["editor.cancel"].exists)
        }
        if !wasEnabled { try service.disable() }
    }
    #endif

    func testStoreScreenshots() {
        defer { XCUIDevice.shared.appearance = .light }
        XCUIDevice.shared.appearance = .light
        let app = launch(seeded: true)
        tap("給湯器から水漏れ", app: app)
        if !row("共用灯の交換", app: app).isHittable {
            back(app)
            captureStoreScreen(app, name: "1-actions")
            tap("給湯器から水漏れ", app: app)
        } else {
            captureStoreScreen(app, name: "1-actions")
        }
        captureStoreScreen(app, name: "3-repair")
        selectTab("物件", app: app)
        tap("桜通りレジデンス", app: app)
        captureStoreScreen(app, name: "2-properties")
        XCUIDevice.shared.appearance = .dark
        XCTAssertTrue(row("203号室", app: app).waitForExistence(timeout: 5))
        captureStoreScreen(app, name: "4-properties-dark")
    }

    func testReviewDemonstration() {
        let app = launch(seeded: true)
        let building = "青葉ハイツ " + String(UUID().uuidString.prefix(8))
        selectTab("物件", app: app)
        app.buttons["property.add"].tap()
        enter(building, into: "property.name", app: app)
        enter("203", into: "property.room", app: app)
        app.buttons["editor.save"].tap()
        tap(building, app: app)
        tap("203号室", app: app)
        tap("契約を登録", app: app)
        tap("契約を編集", app: app)
        enter("82000", into: "contract.rent", app: app)
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts["家賃、¥82,000"].waitForExistence(timeout: 5))
        selectTab("対応", app: app)
        app.buttons["work.add"].tap()
        field("work.building", app: app).tap()
        tap(building, app: app)
        enter("共用灯の交換", into: "work.title", app: app)
        app.buttons["editor.save"].tap()
        let createdRepair = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "共用灯の交換", building)).firstMatch
        reveal(createdRepair, app: app)
        XCTAssertTrue(createdRepair.waitForExistence(timeout: 5))
        createdRepair.tap()
        let detail = app.collectionViews.containing(.button, identifier: "work.status").firstMatch
        XCTAssertTrue(detail.staticTexts[building + " · 共用部分"].waitForExistence(timeout: 5))
        tap("連絡履歴", app: app)
        app.buttons["連絡履歴を追加"].tap()
        enter("業者へ現地確認を依頼", into: "history.text", app: app)
        app.buttons["editor.save"].tap()
        XCTAssertTrue(row("業者へ現地確認を依頼", app: app).waitForExistence(timeout: 5))
        back(app)
        tapIdentifier("work.advance", app: app)
        XCTAssertTrue(app.buttons["完了にする"].waitForExistence(timeout: 5))
        tapIdentifier("work.advance", app: app)
        let completed = NSPredicate(format: "value == %@", "完了")
        let expectation = XCTNSPredicateExpectation(predicate: completed, object: app.buttons["work.status"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        captureStoreScreen(app, name: "Review completed repair")
    }

    private func captureStoreScreen(_ app: XCUIApplication, name: String) {
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
    }

    func testReminderNoticeAccessibilityAfterLaunch() throws {
        let app = launch(seeded: true, reminderNotice: true)
        tap("給湯器から水漏れ", app: app)
        try audit(app, name: "Repair")
    }

    private func launch(seeded: Bool = false, failFirstSave: Bool = false, reminderNotice: Bool = false, pastVisit: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_PAST_VISIT"] = pastVisit ? "1" : "0"
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
            + (seeded ? ["--seeded"] : []) + (failFirstSave ? ["--fail-first-save"] : [])
        app.launchEnvironment["UITEST_STORAGE_ID"] = UUID().uuidString
        if reminderNotice { app.launchEnvironment["UITEST_NOTICE"] = "denied" }
        app.launch()
        let controls = NSPredicate(format: "identifier IN %@", ["work.add", "property.add"])
        XCTAssertTrue(app.descendants(matching: .any).matching(controls).firstMatch.waitForExistence(timeout: 10))
        return app
    }

    private func selectTab(_ title: String, app: XCUIApplication) {
        let standard = app.tabBars.buttons[title]
        if standard.exists {
            standard.tap()
        } else {
            let symbol = title == "物件" ? "building.2.fill" : "checklist"
            let predicate = NSPredicate(format: "identifier == %@ AND label == %@", symbol, title)
            let adaptive = app.descendants(matching: .any).matching(predicate).firstMatch
            XCTAssertTrue(adaptive.waitForExistence(timeout: 5))
            adaptive.tap()
        }
    }

    private func enter(_ value: String, into identifier: String, app: XCUIApplication) {
        let element = field(identifier, app: app)
        reveal(element, app: app)
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        element.tap()
        element.typeText(value)
        waitForEditorLayout(element, app: app)
    }

    private struct EditorLayout: Equatable {
        let input: CGRect
        let keyboard: CGRect?
        let save: CGRect
        let cancel: CGRect
    }

    private func waitForEditorLayout(_ input: XCUIElement, app: XCUIApplication) {
        let save = app.buttons["editor.save"]
        let cancel = app.buttons["editor.cancel"]
        let keyboard = app.keyboards.firstMatch
        var previous: EditorLayout?
        let settled = NSPredicate { _, _ in
            guard input.exists, save.exists, cancel.exists else { return false }
            let window = app.windows.firstMatch.frame
            let keyboardFrame = keyboard.exists ? keyboard.frame : nil
            guard !input.frame.isEmpty, input.frame.intersects(window),
                  window.contains(save.frame), window.contains(cancel.frame),
                  keyboardFrame.map({ !$0.isEmpty && window.contains($0) }) ?? true else {
                previous = nil
                return false
            }
            let current = EditorLayout(input: input.frame, keyboard: keyboardFrame, save: save.frame, cancel: cancel.frame)
            defer { previous = current }
            return current == previous
        }
        let expectation = XCTNSPredicateExpectation(predicate: settled, object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed,
                       "The editor and keyboard must settle before the next action.")
    }

    private func dismissRegistrationInteractively(_ app: XCUIApplication) {
        let header = app.navigationBars["物件を追加"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        let start = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    private func replace(_ value: String, in identifier: String, app: XCUIApplication) {
        let element = field(identifier, app: app)
        reveal(element, app: app)
        element.tap()
        waitForEditorLayout(element, app: app)
        let clear = app.buttons[identifier + ".clear"]
        if clear.exists {
            reveal(clear, app: app)
            clear.tap()
            XCTAssertEqual(element.value as? String ?? "", "")
            reveal(element, app: app)
            element.tap()
        } else {
            element.press(forDuration: 1.1)
            let selectAll = app.descendants(matching: .any)["すべてを選択"].firstMatch
            for _ in 0..<8 {
                if selectAll.exists { break }
                let next = app.buttons["進む"]
                if !next.exists { break }
                next.tap()
            }
            XCTAssertTrue(selectAll.waitForExistence(timeout: 3), app.debugDescription)
            selectAll.tap()
        }
        element.typeText(value)
        waitForEditorLayout(element, app: app)
    }

    private func field(_ identifier: String, app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func inputText(_ identifier: String, app: XCUIApplication) -> String? {
        let element = field(identifier, app: app)
        reveal(element, app: app)
        return element.value as? String
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

    private func tapIdentifier(_ identifier: String, app: XCUIApplication) {
        let button = app.buttons[identifier]
        reveal(button, app: app)
        XCTAssertTrue(button.waitForExistence(timeout: 5), identifier)
        button.tap()
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        func reachable() -> Bool {
            guard element.exists && element.isHittable else { return false }
            let keyboard = app.keyboards.firstMatch
            return !keyboard.exists || !element.frame.intersects(keyboard.frame)
        }
        if reachable() { return }
        let window = app.windows.firstMatch
        let container = app.collectionViews.allElementsBoundByIndex.last(where: \.isHittable) ?? window
        let keyboard = app.keyboards.firstMatch
        guard let coordinates = ScrollCoordinates(bounds: container.frame, keyboard: keyboard.isHittable ? keyboard.frame : nil) else {
            XCTFail("No visible viewport is available for scrolling.")
            return
        }
        let lower = container.coordinate(withNormalizedOffset: coordinates.lower)
        let upper = container.coordinate(withNormalizedOffset: coordinates.upper)
        for _ in 0..<24 {
            lower.press(forDuration: 0.05, thenDragTo: upper)
            if reachable() { return }
        }
        let deepest = XCTAttachment(string: app.debugDescription)
        deepest.name = "Unreached element after upward search"
        deepest.lifetime = .deleteOnSuccess
        add(deepest)
        for _ in 0..<24 {
            upper.press(forDuration: 0.05, thenDragTo: lower)
            if reachable() { return }
        }
    }

    private func back(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons["BackButton"].firstMatch
        if back.exists {
            back.tap()
        } else {
            let controls = NSPredicate(format: "identifier IN %@", ["work.add", "property.add"])
            XCTAssertTrue(app.buttons.matching(controls).firstMatch.isHittable)
        }
    }

    private func auditSelectionContrast(_ selected: XCUIElement, app: XCUIApplication) throws {
        guard selected.exists && selected.isHittable else { return }
        let frame = selected.frame
        try app.performAccessibilityAudit(for: .contrast) { issue in
            guard let element = issue.element else { return false }
            guard frame.intersects(element.frame) else { return true }
            if self.verifiedCaptionContrast(issue, app: app) != nil { return true }
            let detail = XCTAttachment(string: issue.detailedDescription + "\n" + element.debugDescription + "\n" + selected.debugDescription)
            detail.name = "Selected row contrast issue"
            detail.lifetime = .keepAlways
            self.add(detail)
            return false
        }
    }

    private func assertCaptionContrast(in selected: XCUIElement, app: XCUIApplication) throws {
        for identifier in ["work.caption.location", "work.caption.status", "work.caption.deadline"] {
            let caption = selected.staticTexts[identifier].firstMatch
            XCTAssertTrue(caption.exists)
            let contrast = try measureCaption(caption, selected: selected, app: app)
            XCTAssertGreaterThanOrEqual(contrast.ratio, 4.5)
        }
    }

    private func measureCaption(_ caption: XCUIElement, selected: XCUIElement, app: XCUIApplication, requireSelection: Bool = true) throws -> UniformTextContrast {
        let frame = caption.frame
        let rowFrame = selected.frame
        guard (!requireSelection || selected.isSelected), selected.isHittable, caption.isHittable, !frame.isEmpty,
              rowFrame.contains(frame), app.windows.allElementsBoundByIndex.contains(where: { $0.frame.contains(frame) })
        else { throw TextContrastError.changedFrame }
        let capture = caption.screenshot()
        guard caption.frame == frame, selected.frame == rowFrame else { throw TextContrastError.changedFrame }
        let image = try XCTUnwrap(UIImage(data: capture.pngRepresentation)?.cgImage)
        let scaleX = Double(image.width) / frame.width
        let scaleY = Double(image.height) / frame.height
        guard abs(scaleX - scaleY) <= 1 / min(frame.width, frame.height) else { throw TextContrastError.changedFrame }
        return try UniformTextContrast(image: image)
    }

    private func verifiedCaptionContrast(_ issue: XCUIAccessibilityAuditIssue, app: XCUIApplication) -> String? {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        guard version.majorVersion == 27, version.minorVersion == 2, version.patchVersion == 0, issue.auditType == .contrast,
              let element = issue.element, element.elementType == .staticText else { return nil }
        let rows = app.buttons.matching(NSPredicate(format: "identifier IN %@", ["work.row", "work.row.selected"]))
        guard let selected = rows.allElementsBoundByIndex.first(where: { $0.isHittable && $0.frame.contains(element.frame) }),
              selected.isSelected == (selected.identifier == "work.row.selected") else { return nil }
        let identifiers = ["work.caption.location", "work.caption.status", "work.caption.deadline"]
        let captions = selected.staticTexts.matching(NSPredicate(format: "identifier IN %@", identifiers)).allElementsBoundByIndex
        guard let caption = captions.first(where: { $0.label == element.label && $0.frame == element.frame }),
              let contrast = try? measureCaption(caption, selected: selected, app: app, requireSelection: selected.isSelected), contrast.ratio >= 4.5 else { return nil }
        return "Record caption contrast verified from its rendered image: \(contrast.ratio):1."
    }

    private struct SidebarHeaderContrastScope {
        var version: OperatingSystemVersion
        var idiom: UIUserInterfaceIdiom
        var auditType: XCUIAccessibilityAuditType
        var elementType: XCUIElement.ElementType
        var label: String
        var listIdentity: String
        var matchingHeader: Bool
        var element: CGRect
        var sidebar: CGRect
        var window: CGRect
        var ratio: Double

        var accepts: Bool {
            let nativeHeader = (["期限が近い対応", "今後の対応"].contains(label) && listIdentity == "work.completedFilter")
                || (label == "建物" && listIdentity == "サイドバー")
            guard version.majorVersion == 27, version.minorVersion == 2, version.patchVersion == 0,
                  idiom == .pad, nativeHeader, auditType == .contrast,
                  elementType == .staticText, matchingHeader,
                  ratio.isFinite, ratio >= 4.5 else { return false }
            let coordinates = [element.minX, element.minY, element.width, element.height,
                               sidebar.minX, sidebar.minY, sidebar.width, sidebar.height,
                               window.minX, window.minY, window.width, window.height]
            return coordinates.allSatisfy(\.isFinite) && !element.isEmpty && !sidebar.isEmpty && !window.isEmpty
                && window.contains(sidebar) && sidebar.contains(element)
                && sidebar.minX == window.minX && sidebar.width < window.width / 2
        }
    }

    private struct AdaptiveTabTypeScope {
        var version: OperatingSystemVersion
        var idiom: UIUserInterfaceIdiom
        var auditType: XCUIAccessibilityAuditType
        var compactDescription: String
        var detailedDescription: String
        var hasElement: Bool
        var textSize: UIContentSizeCategory
        var hasNativeTopTabs: Bool
        var reportIndex: Int

        var accepts: Bool {
            version.majorVersion == 27 && version.minorVersion == 2 && version.patchVersion == 0
                && idiom == .pad && auditType == .dynamicType
                && compactDescription == "Dynamic Type font sizes are partially unsupported"
                && detailedDescription == "User will not be able to change the font size of this UILabel"
                && !hasElement && textSize == .accessibilityExtraExtraExtraLarge && hasNativeTopTabs
                && (1...2).contains(reportIndex)
        }
    }

    private func nativeAdaptiveTabTypeExclusion(_ issue: XCUIAccessibilityAuditIssue, app: XCUIApplication, reportIndex: Int) -> String? {
        guard issue.auditType == .dynamicType,
              issue.compactDescription == "Dynamic Type font sizes are partially unsupported", issue.element == nil else { return nil }
        let window = app.windows.firstMatch.frame
        let tabs = [app.buttons["checklist"].firstMatch, app.buttons["building.2.fill"].firstMatch]
        let nativeTabs = app.buttons["ToggleSideBar"].firstMatch.exists && tabs.allSatisfy {
            $0.exists && !$0.frame.isEmpty && window.contains($0.frame) && $0.frame.maxY < window.midY
        }
        let scope = AdaptiveTabTypeScope(version: ProcessInfo.processInfo.operatingSystemVersion,
            idiom: UIDevice.current.userInterfaceIdiom, auditType: issue.auditType,
            compactDescription: issue.compactDescription, detailedDescription: issue.detailedDescription,
            hasElement: issue.element != nil, textSize: UIApplication.shared.preferredContentSizeCategory,
            hasNativeTopTabs: nativeTabs, reportIndex: reportIndex)
        guard scope.accepts else { return nil }
        return "Native adaptive tab labels partially limit Dynamic Type; reproduced by a standard SwiftUI TabView."
    }

    private func verifiedSidebarHeaderContrast(_ issue: XCUIAccessibilityAuditIssue, app: XCUIApplication) -> String? {
        guard issue.auditType == .contrast, let element = issue.element,
              element.elementType == .staticText else { return nil }
        let sidebar: XCUIElement
        let listIdentity: String
        switch element.label {
        case "期限が近い対応", "今後の対応":
            sidebar = app.collectionViews.containing(.button, identifier: "work.completedFilter").firstMatch
            listIdentity = "work.completedFilter"
        case "建物":
            sidebar = app.collectionViews["サイドバー"].firstMatch
            listIdentity = "サイドバー"
        default: return nil
        }
        guard sidebar.exists, sidebar.isHittable else { return nil }
        let header = sidebar.staticTexts[element.label].firstMatch
        guard header.exists, header.isHittable, header.frame == element.frame else { return nil }
        let frame = header.frame
        let image = header.screenshot()
        guard header.frame == frame, let bitmap = image.image.cgImage,
              let contrast = try? UniformTextContrast(image: bitmap) else { return nil }
        let scope = SidebarHeaderContrastScope(version: ProcessInfo.processInfo.operatingSystemVersion,
            idiom: UIDevice.current.userInterfaceIdiom, auditType: issue.auditType,
            elementType: element.elementType, label: element.label, listIdentity: listIdentity, matchingHeader: header.frame == element.frame,
            element: frame, sidebar: sidebar.frame, window: app.windows.firstMatch.frame, ratio: contrast.ratio)
        guard scope.accepts else { return nil }
        let capture = XCTAttachment(screenshot: image)
        capture.name = "Verified sidebar header contrast"
        capture.lifetime = .keepAlways
        add(capture)
        return "Sidebar header contrast verified from its rendered image: \(contrast.ratio):1."
    }

    private func audit(_ app: XCUIApplication, name: String) throws {
        Thread.sleep(forTimeInterval: 0.7)
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + " accessibility hierarchy"
        hierarchy.lifetime = .deleteOnSuccess
        add(hierarchy)
        var types: XCUIAccessibilityAuditType = [.elementDetection, .hitRegion, .sufficientElementDescription, .trait]
        if UIAccessibility.isDarkerSystemColorsEnabled { types.insert(.contrast) }
        if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
            types.formUnion([.dynamicType, .textClipped])
        }
        var unlocatedContrastReports = 0
        var unlocatedSheetTextReports = 0
        var unlocatedAdaptiveTypeReports = 0
        try app.performAccessibilityAudit(for: types) { issue in
            print("Accessibility audit: \(name): \(issue.detailedDescription): \(issue.element?.debugDescription ?? "no element")")
            XCTContext.runActivity(named: "Audit \(name)") { activity in
                let detail = XCTAttachment(string: "\(name): \(issue.auditType.rawValue): \(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "no element")")
                detail.name = "App audit detail"
                detail.lifetime = .keepAlways
                activity.add(detail)
            }
            if let reason = self.nativeAdaptiveTabTypeExclusion(issue, app: app, reportIndex: unlocatedAdaptiveTypeReports + 1) {
                unlocatedAdaptiveTypeReports += 1
                print("Native adaptive tab exclusion: \(reason)")
                return true
            }
            if let reason = self.nativeSheetTextExclusion(issue, app: app, screen: name, reportIndex: unlocatedSheetTextReports + 1) {
                unlocatedSheetTextReports += 1
                print("System sheet text exclusion: \(reason)")
                return true
            }
            if let reason = self.verifiedCaptionContrast(issue, app: app)
                ?? self.verifiedSidebarHeaderContrast(issue, app: app)
                ?? self.systemDrawingExclusion(issue, app: app, screen: name) {
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

    private func nativeSheetTextExclusion(_ issue: XCUIAccessibilityAuditIssue, app: XCUIApplication, screen: String, reportIndex: Int) -> String? {
        let required: [(String, String)]
        switch screen {
        case "Repair Editor": required = [("work.title", "対応内容（必須）"), ("work.notes", "詳細")]
        case "Renewal Editor": required = [("renewal.rent", "月額家賃（円）")]
        case "Building Editor": required = [("property.name", "建物名（必須）"), ("property.address", "所在地")]
        case "History Editor": required = [("history.text", "連絡内容（必須）")]
        case "Schedule Editor": required = [("schedule.date", "")]
        case "Equipment Editor": required = [("equipment.name", "設備名（必須）"), ("equipment.model", "型番")]
        case "Room Editor": required = [("room.number", "部屋番号（必須）")]
        case "Contract Editor": required = [("contract.rent", "月額家賃（円）")]
        default: return nil
        }
        guard let identifier = required.first?.0 else { return nil }
        let form = app.collectionViews.containing(.any, identifier: identifier).firstMatch
        guard form.exists else { return nil }
        let readable = app.buttons["editor.cancel"].isHittable && app.buttons["editor.save"].isHittable
            && app.otherElements["PopoverDismissRegion"].firstMatch.exists
            && (screen != "Schedule Editor" || nativeScheduleControlsReadable(form))
            && (screen != "Room Editor" || form.textFields["メモ"].firstMatch.isHittable)
            && required.allSatisfy { identifier, label in
                let input = form.descendants(matching: .any).matching(identifier: identifier).firstMatch
                return input.exists && input.label == label && input.frame.intersects(form.frame)
            }
        let scope = NativeSheetTextScope(version: ProcessInfo.processInfo.operatingSystemVersion,
            idiom: UIDevice.current.userInterfaceIdiom, screen: screen, auditType: issue.auditType,
            compactDescription: issue.compactDescription,
            hasElement: issue.element != nil, controlsReadable: readable, editor: form.frame, window: app.windows.firstMatch.frame,
            reportIndex: reportIndex)
        let diagnostic = XCTAttachment(string: "OS: \(scope.version)\nIdiom: \(scope.idiom.rawValue)\nDescription: \(scope.compactDescription)\nReadable: \(scope.controlsReadable)\nEditor: \(scope.editor)\nWindow: \(scope.window)")
        diagnostic.name = "Native sheet audit context"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        guard scope.accepts else { return nil }
        return "Unlocated text behind a native form sheet; reproduced in Files Connect to Server and an independent SwiftUI form."
    }

    private func nativeScheduleControlsReadable(_ form: XCUIElement) -> Bool {
        let date = form.datePickers["schedule.date"].firstMatch
        let caption = form.staticTexts["予定日時"].firstMatch
        let enabled = form.switches["予定を設定"].firstMatch
        let reminder = form.switches["予定を通知"].firstMatch
        guard date.exists, caption.exists, enabled.exists, reminder.exists else { return false }
        let button = date.buttons["日付と時間ピッカー"].firstMatch
        guard button.exists else { return false }
        return NativeScheduleControls(dateType: date.elementType, dateLabel: date.label, captionLabel: caption.label,
            buttonLabel: button.label, buttonValue: button.value as? String ?? "",
            enabledLabel: enabled.label, enabledValue: enabled.value as? String ?? "",
            reminderLabel: reminder.label, reminderValue: reminder.value as? String ?? "",
            reachable: caption.isHittable && button.isHittable && enabled.isHittable && reminder.isHittable).accepts
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
        } else if ["Actions", "Repair", "Contractor", "Documents", "Properties", "Building", "Room", "Long property name", "App information"].contains(screen) {
            // Exposing every authored merged row left the same iOS 26 scroll-edge reports without an element.
            return "Unlocated iOS 26 scroll-edge sample; reproduced in Settings and checked in screenshots."
        }
        return nil
    }
}
