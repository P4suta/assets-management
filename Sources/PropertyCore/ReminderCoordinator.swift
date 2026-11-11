import Foundation

public enum ReminderAuthorization: Sendable { case notDetermined, denied, authorized }

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
    private var revision: UInt64 = 0
    private var permissionIntents: Set<UUID> = []
    private var tail: Task<ReminderSyncReport, Never>?

    public init(center: any ReminderNotificationCenter,
                now: @escaping @Sendable () -> Date = { Date() },
                calendar: @escaping @Sendable () -> Calendar = { Calendar.current }) {
        self.center = center
        self.now = now
        self.calendar = calendar
    }

    public func synchronize(_ records: Records, requestingAuthorizationFor id: UUID? = nil) async -> ReminderSyncReport {
        revision &+= 1
        let current = revision
        if let id { permissionIntents.insert(id) }
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
            var plan = try ReminderPlan(records: records, now: now(), calendar: calendar())
            var report = ReminderSyncReport()
            var authorization = await center.authorization()
            guard current == revision else { return .superseded }
            let pending = await center.pendingIdentifiers()
            guard current == revision else { return .superseded }
            plan = try ReminderPlan(records: records, now: now(), calendar: calendar())
            let futureIDs = Set(plan.requests.map(\.workID))
            if authorization == .notDetermined, !permissionIntents.isDisjoint(with: futureIDs) {
                permissionIntents = []
                do { authorization = try await center.requestAuthorization() }
                catch {
                    authorization = .denied
                    report.failedWorkIDs = futureIDs
                }
                guard current == revision else { return .superseded }
                plan = try ReminderPlan(records: records, now: now(), calendar: calendar())
            }
            report.expiredWorkIDs = plan.expiredWorkIDs
            if authorization != .authorized { report.deniedWorkIDs = Set(plan.requests.map(\.workID)) }
            let desired = authorization == .authorized ? plan.requests : []
            let identifiers = Set(desired.map(\.identifier))
            let obsolete = pending.filter { ReminderRequest.owns($0) && !identifiers.contains($0) }
            if !obsolete.isEmpty {
                await center.remove(identifiers: obsolete)
                guard current == revision else { return .superseded }
            }
            for request in desired {
                if request.fireDate <= now() {
                    report.expiredWorkIDs.insert(request.workID)
                    await center.remove(identifiers: [request.identifier])
                    guard current == revision else { return .superseded }
                    continue
                }
                do { try await center.add(request) }
                catch { report.failedWorkIDs.insert(request.workID) }
                guard current == revision else { return .superseded }
            }
            return report
        } catch {
            var report = ReminderSyncReport()
            report.failedWorkIDs = Set(records.work.map(\.id))
            return report
        }
    }
}
