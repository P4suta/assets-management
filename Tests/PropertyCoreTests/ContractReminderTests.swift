import Foundation
import Testing
@testable import PropertyCore

private actor ContractNotificationCenter: ReminderNotificationCenter {
    var permission: ReminderAuthorization = .authorized
    private(set) var prompts = 0
    private(set) var requests: [String: ReminderRequest] = [:]
    private var fail = false
    func setPermission(_ value: ReminderAuthorization) { permission = value }
    func setFailure(_ value: Bool) { fail = value }
    func authorization() -> ReminderAuthorization { permission }
    func requestAuthorization() -> ReminderAuthorization { prompts += 1; return permission }
    func pendingIdentifiers() -> [String] { Array(requests.keys) + ["foreign"] }
    func remove(identifiers: [String]) {
        for id in identifiers { requests.removeValue(forKey: id) }
    }
    func add(_ request: ReminderRequest) throws {
        if fail { throw StorageError.unwritable }
        requests[request.identifier] = request
    }
}

@Suite @MainActor struct ContractReminderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func calendar(_ zone: String = "Asia/Tokyo") throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        return calendar
    }

    private func records() throws -> Records {
        var records = try completeRecords()
        records.rooms[0].contract?.notice = ContractNotice(timing: .date(now.addingTimeInterval(90 * 86_400)),
                                                         advanceDays: 30, reminderEnabled: true)
        return try records.validated()
    }

    @Test(arguments: ["Asia/Tokyo", "America/New_York", "UTC"])
    func advanceAndDeadlineUseLocalNineAcrossTimeZones(zone: String) throws {
        let records = try records()
        let calendar = try calendar(zone)
        let plan = try ReminderPlan(records: records, now: now, calendar: calendar)
        #expect(plan.requests.count == 2)
        #expect(plan.requests.map(\.kind) == [.contractAdvance, .contractDeadline])
        let deadline = try #require(plan.requests.last)
        let advance = try #require(plan.requests.first)
        #expect(deadline.target == .contract(records.rooms[0].id))
        #expect(calendar.component(.hour, from: deadline.fireDate) == 9)
        #expect(calendar.component(.hour, from: advance.fireDate) == 9)
        #expect(calendar.dateComponents([.day], from: advance.fireDate, to: deadline.fireDate).day == 30)
        for request in plan.requests {
            #expect(ReminderRequest.target(for: request.identifier) == request.target)
            #expect(request.components.calendar?.date(from: request.components) == request.fireDate)
        }
    }

    @Test func disabledNoticeAndZeroAdvanceDoNotDuplicateReminders() throws {
        var records = try records()
        records.rooms[0].contract?.notice?.advanceDays = 0
        #expect(try ReminderPlan(records: records, now: now, calendar: calendar()).requests.map(\.kind) == [.contractDeadline])
        records.rooms[0].contract?.notice?.reminderEnabled = false
        #expect(try ReminderPlan(records: records, now: now, calendar: calendar()).requests.isEmpty)
    }

    @Test func calendarDaysPreserveLocalMorningAcrossDaylightSaving() throws {
        var records = try records()
        let calendar = try calendar("America/New_York")
        let deadline = try #require(ISO8601DateFormatter().date(from: "2027-03-15T12:00:00Z"))
        records.rooms[0].contract?.notice = ContractNotice(timing: .date(deadline), advanceDays: 30, reminderEnabled: true)
        let plan = try ReminderPlan(records: records, now: deadline.addingTimeInterval(-90 * 86_400), calendar: calendar)
        let advance = try #require(plan.requests.first)
        let final = try #require(plan.requests.last)
        #expect(calendar.component(.hour, from: advance.fireDate) == 9)
        #expect(calendar.component(.hour, from: final.fireDate) == 9)
        #expect(final.fireDate.timeIntervalSince(advance.fireDate) == 30 * 86_400 - 3_600)
    }

    @Test(arguments: ["America/Los_Angeles", "Pacific/Kiritimati", "Asia/Tokyo"])
    func contractDatesStayInTheRecordedZoneWhenTheDeviceTravels(zone: String) async throws {
        var records = try records()
        let japan = try calendar()
        let device = try calendar(zone)
        let expiry = try #require(ISO8601DateFormatter().date(from: "2028-08-30T15:00:00Z"))
        let expected = try #require(ISO8601DateFormatter().date(from: "2028-02-29T00:00:00Z"))
        records.rooms[0].contract?.end = expiry
        records.rooms[0].contract?.notice = ContractNotice(timing: .monthsBeforeExpiry(6), advanceDays: 0, reminderEnabled: true)
        records.work[0].reminderEnabled = true
        records.work[0].dueDate = expiry
        let plan = try ReminderPlan(records: records, now: now, calendar: device, contractCalendar: japan)
        let contract = try #require(plan.requests.first { $0.kind == .contractDeadline })
        #expect(contract.fireDate == expected)
        let work = try #require(plan.requests.first { $0.kind == .deadline })
        #expect(device.component(.hour, from: work.fireDate) == 9)
        let center = ContractNotificationCenter()
        let now = now
        let coordinator = ReminderCoordinator(center: center, now: { now }, calendar: { device }, contractCalendar: japan)
        _ = await coordinator.synchronize(records)
        #expect(await center.requests[contract.identifier]?.fireDate == expected)
    }

    @Test func pastAdvanceDoesNotDiscardTheFutureDeadline() throws {
        var records = try records()
        records.rooms[0].contract?.notice?.timing = .date(now.addingTimeInterval(2 * 86_400))
        let plan = try ReminderPlan(records: records, now: now, calendar: calendar())
        #expect(plan.requests.map(\.kind) == [.contractDeadline])
        #expect(plan.expiredTargets == [.contract(records.rooms[0].id)])
    }

    @Test func contractAndWorkWithTheSameUUIDRemainDistinct() throws {
        var records = try records()
        records.work[0].id = records.rooms[0].id
        records.history[0].workID = records.work[0].id
        records.attachments[0].workID = records.work[0].id
        records.work[0].dueDate = now.addingTimeInterval(86_400)
        records.work[0].reminderEnabled = true
        let plan = try ReminderPlan(records: records, now: now, calendar: calendar())
        #expect(plan.requests.count == 3)
        #expect(Set(plan.requests.map(\.identifier)).count == 3)
        #expect(Set(plan.requests.map(\.target)) == [.work(records.work[0].id), .contract(records.rooms[0].id)])
        var report = ReminderSyncReport()
        report.deniedTargets = [.contract(records.rooms[0].id)]
        #expect(report.result(for: .work(records.work[0].id)) == .none)
        #expect(report.result(for: .contract(records.rooms[0].id)) == .denied)
    }

    @Test func editsDisablingAndRemovalReplaceAllContractRequests() async throws {
        var records = try records()
        let center = ContractNotificationCenter()
        let now = now
        let calendar = try calendar()
        let coordinator = ReminderCoordinator(center: center, now: { now }, calendar: { calendar })
        _ = await coordinator.synchronize(records)
        #expect(await center.requests.count == 2)
        let original = await center.requests
        records.rooms[0].contract?.notice?.timing = .date(now.addingTimeInterval(120 * 86_400))
        _ = await coordinator.synchronize(records)
        let changed = await center.requests
        #expect(Set(original.keys) == Set(changed.keys))
        #expect(original.values.map(\.fireDate).sorted() != changed.values.map(\.fireDate).sorted())
        records.rooms[0].contract?.notice?.advanceDays = 0
        _ = await coordinator.synchronize(records)
        #expect(await center.requests.values.map(\.kind) == [.contractDeadline])
        records.rooms[0].contract?.notice = nil
        _ = await coordinator.synchronize(records)
        #expect(await center.requests.isEmpty)
    }

    @Test func permissionAndRegistrationFailuresKeepSavedDeadlinesRetryable() async throws {
        let records = try records()
        let target = ReminderTarget.contract(records.rooms[0].id)
        let center = ContractNotificationCenter()
        await center.setPermission(.notDetermined)
        let now = now
        let calendar = try calendar()
        let coordinator = ReminderCoordinator(center: center, now: { now }, calendar: { calendar })
        let passive = await coordinator.synchronize(records)
        #expect(passive.result(for: target) == .denied)
        #expect(passive.authorization == .notDetermined)
        #expect(await center.prompts == 0)
        _ = await coordinator.synchronize(records, requestingAuthorizationFor: target)
        #expect(await center.prompts == 1)
        await center.setPermission(.authorized)
        await center.setFailure(true)
        #expect(await coordinator.synchronize(records).result(for: target) == .failed)
        await center.setFailure(false)
        let recovered = await coordinator.synchronize(records)
        #expect(recovered.result(for: target) == .none)
        #expect(recovered.authorization == .authorized)
        #expect(await center.requests.count == 2)
        #expect(records.rooms[0].contract?.notice?.reminderEnabled == true)
    }
}
