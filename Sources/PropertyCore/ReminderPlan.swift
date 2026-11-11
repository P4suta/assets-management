import Foundation

public enum ReminderResult: Equatable, Sendable {
    case none, denied, pastDate, failed
}

public struct ReminderRequest: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable { case deadline, visit }

    public let workID: UUID
    public let kind: Kind
    public let title: String
    public let fireDate: Date
    public let components: DateComponents
    public var identifier: String { workID.uuidString + "." + kind.rawValue }

    public static func owns(_ identifier: String) -> Bool {
        Kind.allCases.contains { kind in
            let suffix = "." + kind.rawValue
            return identifier.hasSuffix(suffix) && UUID(uuidString: String(identifier.dropLast(suffix.count))) != nil
        }
    }
}

public struct ReminderPlan: Equatable, Sendable {
    public let requests: [ReminderRequest]
    public let expiredWorkIDs: Set<UUID>

    public init(records: Records, now: Date, calendar: Calendar) throws {
        _ = try records.validated()
        guard now.timeIntervalSince1970.isFinite else { throw DomainError.invalidDates }
        var triggerCalendar = Calendar(identifier: .gregorian)
        triggerCalendar.timeZone = .gmt
        var requests: [ReminderRequest] = []
        var expired: Set<UUID> = []
        for item in records.work where item.status != .completed {
            var candidates: [(ReminderRequest.Kind, Date)] = []
            if item.reminderEnabled, let due = item.dueDate,
               let date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: due) {
                candidates.append((.deadline, date))
            }
            if item.visitReminderEnabled, let visit = item.nextVisit,
               let minute = calendar.dateInterval(of: .minute, for: visit)?.start {
                candidates.append((.visit, minute))
            }
            for (kind, date) in candidates {
                guard date > now else { expired.insert(item.id); continue }
                var components = triggerCalendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second], from: date)
                components.calendar = triggerCalendar
                components.timeZone = triggerCalendar.timeZone
                requests.append(ReminderRequest(workID: item.id, kind: kind, title: item.title,
                                                fireDate: date, components: components))
            }
        }
        self.requests = requests.sorted {
            $0.fireDate == $1.fireDate ? $0.identifier < $1.identifier : $0.fireDate < $1.fireDate
        }
        expiredWorkIDs = expired
    }
}

public struct ReminderSyncReport: Equatable, Sendable {
    public var isSuperseded = false
    public var deniedWorkIDs: Set<UUID> = []
    public var expiredWorkIDs: Set<UUID> = []
    public var failedWorkIDs: Set<UUID> = []

    static var superseded: Self {
        var report = Self()
        report.isSuperseded = true
        return report
    }

    public func result(for id: UUID) -> ReminderResult {
        if failedWorkIDs.contains(id) { return .failed }
        if deniedWorkIDs.contains(id) { return .denied }
        if expiredWorkIDs.contains(id) { return .pastDate }
        return .none
    }
}
