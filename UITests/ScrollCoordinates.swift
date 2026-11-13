import CoreGraphics

struct ScrollCoordinates {
    let lower: CGVector
    let upper: CGVector

    init?(bounds: CGRect, keyboard: CGRect?) {
        guard !bounds.isEmpty, !bounds.isInfinite,
              [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY].allSatisfy(\.isFinite) else { return nil }
        let horizontal = 0.97
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
        upper = CGVector(dx: 0.97, dy: 0.22)
    }
}
