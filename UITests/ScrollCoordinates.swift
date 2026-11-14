import CoreGraphics

struct ListViewport {
    let bounds: CGRect

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

    init?(bounds: CGRect, keyboard: CGRect?) {
        guard !bounds.isEmpty, !bounds.isInfinite,
              [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY].allSatisfy(\.isFinite) else { return nil }
        let horizontal = 0.85
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
