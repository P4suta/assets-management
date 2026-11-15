import CoreGraphics

extension CGRect {
    func containsWithRoundingTolerance(_ target: CGRect) -> Bool {
        let edges = [minX, minY, maxX, maxY, target.minX, target.minY, target.maxX, target.maxY]
        guard !isEmpty, !target.isEmpty, edges.allSatisfy(\.isFinite) else { return false }
        let magnitude = max(1, edges.map(abs).max() ?? 1)
        let tolerance = magnitude.ulp * 8
        return target.minX >= minX - tolerance && target.minY >= minY - tolerance
            && target.maxX <= maxX + tolerance && target.maxY <= maxY + tolerance
    }
}

struct ListViewport {
    let bounds: CGRect

    func contains(_ target: CGRect, requireFullVisibility: Bool) -> Bool {
        guard !target.isEmpty, !target.isInfinite,
              [target.minX, target.minY, target.maxX, target.maxY].allSatisfy(\.isFinite) else { return false }
        return requireFullVisibility ? bounds.containsWithRoundingTolerance(target) : bounds.contains(CGPoint(x: target.midX, y: target.midY))
    }

    init?(list: CGRect, window: CGRect, target: CGRect, bars: [CGRect]) {
        guard ([list, window, target] + bars).allSatisfy({
            !$0.isInfinite && [$0.minX, $0.minY, $0.maxX, $0.maxY].allSatisfy(\.isFinite)
        }) else { return nil }
        let visible = list.intersection(window)
        guard !visible.isEmpty else { return nil }
        var top = visible.minY
        var bottom = visible.maxY
        for bar in bars where !bar.isEmpty && bar.intersects(visible) && bar.minX < target.maxX && bar.maxX > target.minX {
            if bar.midY < visible.midY { top = max(top, bar.maxY) }
            else { bottom = min(bottom, bar.minY) }
        }
        guard bottom > top else { return nil }
        bounds = CGRect(x: visible.minX, y: top, width: visible.width, height: bottom - top)
    }
}

struct ScrollCoordinates {
    let lower: CGVector
    let upper: CGVector

    func restorationOffset(from current: CGFloat, to original: CGFloat, in bounds: CGRect) -> CGFloat? {
        let span = bounds.height * (lower.dy - upper.dy)
        guard current.isFinite, original.isFinite, span.isFinite, span > 0 else { return nil }
        let offset = original - current
        guard offset.isFinite else { return nil }
        return min(max(offset, -span), span)
    }

    init?(bounds: CGRect, keyboard: CGRect?, rowLeading: CGFloat? = nil) {
        guard !bounds.isEmpty, !bounds.isInfinite,
              [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY].allSatisfy(\.isFinite) else { return nil }
        let leading = rowLeading ?? bounds.minX + min(16, bounds.width / 4)
        guard leading.isFinite, leading >= bounds.minX, leading < bounds.midX else { return nil }
        let horizontal = min((leading - bounds.minX + 8) / bounds.width, 0.5)
        let panX = bounds.minX + bounds.width * horizontal
        var bottom = bounds.maxY
        if let keyboard, !keyboard.isEmpty,
           keyboard.minX <= panX, panX <= keyboard.maxX,
           keyboard.minY < bounds.maxY, keyboard.maxY > bounds.minY {
            bottom = max(bounds.minY, keyboard.minY)
        }
        let start = min(0.8, (bottom - bounds.minY - 20) / bounds.height)
        guard start > 0.22 else { return nil }
        lower = CGVector(dx: horizontal, dy: start)
        upper = CGVector(dx: horizontal, dy: 0.22)
    }
}
