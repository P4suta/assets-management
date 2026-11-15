import CoreGraphics
import Foundation

enum PropertyCaptionRecognition {
    enum Failure: Error, Equatable { case missing, ambiguous, invalidGeometry }
    enum Symbol {
        case plus

        var recognizedCharacters: Set<Character> { ["+", "＋", "十", "→"] }
    }

    static func bounds(label: String, leadingSymbol: Symbol? = nil, observations: [(String, CGRect)]) throws -> CGRect {
        guard observations.allSatisfy({
            !$0.1.isEmpty && !$0.1.isInfinite && [$0.1.minX, $0.1.minY, $0.1.maxX, $0.1.maxY].allSatisfy(\.isFinite)
        }) else { throw Failure.invalidGeometry }
        let ordered = observations.sorted { $0.1.midY > $1.1.midY }
        var matches: [CGRect] = []
        for index in ordered.indices {
            var text = ""
            var frame = CGRect.null
            var previous: CGRect?
            var consumedSymbol = false
            for (fragment, bounds) in ordered[index...].prefix(3) {
                var value = fragment.filter { !$0.isWhitespace }
                if text.isEmpty, !consumedSymbol, let first = value.first, leadingSymbol?.recognizedCharacters.contains(first) == true {
                    value.removeFirst()
                    consumedSymbol = true
                }
                guard !value.isEmpty else { break }
                if let previous {
                    let gap = previous.minY - bounds.maxY
                    guard gap >= -1, gap <= max(previous.height, bounds.height) * 1.5,
                          bounds.minX < previous.maxX, bounds.maxX > previous.minX else { break }
                }
                text += value
                guard label.hasPrefix(text) else { break }
                frame = frame.union(bounds)
                if text == label { matches.append(frame); break }
                previous = bounds
            }
        }
        guard !matches.isEmpty else { throw Failure.missing }
        guard matches.count == 1 else { throw Failure.ambiguous }
        return matches[0]
    }
}
