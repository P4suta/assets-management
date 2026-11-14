import UIKit
import XCTest

struct NativeCaptionClippingScope {
    var version: OperatingSystemVersion
    var screen: String
    var auditType: XCUIAccessibilityAuditType
    var detail: String
    var elementType: XCUIElement.ElementType
    var label: String
    var textSize: UIContentSizeCategory
    var element: CGRect
    var viewport: CGRect
    var window: CGRect
    var bars: [CGRect]
    var scale: CGFloat
    var matchingCaptions: Int
    var foregroundPixels: Int

    @MainActor var accepts: Bool {
        guard version.majorVersion == 27, version.minorVersion == 2, version.patchVersion == 0,
              auditType == .textClipped,
              detail == "Text of this SwiftUI.AccessibilityNode may be clipped at larger Dynamic Type sizes.",
              elementType == .staticText, textSize == .accessibilityExtraExtraExtraLarge,
              let style = Self.fontStyle(screen: screen, label: label), matchingCaptions == 1,
              scale.isFinite, scale >= 1, scale <= 4, foregroundPixels > 0,
              [element, viewport, window].allSatisfy(Self.valid),
              window.contains(viewport), viewport.contains(element),
              !bars.contains(where: { $0.intersects(element) }) else { return false }
        let traits = UITraitCollection(preferredContentSizeCategory: textSize)
        let font = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        let required = (label as NSString).boundingRect(with: CGSize(width: element.width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return required.width.isFinite && required.height.isFinite && required.width > 0 && required.height > 0
            && element.width + 1 / scale >= required.width && element.height + 1 / scale >= required.height
    }

    static func fontStyle(screen: String, label: String) -> UIFont.TextStyle? {
        switch (screen, label) {
        case ("History Editor", "メモ（必須）"),
             ("Property Editor", "建物名（必須）"), ("Property Editor", "部屋番号（必須）"),
             ("Building Editor", "建物名（必須）"), ("Room Editor", "部屋番号（必須）"),
             ("Equipment Editor", "設備名（必須）"), ("Contract Editor", "月額家賃（円）"):
            .subheadline
        case ("Contact", "緊急連絡先"), ("Repair", "通知設定を開く"),
             ("Repair", "設定を開く"), ("Repair", "閉じる"): .body
        default: nil
        }
    }

    private static func valid(_ rect: CGRect) -> Bool {
        [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite)
            && rect.width > 0 && rect.height > 0
    }
}
