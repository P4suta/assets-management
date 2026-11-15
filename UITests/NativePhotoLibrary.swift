import XCTest

@MainActor struct NativePhotoLibrary {
    let app: XCUIApplication

    var cancel: XCUIElement { app.buttons["Cancel"].firstMatch }
    var introduction: XCUIElement {
        app.otherElements["PXGSingleViewContainerView_AX"].buttons["閉じる"].firstMatch
    }

    func waitForPresentation() -> Bool {
        let interactive = NSPredicate { _, _ in
            (introduction.exists && introduction.isHittable) || (cancel.exists && cancel.isHittable)
        }
        guard XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: interactive, object: nil)], timeout: 30) == .completed else {
            return false
        }
        if introduction.exists && introduction.isHittable { introduction.tap() }
        return cancel.wait(for: \.isHittable, toEqual: true, timeout: 30)
    }
}
