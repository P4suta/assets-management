import Foundation

public enum ReminderResult: Hashable, Sendable {
    case none, denied, pastDate, failed
}

public enum ReminderTarget: Hashable, Sendable {
    case work(UUID)
    case contract(UUID)

    public var id: UUID {
        switch self { case .work(let id), .contract(let id): id }
    }
}

public struct ReminderRequest: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable { case deadline, visit, contractAdvance, contractDeadline }

    public let target: ReminderTarget
    public let kind: Kind
    public let fireDate: Date
    public let components: DateComponents
    public var identifier: String { target.id.uuidString + "." + kind.rawValue }

    public static func target(for identifier: String) -> ReminderTarget? {
        guard let separator = identifier.lastIndex(of: "."),
              let id = UUID(uuidString: String(identifier[..<separator])),
              let kind = Kind(rawValue: String(identifier[identifier.index(after: separator)...])) else { return nil }
        switch kind {
        case .deadline, .visit: return .work(id)
        case .contractAdvance, .contractDeadline: return .contract(id)
        }
    }

    func compareForRegistration(to other: Self) -> ComparisonResult {
        let order = fireDate.compare(other.fireDate)
        if order != .orderedSame { return order }
        return identifier.compare(other.identifier)
    }

    public static func owns(_ identifier: String) -> Bool {
        target(for: identifier) != nil
    }
}

public struct ReminderPlan: Equatable, Sendable {
    public let requests: [ReminderRequest]
    public let expiredTargets: Set<ReminderTarget>

    public init(records: Records, now: Date, calendar: Calendar, contractCalendar: Calendar? = nil) throws {
        _ = try records.validated()
        guard now.timeIntervalSince1970.isFinite else { throw DomainError.invalidDates }
        let noticeCalendar = contractCalendar ?? calendar
        var triggerCalendar = Calendar(identifier: .gregorian)
        triggerCalendar.timeZone = .gmt
        var requests: [ReminderRequest] = []
        var expired: Set<ReminderTarget> = []
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
                guard date > now else { expired.insert(.work(item.id)); continue }
                var components = triggerCalendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second], from: date)
                components.calendar = triggerCalendar
                components.timeZone = triggerCalendar.timeZone
                requests.append(ReminderRequest(target: .work(item.id), kind: kind,
                                                fireDate: date, components: components))
            }
        }
        for room in records.rooms {
            guard let contract = room.contract, let notice = contract.notice, notice.reminderEnabled,
                  let deadline = notice.deadline(expiry: contract.end, calendar: noticeCalendar),
                  let morning = noticeCalendar.date(bySettingHour: 9, minute: 0, second: 0, of: deadline) else { continue }
            var candidates: [(ReminderRequest.Kind, Date)] = [(.contractDeadline, morning)]
            if notice.advanceDays > 0,
               let advance = noticeCalendar.date(byAdding: .day, value: -notice.advanceDays, to: morning) {
                candidates.append((.contractAdvance, advance))
            }
            for (kind, date) in candidates {
                let target = ReminderTarget.contract(room.id)
                guard date > now else { expired.insert(target); continue }
                var components = triggerCalendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second], from: date)
                components.calendar = triggerCalendar
                components.timeZone = triggerCalendar.timeZone
                requests.append(ReminderRequest(target: target, kind: kind,
                                                fireDate: date, components: components))
            }
        }
        self.requests = requests.sorted { $0.compareForRegistration(to: $1) == .orderedAscending }
        expiredTargets = expired
    }
}

public struct ReminderSyncReport: Equatable, Sendable {
    public var isSuperseded = false
    public var authorization: ReminderAuthorization?
    public var deniedTargets: Set<ReminderTarget> = []
    public var expiredTargets: Set<ReminderTarget> = []
    public var failedTargets: Set<ReminderTarget> = []

    static var superseded: Self {
        var report = Self()
        report.isSuperseded = true
        return report
    }

    public func result(for id: UUID) -> ReminderResult {
        result(for: .work(id))
    }

    public func result(for target: ReminderTarget) -> ReminderResult {
        if failedTargets.contains(target) { return .failed }
        if deniedTargets.contains(target) { return .denied }
        if expiredTargets.contains(target) { return .pastDate }
        return .none
    }
}
