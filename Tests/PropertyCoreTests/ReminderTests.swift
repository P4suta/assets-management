import Foundation
import Testing
import os
@testable import PropertyCore

private let reminderNow = Date(timeIntervalSince1970: 1_800_000_000)

private func reminderCalendar(_ zone: String = "Asia/Tokyo") throws -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: zone))
    return calendar
}

private func reminderFixture() throws -> Records {
    var records = try fixtureRecords()
    records.work[0].dueDate = reminderNow.addingTimeInterval(172_800)
    records.work[0].nextVisit = reminderNow.addingTimeInterval(3_600)
    records.work[0].reminderEnabled = true
    records.work[0].visitReminderEnabled = true
    return try records.validated()
}

private enum NotificationOperation: Hashable { case authorization, permission, pending, remove, add }

private actor ControlledNotificationCenter: ReminderNotificationCenter {
    private var permission: ReminderAuthorization
    private var suspended: Set<NotificationOperation>
    private var failAdd = false
    private var failPermission = false
    private var counts: [NotificationOperation: Int] = [:]
    private var arrivals: [NotificationOperation: [CheckedContinuation<Bool, Never>]] = [:]
    private var ended: Set<NotificationOperation> = []
    private var resumes: [NotificationOperation: [CheckedContinuation<Void, Never>]] = [:]
    private(set) var requests: [String: ReminderRequest] = [:]
    private(set) var foreignIdentifiers: [String] = ["unrelated-feature"]

    init(permission: ReminderAuthorization = .authorized, suspended: Set<NotificationOperation> = []) {
        self.permission = permission
        self.suspended = suspended
    }

    func authorization() async -> ReminderAuthorization {
        let value = permission
        await checkpoint(.authorization)
        return value
    }

    func requestAuthorization() async throws -> ReminderAuthorization {
        await checkpoint(.permission)
        if failPermission { throw StorageError.unwritable }
        return permission
    }

    func pendingIdentifiers() async -> [String] {
        let identifiers = Array(requests.keys) + foreignIdentifiers
        await checkpoint(.pending)
        return identifiers
    }

    func remove(identifiers: [String]) async {
        await checkpoint(.remove)
        for identifier in identifiers { requests.removeValue(forKey: identifier) }
        foreignIdentifiers.removeAll { identifiers.contains($0) }
    }

    func add(_ request: ReminderRequest) async throws {
        await checkpoint(.add)
        if failAdd { throw StorageError.unwritable }
        requests[request.identifier] = request
    }

    func setPermission(_ permission: ReminderAuthorization) { self.permission = permission }
    func setFailures(add: Bool = false, permission: Bool = false) {
        failAdd = add
        failPermission = permission
    }
    func count(_ operation: NotificationOperation) -> Int { counts[operation, default: 0] }

    func waitFor(_ operation: NotificationOperation) async -> Bool {
        if counts[operation, default: 0] > 0 { return true }
        if ended.contains(operation) { return false }
        return await withCheckedContinuation { arrivals[operation, default: []].append($0) }
    }

    func finishWaiting(for operation: NotificationOperation) {
        ended.insert(operation)
        for continuation in arrivals.removeValue(forKey: operation) ?? [] { continuation.resume(returning: false) }
    }

    func release(_ operation: NotificationOperation) {
        suspended.remove(operation)
        for continuation in resumes.removeValue(forKey: operation) ?? [] { continuation.resume() }
    }

    private func checkpoint(_ operation: NotificationOperation) async {
        counts[operation, default: 0] += 1
        for continuation in arrivals.removeValue(forKey: operation) ?? [] { continuation.resume(returning: true) }
        if suspended.contains(operation) {
            await withCheckedContinuation { resumes[operation, default: []].append($0) }
        }
    }
}

@MainActor private func reaches(_ operation: NotificationOperation, center: ControlledNotificationCenter,
                               during task: Task<ReminderSyncReport, Never>) async -> Bool {
    let completion = Task {
        _ = await task.value
        if !Task.isCancelled { await center.finishWaiting(for: operation) }
    }
    let reached = await center.waitFor(operation)
    completion.cancel()
    return reached
}

