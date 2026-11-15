import UIKit
import XCTest

@MainActor final class NativeListTypeTests: XCTestCase {
    func testPartialHeaderTypeScopeRequiresTheCurrentMeasuredNativeCaption() {
        let frame = CGRect(x: 16, y: 665, width: 370, height: 83.333333)
        let identity = "property.photos.header"
        let native = NativeListTypeScope(version: OperatingSystemVersion(majorVersion: 26, minorVersion: 5, patchVersion: 0),
            idiom: .phone, screen: "Building", auditType: .dynamicType,
            compactDescription: "Dynamic Type font sizes are partially unsupported",
            detail: "User will not be able to change the font size of this SwiftUI.AccessibilityNode",
            hasElement: true, textSize: .accessibilityExtraExtraExtraLarge, listIdentity: "property.detail", matchingCaptions: true,
            measurements: [identity: NativeListTextMeasurement(label: "写真", frame: frame, renderedHeight: 120, minimumHeight: 80)],
            list: CGRect(x: 0, y: 0, width: 402, height: 874), window: CGRect(x: 0, y: 0, width: 402, height: 874),
            reportedCaption: NativeListLocatedCaption(type: .staticText, label: "写真", frame: frame))
        XCTAssertTrue(native.accepts)
        let rejected: [(inout NativeListTypeScope) -> Void] = [
            { $0.version.majorVersion = 27 }, { $0.version.minorVersion = 4 }, { $0.version.patchVersion = 1 },
            { $0.idiom = .pad }, { $0.screen = "Contact" }, { $0.auditType = .textClipped },
            { $0.compactDescription = "Dynamic Type font sizes are unsupported" },
            { $0.detail = "Unknown report" }, { $0.hasElement = false }, { $0.textSize = .large },
            { $0.listIdentity = "room.detail" }, { $0.matchingCaptions = false }, { $0.reportedCaption = nil },
            { $0.reportedCaption?.type = .button }, { $0.reportedCaption?.label = "部屋" },
            { $0.reportedCaption?.frame.origin.y += 1 }, { $0.measurements = [:] },
            { $0.measurements["unknown"] = $0.measurements.removeValue(forKey: identity) },
            { $0.measurements[identity]?.label = "部屋" }, { $0.measurements[identity]?.renderedHeight = 79 },
            { $0.measurements[identity]?.minimumHeight = 0 }, { $0.measurements[identity]?.frame = .zero },
            { $0.measurements[identity]?.frame.origin.x = .nan }, { $0.measurements[identity]?.frame.origin.y = 900 },
            { $0.list = .zero }, { $0.list.size.width = 403 }, { $0.window = .zero }, { $0.reportIndex = 0 }, { $0.reportIndex = 2 }
        ]
        for reject in rejected {
            var candidate = native
            reject(&candidate)
            XCTAssertFalse(candidate.accepts)
        }
    }

    func testPartialListTypeScopeRejectsUnverifiedOrUnsupportedReports() {
        let identity = "contact.related.sample"
        let native = NativeListTypeScope(version: OperatingSystemVersion(majorVersion: 27, minorVersion: 2, patchVersion: 0),
            idiom: .phone, screen: "Contact", auditType: .dynamicType,
            compactDescription: "Dynamic Type font sizes are partially unsupported",
            detail: "User will not be able to change the font size of this SwiftUI.AccessibilityNode",
            hasElement: false, textSize: .accessibilityExtraExtraExtraLarge, listIdentity: "contact.detail",
            matchingCaptions: true, measurements: [identity: NativeListTextMeasurement(label: "未来ヶ丘団地",
                frame: CGRect(x: 20, y: 640, width: 380, height: 93), renderedHeight: 135, minimumHeight: 87)],
            list: CGRect(x: 0, y: 0, width: 420, height: 912), window: CGRect(x: 0, y: 0, width: 420, height: 912))
        XCTAssertTrue(native.accepts)
        let rejected: [(inout NativeListTypeScope) -> Void] = [
            { $0.version.majorVersion = 26 }, { $0.version.majorVersion = 28 },
            { $0.version.minorVersion = 3 }, { $0.version.patchVersion = 1 },
            { $0.idiom = .pad }, { $0.screen = "Contract" }, { $0.auditType = .textClipped },
            { $0.compactDescription = "Dynamic Type font sizes are unsupported" },
            { $0.detail = "User will not be able to change the font size of this element" },
            { $0.hasElement = true }, { $0.textSize = .large }, { $0.listIdentity = "room.detail" },
            { $0.matchingCaptions = false }, { $0.measurements = [:] },
            { $0.measurements["unknown"] = $0.measurements.removeValue(forKey: identity) },
            { $0.measurements[identity]?.label = "" },
            { $0.measurements[identity]?.renderedHeight = 86 },
            { $0.measurements[identity]?.minimumHeight = 0 },
            { $0.measurements[identity]?.frame = .zero },
            { $0.measurements[identity]?.frame.origin.x = .nan },
            { $0.measurements[identity]?.frame.origin.y = 900 },
            { $0.list = .zero }, { $0.list.size.width = 421 }, { $0.window = .zero },
            { $0.reportIndex = 0 }, { $0.reportIndex = 2 }
        ]
        for reject in rejected {
            var scope = native
            reject(&scope)
            XCTAssertFalse(scope.accepts)
        }
        var floorRuntime = native
        floorRuntime.version = OperatingSystemVersion(majorVersion: 26, minorVersion: 5, patchVersion: 0)
        XCTAssertTrue(floorRuntime.accepts)
    }

    func testRenderedTextHeightRejectsAnUnscaledFont() throws {
        func renderedHeight(fontSize: CGFloat) throws -> Int {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: CGSize(width: 380, height: 100), format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 380, height: 100))
                ("未来ヶ丘団地" as NSString).draw(at: CGPoint(x: 0, y: 0), withAttributes: [
                    .font: UIFont.systemFont(ofSize: fontSize), .foregroundColor: UIColor.black
                ])
            }
            return try UniformTextContrast(image: XCTUnwrap(image.cgImage)).foregroundHeight
        }
        let minimum = try renderedHeight(fontSize: 34)
        XCTAssertGreaterThan(minimum, 0)
        XCTAssertLessThan(try renderedHeight(fontSize: 17), minimum)
        XCTAssertGreaterThanOrEqual(try renderedHeight(fontSize: 53), minimum)
    }
}
