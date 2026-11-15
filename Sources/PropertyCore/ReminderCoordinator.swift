import Foundation

public enum ReminderAuthorization: Equatable, Sendable { case notDetermined, denied, authorized }

public protocol ReminderNotificationCenter: Sendable {
    func authorization() async -> ReminderAuthorization
    func requestAuthorization() async throws -> ReminderAuthorization
    func pendingIdentifiers() async -> [String]
    func remove(identifiers: [String]) async
    func add(_ request: ReminderRequest) async throws
}

@MainActor public final class ReminderCoordinator {
    private let center: any ReminderNotificationCenter
    private let now: @Sendable () -> Date
    private let calendar: @Sendable () -> Calendar
    private let contractCalendar: Calendar?
    private var revision: UInt64 = 0
    private var permissionIntents: Set<ReminderTarget> = []
    private var tail: Task<ReminderSyncReport, Never>?

    public init(center: any ReminderNotificationCenter,
                now: @escaping @Sendable () -> Date = { Date() },
                calendar: @escaping @Sendable () -> Calendar = { Calendar.current },
                contractCalendar: Calendar? = nil) {
        self.center = center
        self.now = now
        self.calendar = calendar
        self.contractCalendar = contractCalendar
    }

    public func synchronize(_ records: Records, requestingAuthorizationFor id: UUID) async -> ReminderSyncReport {
        await synchronize(records, requestingAuthorizationFor: .work(id))
    }

    public func synchronize(_ records: Records, requestingAuthorizationFor target: ReminderTarget? = nil) async -> ReminderSyncReport {
        revision &+= 1
        let current = revision
        if let target { permissionIntents.insert(target) }
        let previous = tail
        let task = Task {
            _ = await previous?.value
            guard current == revision else { return ReminderSyncReport.superseded }
            return await reconcile(records, revision: current)
        }
        tail = task
        return await task.value
    }

    private func reconcile(_ records: Records, revision current: UInt64) async -> ReminderSyncReport {
        defer { if current == revision { permissionIntents = [] } }
        do {
            var plan = try ReminderPlan(records: records, now: now(), calendar: calendar(), contractCalendar: contractCalendar)
            var report = ReminderSyncReport()
            var authorization = await center.authorization()
            guard current == revision else { return .superseded }
            let pending = await center.pendingIdentifiers()
            guard current == revision else { return .superseded }
            plan = try ReminderPlan(records: records, now: now(), calendar: calendar(), contractCalendar: contractCalendar)
            let futureIDs = Set(plan.requests.map(\.target))
            if authorization == .notDetermined, !permissionIntents.isDisjoint(with: futureIDs) {
                permissionIntents = []
                do { authorization = try await center.requestAuthorization() }
                catch {
                    authorization = .denied
                    report.failedTargets = futureIDs
                }
                guard current == revision else { return .superseded }
                plan = try ReminderPlan(records: records, now: now(), calendar: calendar(), contractCalendar: contractCalendar)
            }
            report.authorization = authorization
            report.expiredTargets = plan.expiredTargets
            if authorization != .authorized { report.deniedTargets = Set(plan.requests.map(\.target)) }
            let desired = authorization == .authorized ? plan.requests : []
            let identifiers = Set(desired.map(\.identifier))
            let obsolete = pending.filter { ReminderRequest.owns($0) && !identifiers.contains($0) }
            if !obsolete.isEmpty {
                await center.remove(identifiers: obsolete)
                guard current == revision else { return .superseded }
            }
            var accepted: [ReminderRequest] = []
            for request in desired {
                if request.fireDate <= now() {
                    report.expiredTargets.insert(request.target)
                    await center.remove(identifiers: [request.identifier])
                    guard current == revision else { return .superseded }
                    continue
                }
                do {
                    try await center.add(request)
                    accepted.append(request)
                }
                catch { report.failedTargets.insert(request.target) }
                guard current == revision else { return .superseded }
            }
            if !accepted.isEmpty {
                let registered = Set(await center.pendingIdentifiers())
                guard current == revision else { return .superseded }
                let verifiedAt = now()
                for request in accepted where !registered.contains(request.identifier) {
                    if request.fireDate > verifiedAt { report.failedTargets.insert(request.target) }
                    else { report.expiredTargets.insert(request.target) }
                }
            }
            return report
        } catch {
            var report = ReminderSyncReport()
            report.failedTargets = Set(records.work.map { .work($0.id) } + records.rooms.map { .contract($0.id) })
            return report
        }
    }
}
