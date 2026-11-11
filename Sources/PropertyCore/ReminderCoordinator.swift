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
    private var records = Records()
    private var revision: UInt64 = 0
    private var running = false
    private var permissionIntents: Set<UUID> = []
    private var waiters: [CheckedContinuation<ReminderSyncReport, Never>] = []

    public init(center: any ReminderNotificationCenter,
                now: @escaping @Sendable () -> Date = { Date() },
                calendar: @escaping @Sendable () -> Calendar = { Calendar.current }) {
        self.center = center
        self.now = now
        self.calendar = calendar
    }

    public func synchronize(_ records: Records, requestingAuthorizationFor id: UUID? = nil) async -> ReminderSyncReport {
        self.records = records
        revision &+= 1
        if let id { permissionIntents.insert(id) }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            if !running {
                running = true
                Task { await drain() }
            }
        }
    }

    private func drain() async {
        updates: while true {
            let current = revision
            var plan: ReminderPlan
            do { plan = try ReminderPlan(records: records, now: now(), calendar: calendar()) }
            catch {
                var report = ReminderSyncReport()
                report.failedWorkIDs = Set(records.work.map(\.id))
                finish(report)
                return
            }
            var report = ReminderSyncReport()
            var authorization = ReminderAuthorization.authorized
            if !plan.requests.isEmpty {
                authorization = await center.authorization()
                guard current == revision else { continue }
                let futureIDs = Set(plan.requests.map(\.workID))
                if authorization == .notDetermined, !permissionIntents.isDisjoint(with: futureIDs) {
                    permissionIntents.removeAll()
                    do { authorization = try await center.requestAuthorization() }
                    catch {
                        authorization = .denied
                        report.failedWorkIDs = futureIDs
                    }
                    guard current == revision else { continue }
                }
                do { plan = try ReminderPlan(records: records, now: now(), calendar: calendar()) }
                catch {
                    report.failedWorkIDs = Set(records.work.map(\.id))
                    finish(report)
                    return
                }
                if authorization != .authorized {
                    report.deniedWorkIDs = Set(plan.requests.map(\.workID))
                }
            }
            let pending = await center.pendingIdentifiers()
            guard current == revision else { continue }
            do { plan = try ReminderPlan(records: records, now: now(), calendar: calendar()) }
            catch {
                report.failedWorkIDs = Set(records.work.map(\.id))
                finish(report)
                return
            }
            report.expiredWorkIDs = plan.expiredWorkIDs
            if authorization != .authorized { report.deniedWorkIDs = Set(plan.requests.map(\.workID)) }
            let desired = authorization == .authorized ? plan.requests : []
            let identifiers = Set(desired.map(\.identifier))
            let obsolete = pending.filter { ReminderRequest.owns($0) && !identifiers.contains($0) }
            if !obsolete.isEmpty {
                await center.remove(identifiers: obsolete)
                guard current == revision else { continue }
            }
            for request in desired {
                if request.fireDate <= now() {
                    report.expiredWorkIDs.insert(request.workID)
                    await center.remove(identifiers: [request.identifier])
                    guard current == revision else { continue updates }
                    continue
                }
                do { try await center.add(request) }
                catch { report.failedWorkIDs.insert(request.workID) }
                guard current == revision else { continue updates }
            }
            finish(report)
            return
        }
    }

    private func finish(_ report: ReminderSyncReport) {
        let continuations = waiters
        waiters.removeAll()
        permissionIntents.removeAll()
        running = false
        for continuation in continuations { continuation.resume(returning: report) }
    }
}
