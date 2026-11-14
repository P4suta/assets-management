import UIKit
import XCTest

@MainActor final class NativeOffscreenCaptionTests: XCTestCase {
    func testScrollEdgeClippingRequiresAnUnobscuredCompleteCaption() {
        let window = CGRect(x: 0, y: 0, width: 420, height: 912)
        let bars = [CGRect(x: 0, y: 88, width: 420, height: 54)]
        let version = OperatingSystemVersion(majorVersion: 26, minorVersion: 5, patchVersion: 0)
        let detail = "Text of this SwiftUI.AccessibilityNode may be clipped at larger Dynamic Type sizes."
        let measurement = NativeCaptionClippingScope(version: version, screen: "Contact", auditType: .textClipped,
            detail: detail, elementType: .staticText, label: "緊急連絡先", textSize: .accessibilityExtraExtraExtraLarge,
            element: CGRect(x: 20, y: 196, width: 380, height: 93), viewport: window, window: window,
            bars: bars, scale: 3, matchingCaptions: 1, foregroundPixels: 1_000)
        let valid = NativeOffscreenCaptionScope(version: version, screen: "Contact", auditType: .textClipped,
            detail: detail, elementType: .staticText, label: "緊急連絡先", matchingCaption: true,
            element: CGRect(x: 20, y: 120, width: 380, height: 93), listIdentity: "contact.detail",
            list: window, window: window, bars: bars, measurement: measurement)
        XCTAssertTrue(valid.accepts)
        let rejected: [(inout NativeOffscreenCaptionScope) -> Void] = [
            { $0.version.minorVersion = 4 }, { $0.screen = "Repair" }, { $0.listIdentity = "work.detail" },
            { $0.auditType = .dynamicType }, { $0.detail = "Unknown report" }, { $0.elementType = .button },
            { $0.label = "Unknown caption" }, { $0.matchingCaption = false }, { $0.measurement = nil },
            { $0.element.origin.y = 196 }, { $0.element.origin.y = -1_000 }, { $0.element.size.width = 379 },
            { $0.element.size.height = 40 }, { $0.element.origin.x = .nan }, { $0.element.size.width = .infinity },
            { $0.list.size.height = 800 }, { $0.window.size.width = 421 }, { $0.bars = [] },
            { $0.measurement?.foregroundPixels = 0 }, { $0.measurement?.matchingCaptions = 2 },
            { $0.measurement?.element.size.height = 30 }, { $0.measurement?.element.origin.y = 100 },
            { $0.measurement?.label = "Unknown caption" }, { $0.measurement?.version.patchVersion = 1 }
        ]
        for reject in rejected {
            var candidate = valid
            reject(&candidate)
            XCTAssertFalse(candidate.accepts)
        }
    }
}
