import XCTest

@MainActor struct NativePhotoLibrary {
    let app: XCUIApplication

    var cancel: XCUIElement { app.buttons["Cancel"].firstMatch }
    var content: XCUIElement { app.scrollViews["photosView_content_scroll_view"] }
    var introduction: XCUIElement {
        app.otherElements["PXGSingleViewContainerView_AX"].buttons["閉じる"].firstMatch
    }

    func waitForPresentation(dismissIntroduction: Bool = true) -> Bool {
        let interactive = NSPredicate { _, _ in
            (introduction.exists && introduction.isHittable) || (cancel.exists && cancel.isHittable)
        }
        guard XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: interactive, object: nil)], timeout: 30) == .completed else {
            return false
        }
        guard dismissIntroduction else { return true }
        if introduction.exists {
            if !introduction.isHittable {
                guard content.waitForExistence(timeout: 10) else { return false }
                content.swipeDown(velocity: .slow)
            }
            guard introduction.wait(for: \.isHittable, toEqual: true, timeout: 10) else { return false }
            introduction.tap()
            guard introduction.waitForNonExistence(timeout: 5) else { return false }
        }
        return cancel.wait(for: \.isHittable, toEqual: true, timeout: 30)
    }
}