@Suite @MainActor struct ReminderTests {
    @Test func deadlineUsesLocalMorningAndVisitUsesTheDisplayedMinute() throws {
        let calendar = try reminderCalendar()
        let records = try reminderFixture()
        let plan = try ReminderPlan(records: records, now: reminderNow, calendar: calendar)
        #expect(plan.requests.count == 2)
        let deadline = try #require(plan.requests.first { $0.kind == .deadline })
        #expect(calendar.component(.hour, from: deadline.fireDate) == 9)
        #expect(calendar.isDate(deadline.fireDate, inSameDayAs: try #require(records.work[0].dueDate)))
        for request in plan.requests {
            #expect(request.components.second == 0)
            #expect(request.components.timeZone == .gmt)
            #expect(request.components.calendar?.identifier == .gregorian)
            #expect(request.components.calendar?.date(from: request.components) == request.fireDate)
            #expect(ReminderRequest.owns(request.identifier))
        }
    }

    @Test(arguments: WorkStatus.allCases, [false, true])
    func statusAndIndependentTogglesControlEachRequest(status: WorkStatus, enabled: Bool) throws {
        var records = try reminderFixture()
        records.work[0].status = status
        records.work[0].reminderEnabled = enabled
        records.work[0].visitReminderEnabled = !enabled
        let plan = try ReminderPlan(records: records, now: reminderNow, calendar: reminderCalendar())
        #expect(plan.requests.map(\.kind) == (status == .completed ? [] : [enabled ? .deadline : .visit]))
    }

