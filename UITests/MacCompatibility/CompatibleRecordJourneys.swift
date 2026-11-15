import AppKit
import XCTest

@MainActor final class MacCompatibilityTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["MAC_COMPATIBLE_APP_PATH"])
        XCTAssertTrue(path.hasPrefix("/"))
        let registered = try XCTUnwrap(NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.p4suta.PropertyRecords"))
        XCTAssertEqual(registered.resolvingSymlinksInPath(), URL(fileURLWithPath: path, isDirectory: true).resolvingSymlinksInPath())
        addTeardownBlock { @MainActor in
            let app = XCUIApplication(url: URL(fileURLWithPath: path, isDirectory: true))
            guard app.state == .runningForeground || app.state == .runningBackground else { return }
            let image = XCTAttachment(screenshot: app.screenshot())
            image.name = "Mac native end state"
            image.lifetime = .keepAlways
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Mac native end hierarchy"
            hierarchy.lifetime = .keepAlways
            XCTContext.runActivity(named: "Mac native end state") { activity in
                activity.add(image)
                activity.add(hierarchy)
            }
            app.terminate()
        }
    }

    func testCompatibleRecordsSurviveNativeEditingResizingAndRelaunch() throws {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["MAC_COMPATIBLE_APP_PATH"])
        let app = XCUIApplication(url: URL(fileURLWithPath: path, isDirectory: true))
        app.launchArguments = ["--ui-testing", "--seeded", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launchEnvironment["UITEST_STORAGE_ID"] = UUID().uuidString
        app.launch()
        defer { app.terminate() }
        let suffix = String(UUID().uuidString.prefix(8))
        let property = "未来ヶ丘団地Mac" + suffix
        select("building.2.fill", in: app)
        click("property.add", in: app)
        enter(property, into: "property.name", in: app)
        enter("203", into: "property.room", in: app)
        enter("朝焼1-2-3", into: "property.address", in: app)
        resizeEditor(in: app, keeping: property)
        click("editor.cancel", in: app)
        choose("編集を続ける", in: app)
        XCTAssertEqual(input("property.name", in: app).value as? String, property)
        click("editor.save", in: app)
        choose(property, in: app)
        choose("203号室", in: app)
        XCTAssertTrue(app.buttons["room.edit"].waitForExistence(timeout: 5), app.debugDescription)
        choose("賃貸借契約", in: app)
        click("contract.edit", in: app)
        let start = input("contract.start", in: app).value as? String
        XCTAssertNotNil(start)
        click("contract.start", in: app)
        click("date.done", in: app)
        XCTAssertEqual(input("contract.start", in: app).value as? String, start)
        enter("85000", into: "contract.rent", in: app)
        click("contract.notice.record", in: app)
        click("contract.notice.timing", in: app)
        choose("満了日から計算", in: app)
        let increase = app.buttons["contract.notice.months-Increment"]
        reveal(increase, in: app)
        for _ in 0..<5 { increase.click() }
        XCTAssertTrue(app.staticTexts["満了日の6か月前"].exists)
        click("editor.save", in: app)
        XCTAssertTrue(app.buttons["contract.edit"].waitForExistence(timeout: 5))

        select("person.crop.rectangle.stack.fill", in: app)
        click("contacts.add", in: app)
        let contact = "設備の相談窓口" + suffix
        enter(contact, into: "contact.name", in: app)
        enter("朝焼設備", into: "contact.company", in: app)
        enter("+12025550142", into: "contact.phone", in: app)
        enter("maintenance@example.com", into: "contact.email", in: app)
        enter("夜間の連絡も受付", into: "contact.notes", in: app)
        click("contact.emergency", in: app)
        click("editor.save", in: app)
        choose(contact, in: app)
        XCTAssertTrue(app.buttons["contact.edit"].waitForExistence(timeout: 5))
        for (identifier, destination) in [("contact.phone.open", "tel:+12025550142"),
                                          ("contact.email.open", "mailto:maintenance@example.com")] {
            click(identifier, in: app)
            XCTAssertTrue(app.staticTexts[destination].waitForExistence(timeout: 5), app.debugDescription)
            app.buttons["キャンセル"].click()
            XCTAssertTrue(app.staticTexts[destination].waitForNonExistence(timeout: 5))
            XCTAssertTrue(app.buttons["contact.edit"].wait(for: \.isHittable, toEqual: true, timeout: 5))
        }

        select("checklist", in: app)
        click("work.add", in: app)
        click("work.building", in: app)
        choose(property, in: app)
        let repair = "共用扉の調整" + suffix
        enter(repair, into: "work.title", in: app)
        click("editor.save", in: app)
        choose(repair, in: app)
        click("memo.add", in: app)
        enter("現地確認を依頼", into: "history.text", in: app)
        click("editor.save", in: app)
        XCTAssertTrue(app.staticTexts["現地確認を依頼"].waitForExistence(timeout: 5))
        for status in ["対応中", "完了"] {
            click("work.status", in: app)
            choose(status, in: app)
            XCTAssertEqual(app.buttons["work.status"].value as? String, status)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Mac saved repair and memo"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        select("building.2.fill", in: app)
        choose(property, in: app)
        choose("203号室", in: app)
        choose("賃貸借契約", in: app)
        click("contract.edit", in: app)
        XCTAssertEqual(input("contract.rent", in: app).value as? String, "85000")
        XCTAssertTrue(app.staticTexts["満了日の6か月前"].exists)
        click("editor.cancel", in: app)
        select("checklist", in: app)
        choose(repair, in: app)
        XCTAssertEqual(app.buttons["work.status"].value as? String, "完了")
        XCTAssertTrue(app.staticTexts["現地確認を依頼"].exists)
    }

    private func resizeEditor(in app: XCUIApplication, keeping property: String) {
        let window = app.windows["SceneWindow"]
        let original = window.frame
        zoomWindow(in: app)
        XCTAssertNotEqual(window.frame.size, original.size)
        XCTAssertEqual(input("property.name", in: app).value as? String, property)
        XCTAssertTrue(app.buttons["editor.save"].isHittable)
        zoomWindow(in: app)
        XCTAssertEqual(window.frame.size, original.size)
        XCTAssertEqual(input("property.name", in: app).value as? String, property)
    }

    private func zoomWindow(in app: XCUIApplication) {
        app.menuBarItems["com.apple.menu.window"].click()
        app.menuItems["performZoom:"].click()
    }

    private func select(_ identifier: String, in app: XCUIApplication) {
        let tab = app.cells.matching(identifier: identifier).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5), app.debugDescription)
        tab.click()
    }

    private func click(_ identifier: String, in app: XCUIApplication) {
        let control = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        reveal(control, in: app)
        control.click()
    }

    private func choose(_ title: String, in app: XCUIApplication) {
        let control = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR title == %@ OR label BEGINSWITH %@", title, title, title + "、")
        ).firstMatch
        reveal(control, in: app)
        control.click()
    }

    private func input(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func enter(_ value: String, into identifier: String, in app: XCUIApplication) {
        let field = input(identifier, in: app)
        reveal(field, in: app)
        field.click()
        field.typeText(value)
        XCTAssertTrue(app.dialogs.firstMatch.waitForNonExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(field.value as? String, value, app.debugDescription)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), app.debugDescription)
        guard element.exists else { return }
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            let form = app.collectionViews["editor.form"]
            guard form.exists else { break }
            form.scroll(byDeltaX: 0, deltaY: -180)
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
}
