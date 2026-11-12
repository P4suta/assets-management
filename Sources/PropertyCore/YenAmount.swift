import Foundation

public enum YenAmount {
    public static let maximum = 1_000_000_000_000
    public static let maximumInputLength = 17

    public static func checked(_ value: Int?) throws -> Int? {
        if let value, !(0...maximum).contains(value) { throw DomainError.invalidAmount }
        return value
    }

    public static func parse(_ text: String) throws -> Int? {
        guard text.unicodeScalars.prefix(maximumInputLength + 1).count <= maximumInputLength else {
            throw DomainError.invalidAmount
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var normalized = ""
        for scalar in trimmed.unicodeScalars {
            switch scalar.value {
            case 48...57: normalized.unicodeScalars.append(scalar)
            case 65_296...65_305:
                normalized += String(scalar.value - 65_296)
            case 44, 65_292: normalized += ","
            default: throw DomainError.invalidAmount
            }
        }
        let groups = normalized.split(separator: ",", omittingEmptySubsequences: false)
        if groups.count > 1 {
            guard let first = groups.first, (1...3).contains(first.count),
                  groups.dropFirst().allSatisfy({ $0.count == 3 }) else { throw DomainError.invalidAmount }
        }
        let digits = groups.joined()
        guard !digits.isEmpty, let value = Int(digits) else { throw DomainError.invalidAmount }
        return try checked(value)
    }
}

public struct AmountInput: Equatable, Sendable {
    public enum Issue: Equatable, Sendable { case tooLong, invalidAmount }

    public private(set) var text = ""
    public private(set) var issue: Issue?
    public var isValid: Bool { issue == nil }

    public init(_ text: String = "") { replace(with: text) }

    public mutating func replace(with candidate: String) {
        guard candidate.unicodeScalars.prefix(YenAmount.maximumInputLength + 1).count <= YenAmount.maximumInputLength else {
            issue = .tooLong
            return
        }
        text = candidate
        do {
            _ = try YenAmount.parse(candidate)
            issue = nil
        } catch { issue = .invalidAmount }
    }

    public mutating func clear() { self = AmountInput() }

    public func value() throws -> Int? {
        guard isValid else { throw DomainError.invalidAmount }
        return try YenAmount.parse(text)
    }
}