    @Test func currentMinuteAndExactDeadlineAreExpired() throws {
        let calendar = try reminderCalendar()
        var records = try reminderFixture()
        records.work[0].nextVisit = reminderNow.addingTimeInterval(1)
        let deadline = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: reminderNow))
        records.work[0].dueDate = deadline
        let plan = try ReminderPlan(records: records, now: max(reminderNow, deadline), calendar: calendar)
        #expect(plan.requests.isEmpty)
        #expect(plan.expiredWorkIDs == [records.work[0].id])
    }

    @Test(arguments: ["2026-03-08T06:30:00Z", "2026-11-01T05:30:00Z", "2026-11-01T06:30:00Z"])
    func daylightSavingTransitionsKeepAbsoluteVisitAndLocalDeadline(iso: String) throws {
        let calendar = try reminderCalendar("America/New_York")
        let visit = try #require(ISO8601DateFormatter().date(from: iso))
        var records = try reminderFixture()
        records.work[0].nextVisit = visit
        records.work[0].dueDate = visit
        let plan = try ReminderPlan(records: records, now: visit.addingTimeInterval(-60), calendar: calendar)
        let request = try #require(plan.requests.first { $0.kind == .visit })
        #expect(request.fireDate == visit)
        #expect(request.components.calendar?.date(from: request.components) == visit)
        #expect(calendar.component(.hour, from: try #require(plan.requests.first { $0.kind == .deadline }).fireDate) == 9)
    }

    @Test func onlyReminderIdentifiersAreOwned() {
        for identifier in ["unrelated-feature", UUID().uuidString, "../file.visit", ".deadline", "unknown.visit", UUID().uuidString + ".other"] {
            #expect(!ReminderRequest.owns(identifier))
        }
    }

    @Test func passiveReconciliationNeverRequestsPermissionAndRecoversAfterSettings() async throws {
        let records = try reminderFixture()
        let id = records.work[0].id
        let center = ControlledNotificationCenter(permission: .notDetermined)
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { reminderNow }, calendar: { calendar })
        #expect(await coordinator.synchronize(records).result(for: id) == .denied)
        #expect(await center.count(.permission) == 0)
        #expect(await center.requests.isEmpty)
        await center.setPermission(.authorized)
        #expect(await coordinator.synchronize(records).result(for: id) == .none)
        #expect(await center.requests.count == 2)
        #expect(await center.foreignIdentifiers == ["unrelated-feature"])
    }

    @Test func explicitPermissionRequestIsLimitedToTheEditedFutureReminder() async throws {
        var records = try reminderFixture()
        let center = ControlledNotificationCenter(permission: .notDetermined)
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { reminderNow }, calendar: { calendar })
        _ = await coordinator.synchronize(records, requestingAuthorizationFor: UUID())
        #expect(await center.count(.permission) == 0)
        let id = records.work[0].id
        records.work[0].status = .completed
        _ = await coordinator.synchronize(records, requestingAuthorizationFor: id)
        #expect(await center.count(.permission) == 0)
        records.work[0].status = .inProgress
        _ = await coordinator.synchronize(records, requestingAuthorizationFor: id)
        #expect(await center.count(.permission) == 1)
    }

    @Test(arguments: [NotificationOperation.authorization, .permission, .pending, .add])
    private func completionSupersedesEverySuspendedSchedulingPhase(operation: NotificationOperation) async throws {
        let records = try reminderFixture()
        let id = records.work[0].id
        let center = ControlledNotificationCenter(permission: operation == .permission ? .notDetermined : .authorized,
                                                  suspended: [operation])
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { reminderNow }, calendar: { calendar })
        let first = Task { await coordinator.synchronize(records, requestingAuthorizationFor: id) }
        guard await reaches(operation, center: center, during: first) else {
            Issue.record("Synchronization ended before reaching the controlled operation.")
            return
        }
        let completed = try records.settingStatus(.completed, for: id)
        let release = Task { await center.release(operation) }
        let latest = await coordinator.synchronize(completed)
        await release.value
        #expect(await first.value.isSuperseded)
        #expect(!latest.isSuperseded)
        #expect(latest.result(for: id) == .none)
        #expect(await center.requests.isEmpty)
        #expect(await center.count(.add) == (operation == .add ? 1 : 0))
        #expect(await center.foreignIdentifiers == ["unrelated-feature"])
    }

    @Test func registrationFailureRetriesFromTheSameCommittedSnapshot() async throws {
        let records = try reminderFixture()
        let id = records.work[0].id
        let center = ControlledNotificationCenter()
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { reminderNow }, calendar: { calendar })
        await center.setFailures(add: true)
        #expect(await coordinator.synchronize(records).result(for: id) == .failed)
        await center.setFailures()
        #expect(await coordinator.synchronize(records).result(for: id) == .none)
        #expect(await center.requests.count == 2)
        let disabled = try records.settingStatus(.completed, for: id)
        _ = await coordinator.synchronize(disabled)
        #expect(await center.requests.isEmpty)
    }

    @Test func permissionFailureCanBeRetriedWithoutChangingRecords() async throws {
        let records = try reminderFixture()
        let id = records.work[0].id
        let center = ControlledNotificationCenter(permission: .notDetermined, suspended: [.permission])
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { reminderNow }, calendar: { calendar })
        await center.setFailures(permission: true)
        let first = Task { await coordinator.synchronize(records, requestingAuthorizationFor: id) }
        guard await reaches(.permission, center: center, during: first) else {
            Issue.record("Synchronization ended before requesting permission.")
            return
        }
        await center.release(.permission)
        #expect(await first.value.result(for: id) == .failed)
        #expect(await center.requests.isEmpty)
        await center.setFailures()
        await center.setPermission(.authorized)
        #expect(await coordinator.synchronize(records).result(for: id) == .none)
        #expect(await center.requests.count == 2)
    }

    @Test func reopeningSupersedesASuspendedCancellation() async throws {
        let records = try reminderFixture()
        let id = records.work[0].id
        let center = ControlledNotificationCenter(suspended: [.remove])
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { reminderNow }, calendar: { calendar })
        _ = await coordinator.synchronize(records)
        let completed = try records.settingStatus(.completed, for: id)
        let cancelling = Task { await coordinator.synchronize(completed) }
        guard await reaches(.remove, center: center, during: cancelling) else {
            Issue.record("Synchronization ended before cancelling the reminder.")
            return
        }
        let release = Task { await center.release(.remove) }
        let reopened = await coordinator.synchronize(records)
        await release.value
        #expect(await cancelling.value.isSuperseded)
        #expect(!reopened.isSuperseded)
        #expect(await center.requests.count == 2)
        #expect(await center.foreignIdentifiers == ["unrelated-feature"])
    }

    @Test func datesExpiringDuringPendingLookupAreNotRegistered() async throws {
        var records = try reminderFixture()
        records.work[0].reminderEnabled = false
        let clock = OSAllocatedUnfairLock(initialState: reminderNow)
        let center = ControlledNotificationCenter(suspended: [.pending])
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { clock.withLock { $0 } }, calendar: { calendar })
        let syncing = Task { await coordinator.synchronize(records) }
        guard await reaches(.pending, center: center, during: syncing) else {
            Issue.record("Synchronization ended before reading pending reminders.")
            return
        }
        clock.withLock { $0 = reminderNow.addingTimeInterval(7_200) }
        await center.release(.pending)
        #expect(await syncing.value.result(for: records.work[0].id) == .pastDate)
        #expect(await center.requests.isEmpty)
    }

    @Test func clockChangesNeverBypassAuthorization() async throws {
        var records = try reminderFixture()
        records.work[0].reminderEnabled = false
        records.work[0].nextVisit = reminderNow.addingTimeInterval(-3_600)
        let clock = OSAllocatedUnfairLock(initialState: reminderNow)
        let center = ControlledNotificationCenter(permission: .denied, suspended: [.pending])
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { clock.withLock { $0 } }, calendar: { calendar })
        let syncing = Task { await coordinator.synchronize(records) }
        guard await reaches(.pending, center: center, during: syncing) else {
            Issue.record("Synchronization ended before reading pending reminders.")
            return
        }
        clock.withLock { $0 = reminderNow.addingTimeInterval(-7_200) }
        await center.release(.pending)
        #expect(await syncing.value.result(for: records.work[0].id) == .denied)
        #expect(await center.requests.isEmpty)
    }

    @Test func permissionIntentNeverLeaksIntoAPassiveSynchronization() async throws {
        let records = try reminderFixture()
        let id = records.work[0].id
        let center = ControlledNotificationCenter(permission: .notDetermined)
        let calendar = try reminderCalendar()
        let coordinator = ReminderCoordinator(center: center, now: { reminderNow }, calendar: { calendar })
        _ = await coordinator.synchronize(try records.settingStatus(.completed, for: id), requestingAuthorizationFor: id)
        _ = await coordinator.synchronize(records)
        #expect(await center.count(.permission) == 0)
        #expect(await center.requests.isEmpty)
    }

    @Test func aNewSnapshotSupersedesRemovalAtTheExactExpirationTime() async throws {
        let records = try reminderFixture()
        let calendar = try reminderCalendar()
        let plan = try ReminderPlan(records: records, now: reminderNow, calendar: calendar)
        let deadline = try #require(plan.requests.first { $0.kind == .deadline })
        let clock = OSAllocatedUnfairLock(initialState: reminderNow)
        let center = ControlledNotificationCenter(suspended: [.add, .remove])
        let coordinator = ReminderCoordinator(center: center, now: { clock.withLock { $0 } }, calendar: { calendar })
        let syncing = Task { await coordinator.synchronize(records) }
        guard await reaches(.add, center: center, during: syncing) else {
            Issue.record("Synchronization ended before registering the first reminder.")
            return
        }
        clock.withLock { $0 = deadline.fireDate }
        await center.release(.add)
        guard await reaches(.remove, center: center, during: syncing) else {
            Issue.record("An expired reminder must be removed before synchronization completes.")
            return
        }
        let release = Task { await center.release(.remove) }
        let latest = await coordinator.synchronize(try records.settingStatus(.completed, for: records.work[0].id))
        await release.value
        #expect(await syncing.value.isSuperseded)
        #expect(!latest.isSuperseded)
        #expect(await center.requests.isEmpty)
        #expect(await center.count(.add) == 1)
    }

    @Test func cancellingASubscriberKeepsCommittedRemindersScheduled() async throws {
        let records = try reminderFixture()
        let calendar = try reminderCalendar()
        let center = ControlledNotificationCenter(suspended: [.authorization])
        let coordinator = ReminderCoordinator(center: center, now: { reminderNow }, calendar: { calendar })
        let syncing = Task { await coordinator.synchronize(records) }
        guard await reaches(.authorization, center: center, during: syncing) else {
            Issue.record("Synchronization ended before checking authorization.")
            return
        }
        syncing.cancel()
        await center.release(.authorization)
        #expect(!(await syncing.value).isSuperseded)
        #expect(await center.requests.count == 2)
    }
}
