import Foundation

public enum ContractNoticeTiming: Codable, Equatable, Sendable {
    case date(Date)
    case monthsBeforeExpiry(Int)
}

public struct ContractNotice: Codable, Equatable, Sendable {
    public var timing: ContractNoticeTiming
    public var advanceDays: Int
    public var reminderEnabled: Bool

    public init(timing: ContractNoticeTiming, advanceDays: Int = 30, reminderEnabled: Bool = false) {
        self.timing = timing
        self.advanceDays = advanceDays
        self.reminderEnabled = reminderEnabled
    }

    public func deadline(expiry: Date, calendar: Calendar) -> Date? {
        switch timing {
        case .date(let date): date.timeIntervalSince1970.isFinite ? date : nil
        case .monthsBeforeExpiry(let months):
            (1...1_200).contains(months) ? calendar.date(byAdding: .month, value: -months, to: expiry) : nil
        }
    }
}
