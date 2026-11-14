import XCTest

@MainActor final class AdaptiveRecordLayoutTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testListViewportUsesVisibleBarsAndRetainsReachableEndRows() throws {
        let window = CGRect(x: 0, y: 0, width: 1032, height: 1376)
        let lastRow = CGRect(x: 340, y: 1262, width: 672, height: 74)
        let viewport = try XCTUnwrap(ListViewport(list: CGRect(x: 0, y: 32, width: 1032, height: 1344),
            window: window, target: lastRow,
            bars: [CGRect(x: 0, y: 106, width: 320, height: 108), CGRect(x: 320, y: 106, width: 712, height: 54)]))
        XCTAssertEqual(viewport.bounds.minY, 160)
        XCTAssertTrue(viewport.bounds.contains(lastRow))
        let phone = CGRect(x: 0, y: 0, width: 420, height: 912)
        let obscured = CGRect(x: 20, y: 820, width: 380, height: 60)
        let compact = try XCTUnwrap(ListViewport(list: phone, window: phone, target: obscured,
            bars: [CGRect(x: 0, y: 68, width: 420, height: 54), CGRect(x: 116, y: 819, width: 188, height: 80)]))
        XCTAssertEqual(compact.bounds, CGRect(x: 0, y: 122, width: 420, height: 697))
        XCTAssertFalse(compact.bounds.contains(obscured))
        XCTAssertNil(ListViewport(list: .zero, window: phone, target: obscured, bars: []))
        XCTAssertNil(ListViewport(list: phone, window: phone, target: obscured, bars: [.infinite]))
    }

    func testStatusRowFitsAdjacentRowsAndPersistsEveryChoice() {
        let app = launch()
        openRepair(app)
        assertStatusRowGeometry(app, name: "Initial status row")
        for choice in ["対応中", "返答待ち", "完了", "未着手"] {
            app.buttons["work.status"].tap()
            let option = app.buttons[choice].firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5), app.debugDescription)
            option.tap()
            assertStatus(choice, app: app)
            assertStatusRowGeometry(app, name: choice + " status row")
            app.terminate()
            app.launch()
            XCTAssertTrue(app.buttons["work.add"].waitForExistence(timeout: 10))
            openRepair(app)
            assertStatus(choice, app: app)
        }
    }

    func testActiveAndCompletedRecordsShareSearchAndTheList() {
        let app = launch()
        openRepair(app)
        app.buttons["work.status"].tap()
        app.buttons["完了"].firstMatch.tap()
        assertStatus("完了", app: app)
        let sidebarSearch = app.searchFields.firstMatch
        if !sidebarSearch.exists || !sidebarSearch.isHittable {
            let back = app.navigationBars["修繕の詳細"].buttons["対応"]
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.tap()
        }
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("未来ヶ丘\n")
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.staticTexts["対応済み"].waitForExistence(timeout: 5))
        XCTAssertTrue(list.staticTexts["対応"].exists)
        XCTAssertTrue(record("給湯器から水漏れ", app: app).exists)
        XCTAssertTrue(record("契約更新の確認", app: app).exists)
        XCTAssertFalse(record("共用灯の交換", app: app).exists)
        XCTAssertFalse(app.buttons["work.completedFilter"].exists)
        capture(app, name: "Search includes active and completed records")
        search.tap()
        search.buttons["テキストを消去"].tap()
        search.tap()
        search.typeText("青葉\n")
        XCTAssertEqual(search.value as? String, "青葉")
        XCTAssertTrue(record("共用灯の交換", app: app).waitForExistence(timeout: 5))
        XCTAssertTrue(record("消防設備点検", app: app).exists)
        XCTAssertFalse(record("給湯器から水漏れ", app: app).exists)
        XCTAssertFalse(record("契約更新の確認", app: app).exists)
    }

    func testPropertyDetailsKeepWorkActionsInTheWorkTab() {
        let app = launch()
        selectTab("物件", app: app)
        record("未来ヶ丘団地", app: app).tap()
        let building = app.navigationBars["建物"]
        XCTAssertTrue(building.waitForExistence(timeout: 5))
        XCTAssertTrue(building.buttons["建物を編集"].exists)
        XCTAssertFalse(app.buttons["共用部分の対応を追加"].exists)
        record("203号室", app: app).tap()
        XCTAssertTrue(app.navigationBars["203号室"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["対応を追加"].exists)
        XCTAssertFalse(record("給湯器から水漏れ", app: app).exists)
        app.buttons["賃貸借契約"].tap()
        let contract = app.navigationBars["賃貸借契約"]
        XCTAssertTrue(contract.waitForExistence(timeout: 5))
        XCTAssertTrue(contract.buttons["契約を編集"].exists)
        XCTAssertFalse(app.buttons["契約更新の対応を追加"].exists)
    }

    func testFailedStatusSaveKeepsSelectionAndAllowsRetry() {
        let app = launch(failFirstSave: true)
        openRepair(app)
        app.buttons["work.status"].tap()
        app.buttons["返答待ち"].firstMatch.tap()
        let failure = app.alerts["保存できませんでした"]
        XCTAssertTrue(failure.waitForExistence(timeout: 5))
        failure.buttons["閉じる"].tap()
        assertStatus("未着手", app: app)
        app.buttons["work.status"].tap()
        app.buttons["返答待ち"].firstMatch.tap()
        assertStatus("返答待ち", app: app)
    }

    func testImportedPhotoRendersInlineAfterRelaunch() throws {
        let app = launch()
        openRepair(app)
        let previousPhotos = restoredPhotoIdentifiers(app)
        XCTAssertEqual(previousPhotos.count, 1)
        let previous = try XCTUnwrap(previousPhotos.first)
        openPhotoLibrary(app)
        chooseLibraryPhoto(app)
        let newPhoto = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "photo.", previous)).firstMatch
        revealDetail(newPhoto, app: app)
        XCTAssertTrue(newPhoto.waitForExistence(timeout: 15))
        assertPhotoRendered(newPhoto, app: app, name: "Imported photo inline")
        let identifier = newPhoto.identifier
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["work.add"].waitForExistence(timeout: 10))
        openRepair(app)
        XCTAssertEqual(restoredPhotoIdentifiers(app), Set([previous, identifier]))
        assertPhotoRendered(app.buttons[identifier], app: app, name: "Imported photo after relaunch")
        XCTAssertFalse(app.alerts["写真を追加できませんでした"].exists)
    }

    func testFailedPhotoImportCanRetryWithoutDuplicatingThePhoto() throws {
        let app = launch(failFirstSave: true)
        openRepair(app)
        let previousPhotos = restoredPhotoIdentifiers(app)
        XCTAssertEqual(previousPhotos.count, 1)
        let previous = try XCTUnwrap(previousPhotos.first)
        openPhotoLibrary(app)
        chooseLibraryPhoto(app)
        let failure = app.alerts["写真を追加できませんでした"]
        XCTAssertTrue(failure.waitForExistence(timeout: 15), app.debugDescription)
        failure.buttons["写真を選び直す"].tap()
        chooseLibraryPhoto(app)
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND identifier != %@", "photo.", previous)).firstMatch
        revealDetail(photo, app: app)
        XCTAssertTrue(photo.waitForExistence(timeout: 15))
        assertPhotoRendered(photo, app: app, name: "Retried photo import")
        let identifier = photo.identifier
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["work.add"].waitForExistence(timeout: 10))
        openRepair(app)
        XCTAssertEqual(restoredPhotoIdentifiers(app), Set([previous, identifier]))
        assertPhotoRendered(app.buttons[identifier], app: app, name: "Retried photo after relaunch")
    }

    private func openPhotoLibrary(_ app: XCUIApplication) {
        let addPhoto = app.buttons["photos.add"]
        revealDetail(addPhoto, app: app)
        addPhoto.tap()
        let library = app.buttons["photos.library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), app.debugDescription)
        library.tap()
    }

    private func chooseLibraryPhoto(_ app: XCUIApplication) {
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        let asset = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(asset.waitForExistence(timeout: 30), app.debugDescription)
        let onboarding = app.otherElements["PXGSingleViewContainerView_AX"].buttons["閉じる"].firstMatch
        if onboarding.exists && onboarding.isHittable { onboarding.tap() }
        let window = app.windows.firstMatch
        var previous: CGRect?
        let visible = NSPredicate { _, _ in
            guard asset.exists && asset.isHittable else { return false }
            let frame = asset.frame
            defer { previous = frame }
            return !frame.isEmpty && window.frame.contains(frame) && frame == previous
        }
        let readiness = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: visible, object: asset)], timeout: 30)
        let picker = XCTAttachment(string: app.debugDescription)
        picker.name = "Native photo library selection"
        picker.lifetime = .keepAlways
        add(picker)
        capture(app, name: "Native photo library")
        XCTAssertEqual(readiness, .completed)
        let frame = asset.frame
        let origin = window.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: frame.midX - window.frame.minX, dy: frame.midY - window.frame.minY)).tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
    }

    func testVisibleReminderToggleMeetsIncreasedContrast() throws {
        guard UIAccessibility.isDarkerSystemColorsEnabled else {
            throw XCTSkip("Reminder toggle contrast requires Increase Contrast.")
        }
        let app = launch()
        openRepair(app)
        app.buttons["work.edit"].tap()
        let form = app.collectionViews["editor.form"]
        let caption = app.staticTexts["期限を通知"].firstMatch
        reveal(caption, in: form, app: app)
        XCTAssertTrue(form.frame.contains(caption.frame))
        XCTAssertTrue(app.windows.firstMatch.frame.contains(caption.frame))
        let screenshot = caption.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Visible reminder toggle caption"
        attachment.lifetime = .keepAlways
        add(attachment)
        capture(app, name: "Visible reminder toggle in the native form")
        let measurement = try UniformTextContrast(image: XCTUnwrap(screenshot.image.cgImage))
        let detail = XCTAttachment(string: "Reminder toggle: \(measurement.ratio):1\nForm: \(form.frame)\nCaption: \(caption.frame)")
        detail.name = "Reminder toggle measured contrast"
        detail.lifetime = .keepAlways
        add(detail)
        XCTAssertGreaterThanOrEqual(measurement.ratio, 4.5)
        try app.performAccessibilityAudit(for: .contrast) { issue in
            guard let element = issue.element else { return false }
            return !element.frame.intersects(caption.frame)
        }
    }

    func testOffscreenReminderScopeRejectsUnmeasuredAndDifferentContexts() {
        let form = CGRect(x: 226, y: 358, width: 580, height: 660)
        let caption = CGRect(x: 262, y: 1201, width: 80, height: 20.5)
        let anchor = CGRect(x: 262, y: 723, width: 508, height: 23)
        let measurement = ReminderCaptionMeasurement(label: "期限を通知", formIdentity: "editor.form", form: form,
            offscreenCaption: caption, visibleCaption: CGRect(x: 262, y: 961.5, width: 80, height: 20.5),
            anchorIdentity: "work.title", originalAnchor: anchor, restoredAnchor: anchor, ratio: 20.822)
        let verified = NativeOffscreenReminderScope(
            version: OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0),
            idiom: .pad, screen: "Repair Editor", auditType: .contrast, compactDescription: "Contrast failed", elementType: .staticText,
            label: "期限を通知", formIdentity: "editor.form", matchingCaptionInForm: true,
            element: caption, form: form, window: CGRect(x: 0, y: 0, width: 1032, height: 1376), measurement: measurement)
        XCTAssertTrue(verified.accepts)
        let rejected: [(inout NativeOffscreenReminderScope) -> Void] = [
            { $0.version.majorVersion = 26 }, { $0.version.majorVersion = 28 },
            { $0.version.minorVersion = 3 }, { $0.version.patchVersion = 1 },
            { $0.idiom = .phone }, { $0.screen = "Room Editor" }, { $0.screen = "Repair" },
            { $0.auditType = .elementDetection }, { $0.compactDescription = "Other contrast report" }, { $0.elementType = .switch },
            { $0.label = "期限を設定" }, { $0.formIdentity = "other.form" }, { $0.matchingCaptionInForm = false },
            { $0.measurement = nil }, { $0.measurement?.label = "予定を通知" },
            { $0.measurement?.formIdentity = "other.form" }, { $0.measurement?.form.origin.x += 1 },
            { $0.measurement?.offscreenCaption.origin.y = 900 }, { $0.measurement?.offscreenCaption.origin.y = 1360 },
            { $0.measurement?.visibleCaption.origin.y = 1201 },
            { $0.measurement?.visibleCaption.size.width += 1 }, { $0.measurement?.visibleCaption.size.height += 1 },
            { $0.measurement?.anchorIdentity = "work.notes" }, { $0.measurement?.restoredAnchor.origin.y += 1 },
            { $0.measurement?.originalAnchor = .zero; $0.measurement?.restoredAnchor = .zero },
            { $0.measurement?.ratio = 4.499 }, { $0.measurement?.ratio = .nan }, { $0.measurement?.ratio = .infinity },
            { $0.form = .zero }, { $0.window = .zero }, { $0.element.origin.x = .nan },
            { $0.reportIndex = 0 }, { $0.reportIndex = 2 }
        ]
        for reject in rejected {
            var scope = verified
            reject(&scope)
            XCTAssertFalse(scope.accepts)
        }
        for frame in [CGRect(x: 262, y: 1008, width: 80, height: 20.5),
                      CGRect(x: 262, y: 900, width: 80, height: 20.5),
                      CGRect(x: 262, y: 1360, width: 80, height: 20.5)] {
            var scope = verified
            scope.element = frame
            scope.measurement?.offscreenCaption = frame
            XCTAssertFalse(scope.accepts)
        }
        var threshold = verified
        threshold.measurement?.ratio = 4.5
        XCTAssertTrue(threshold.accepts)
        var reestimated = verified
        reestimated.element.origin.y = 1224
        XCTAssertTrue(reestimated.accepts)
    }

    func testOffscreenSidebarDeadlineRequiresVisibleContrastAndRestoredSelection() {
        let sidebar = CGRect(x: 0, y: 240, width: 320, height: 1136)
        let caption = CGRect(x: 36, y: 1278.5, width: 243.5, height: 105)
        let anchor = CGRect(x: 16, y: 420, width: 288, height: 300)
        let measurement = ReminderCaptionMeasurement(label: "期限 2026年11月20日", formIdentity: "work.list", form: sidebar,
            offscreenCaption: caption, visibleCaption: CGRect(x: 36, y: 950, width: 243.5, height: 105),
            anchorIdentity: "work.row.selected", originalAnchor: anchor, restoredAnchor: anchor, ratio: 12)
        let verified = NativeOffscreenReminderScope(
            version: OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0),
            idiom: .pad, screen: "Repair", auditType: .contrast, compactDescription: "Contrast failed", elementType: .staticText,
            label: measurement.label, formIdentity: "work.list", matchingCaptionInForm: true,
            element: caption, form: sidebar, window: CGRect(x: 0, y: 0, width: 1032, height: 1376), measurement: measurement)
        XCTAssertTrue(verified.accepts)
        let rejected: [(inout NativeOffscreenReminderScope) -> Void] = [
            { $0.screen = "Contract" }, { $0.formIdentity = "contacts.list" },
            { $0.label = "対応中" }, { $0.matchingCaptionInForm = false },
            { $0.element.origin.y = 1000 }, { $0.element.origin.y = 1400 },
            { $0.measurement?.offscreenCaption.origin.y -= 1 },
            { $0.measurement?.visibleCaption.origin.y = 1278.5 },
            { $0.measurement?.visibleCaption.size.height -= 1 },
            { $0.measurement?.anchorIdentity = "work.row" }, { $0.measurement?.restoredAnchor.origin.y += 1 },
            { $0.measurement?.ratio = 4.49 }, { $0.measurement?.ratio = .nan },
            { $0.measurement = nil }, { $0.form.size.width = 600 },
            { $0.auditType = .dynamicType }, { $0.elementType = .button },
            { $0.version.patchVersion = 1 }, { $0.idiom = .phone }, { $0.reportIndex = 2 }
        ]
        for reject in rejected {
            var scope = verified
            reject(&scope)
            XCTAssertFalse(scope.accepts)
        }
    }

    func testListTitlesRemainAboveSearchAndRecordsAfterRotation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch()
        for title in ["対応", "物件"] {
            if title == "物件" { selectTab(title, app: app) }
            assertListHeader(title, app: app, name: title + " initial portrait")
            for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight] {
                let record = title == "対応" ? "給湯器から水漏れ" : "未来ヶ丘団地"
                let item = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", record)).firstMatch
                XCTAssertTrue(item.waitForExistence(timeout: 5))
                item.tap()
                let detailTitle = title == "対応" ? "修繕の詳細" : "建物"
                XCTAssertTrue(app.navigationBars[detailTitle].waitForExistence(timeout: 5))
                XCUIDevice.shared.orientation = orientation
                waitForWindow(app, landscape: true)
                capture(app, name: title + " landscape")
                XCUIDevice.shared.orientation = .portrait
                waitForWindow(app, landscape: false)
                let back = app.navigationBars[detailTitle].buttons[title]
                if back.exists { back.tap() }
                assertListHeader(title, app: app, name: title + " restored portrait")
            }
        }
    }

    private func launch(failFirstSave: Bool = false) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--seeded", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
            + (failFirstSave ? ["--fail-first-save"] : [])
        app.launchEnvironment["UITEST_STORAGE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["work.add"].waitForExistence(timeout: 10))
        return app
    }

    private func openRepair(_ app: XCUIApplication) {
        let repair = record("給湯器から水漏れ", app: app)
        reveal(repair, in: app.collectionViews["work.list"], app: app)
        XCTAssertTrue(repair.waitForExistence(timeout: 5), app.debugDescription)
        repair.tap()
        XCTAssertTrue(app.buttons["work.status"].waitForExistence(timeout: 5), app.debugDescription)
    }

    private func assertStatus(_ title: String, app: XCUIApplication) {
        let control = app.buttons["work.status"]
        let value = NSPredicate(format: "value == %@", title)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: value, object: control)], timeout: 5), .completed)
        XCTAssertEqual(app.alerts.count, 0)
    }

    private func assertPhotoRendered(_ photo: XCUIElement, app: XCUIApplication, name: String) {
        revealDetail(photo, app: app)
        let loaded = NSPredicate { _, _ in photo.exists && photo.frame.height > 100 }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: loaded, object: photo)], timeout: 10), .completed)
        XCTAssertTrue(photo.isHittable)
        let image = photo.images.matching(NSPredicate(format: "identifier BEGINSWITH %@", "photo.image.")).firstMatch
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(image.frame.width, 0)
        XCTAssertEqual(image.frame.width, image.frame.height, accuracy: 1,
                       "The imported building fixture must retain its square aspect ratio.")
        capture(app, name: name)
    }

    private func revealDetail(_ element: XCUIElement, app: XCUIApplication) {
        reveal(element, in: app.collectionViews["work.detail"], app: app)
    }

    private func restoredPhotoIdentifiers(_ app: XCUIApplication) -> Set<String> {
        let photos = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "photo."))
        var identifiers: Set<String> = []
        reveal(app.buttons["photos.add"], in: app.collectionViews["work.detail"], app: app) {
            identifiers.formUnion(photos.allElementsBoundByIndex.map(\.identifier))
        }
        return identifiers
    }

    private func reveal(_ element: XCUIElement, in list: XCUIElement, app: XCUIApplication,
                        observing: () -> Void = {}) {
        let window = app.windows.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), app.debugDescription)
        let frame = list.frame
        let bars = (app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex).filter(\.isHittable).map(\.frame)
        let target = element.exists && !element.frame.isEmpty ? element.frame : frame
        guard let unobscured = ListViewport(list: frame, window: window.frame, target: target, bars: bars)?.bounds else {
            XCTFail("The list must provide a viewport outside visible navigation bars.")
            return
        }
        func reachable() -> Bool {
            guard element.exists && element.isHittable else { return false }
            if element.frame.height > unobscured.height { return element.frame.intersects(unobscured) }
            return unobscured.contains(element.frame)
        }
        observing()
        if reachable() { return }
        guard let coordinates = ScrollCoordinates(bounds: unobscured, keyboard: nil) else {
            XCTFail("The detail list must provide a visible scroll viewport.")
            return
        }
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let lower = origin.withOffset(CGVector(dx: unobscured.minX - window.frame.minX + unobscured.width * coordinates.lower.dx,
                                              dy: unobscured.minY - window.frame.minY + unobscured.height * coordinates.lower.dy))
        let upper = origin.withOffset(CGVector(dx: unobscured.minX - window.frame.minX + unobscured.width * coordinates.upper.dx,
                                              dy: unobscured.minY - window.frame.minY + unobscured.height * coordinates.upper.dy))
        for _ in 0..<8 {
            if !element.exists || element.frame.midY > unobscured.midY {
                lower.press(forDuration: 0.05, thenDragTo: upper)
            } else {
                upper.press(forDuration: 0.05, thenDragTo: lower)
            }
            observing()
            if reachable() { return }
        }
        XCTFail("The list control must be reachable by scrolling.\n" + app.debugDescription)
    }

    private func assertStatusRowGeometry(_ app: XCUIApplication, name: String) {
        let detail = app.collectionViews.containing(.button, identifier: "work.status").firstMatch
        let due = detail.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "期限")).firstMatch
        XCTAssertTrue(due.waitForExistence(timeout: 5), app.debugDescription)
        let statusRow = detail.cells.containing(.button, identifier: "work.status").firstMatch
        let dueRow = detail.cells.containing(.staticText, identifier: due.label).firstMatch
        XCTAssertTrue(statusRow.exists && dueRow.exists, detail.debugDescription)
        capture(app, name: name)
        XCTAssertGreaterThan(dueRow.frame.height, 0)
        XCTAssertLessThanOrEqual(statusRow.frame.height, dueRow.frame.height * 1.5,
                                 "A one-line status selector must keep the scale of neighboring metadata rows.")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(statusRow.frame))
        XCTAssertTrue(app.buttons["work.status"].isHittable)
        XCTAssertEqual(app.buttons["work.status"].label, "状態")
    }

    private func assertListHeader(_ title: String, app: XCUIApplication, name: String) {
        let heading = app.navigationBars[title].staticTexts[title].firstMatch
        let search = app.searchFields.firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(search.waitForExistence(timeout: 5), app.debugDescription)
        let add = app.buttons[title == "対応" ? "work.add" : "property.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        let firstRecord = record(title == "対応" ? "給湯器から水漏れ" : "未来ヶ丘団地", app: app)
        XCTAssertTrue(firstRecord.waitForExistence(timeout: 5), app.debugDescription)
        var previous: [CGRect]?
        let settled = NSPredicate { _, _ in
            let current = [heading.frame, search.frame, firstRecord.frame]
            defer { previous = current }
            return current.allSatisfy { !$0.isEmpty } && current == previous
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: settled, object: heading)], timeout: 10), .completed)
        capture(app, name: name)
        XCTAssertGreaterThanOrEqual(heading.frame.minY, add.frame.minY,
                                    "The title must stay inside the native toolbar row.")
        XCTAssertLessThanOrEqual(heading.frame.maxY, add.frame.maxY,
                                 "The title must stay inside the native toolbar row.")
        XCTAssertLessThanOrEqual(heading.frame.maxY, search.frame.minY,
                                 "The list title must remain above its search field after rotation.")
        XCTAssertFalse(heading.frame.intersects(firstRecord.frame),
                       "The list title must not overlap the first record after rotation.")
        XCTAssertTrue(firstRecord.isHittable)
    }

    private func waitForWindow(_ app: XCUIApplication, landscape: Bool) {
        let rotated = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return !frame.isEmpty && ((frame.width > frame.height) == landscape)
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rotated, object: app)], timeout: 10), .completed)
    }

    private func record(_ title: String, app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", title, title)).firstMatch
    }

    private func selectTab(_ title: String, app: XCUIApplication) {
        let standard = app.tabBars.buttons[title]
        if standard.exists { standard.tap() }
        else {
            let symbol = title == "物件" ? "building.2.fill" : "checklist"
            let tab = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ AND label == %@", symbol, title)).firstMatch
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
