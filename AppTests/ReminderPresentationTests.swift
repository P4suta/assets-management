import Foundation
import PropertyCore
import SwiftUI
import Testing
import UserNotifications
@testable import PropertyRecords

private actor PresentationNotificationCenter: ReminderNotificationCenter {
    var permission: ReminderAuthorization = .denied
    private(set) var permissionRequests = 0
    private(set) var lookups = 0
    private(set) var requests: [String: ReminderRequest] = [:]

    func authorization() -> ReminderAuthorization { permission }
    func setPermission(_ value: ReminderAuthorization) { permission = value }
    func requestAuthorization() -> ReminderAuthorization {
        permissionRequests += 1
        return permission
    }
    func pendingIdentifiers() -> [String] {
        lookups += 1
        return Array(requests.keys)
    }
    func remove(identifiers: [String]) {
        for identifier in identifiers { requests.removeValue(forKey: identifier) }
    }
    func add(_ request: ReminderRequest) { requests[request.identifier] = request }
}

@Suite @MainActor struct ReminderPresentationTests {
    private func records() throws -> Records {
        var records = try Records().registering(RegistrationDraft(name: "検査用の建物", roomNumber: "101"))
        records.work = [WorkItem(buildingID: records.buildings[0].id, roomID: records.rooms[0].id,
                                 title: "修繕の予定", nextVisit: Date().addingTimeInterval(86_400), visitReminderEnabled: true)]
        return try records.validated()
    }

    @Test func returningFromSettingsRestoresRemindersWithoutAnotherRecordWrite() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let original = try records()
        try await repository.save(original)
        let store = RecordsStore(repository: repository)
        await store.load()
        let center = PresentationNotificationCenter()
        let notices = AppNotices(center: center)
        let snapshot = directory.appendingPathComponent("records.json")
        let bytes = try Data(contentsOf: snapshot)
        await notices.synchronize(store.records, reporting: original.work[0].id)
        #expect(notices.reminder == .denied)
        await center.setPermission(.authorized)
        await notices.sceneChanged(to: .active, store: store)
        #expect(notices.reminder == .none)
        #expect(await center.requests.count == 1)
        #expect(store.records == original)
        #expect(try Data(contentsOf: snapshot) == bytes)
        #expect(await center.permissionRequests == 0)
    }

    @Test func foregroundChecksWaitForLoadedRecordsAndNeverPrompt() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let store = RecordsStore(repository: repository)
        let center = PresentationNotificationCenter()
        await center.setPermission(.notDetermined)
        let notices = AppNotices(center: center)
        await notices.sceneChanged(to: .active, store: store)
        #expect(await center.lookups == 0)
        try await repository.save(records())
        await store.load()
        await notices.sceneChanged(to: .background, store: store)
        await notices.sceneChanged(to: .inactive, store: store)
        #expect(await center.lookups == 0)
        await notices.sceneChanged(to: .active, store: store)
        #expect(await center.lookups == 1)
        #expect(await center.permissionRequests == 0)
        #expect(await center.requests.isEmpty)
    }

    @Test func failedLoadsLeaveExistingNotificationRequestsAlone() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("invalid snapshot".utf8).write(to: directory.appendingPathComponent("records.json"))
        let store = RecordsStore(repository: FileRecordsRepository(directory: directory))
        await store.load()
        let center = PresentationNotificationCenter()
        let notices = AppNotices(center: center)
        await notices.sceneChanged(to: .active, store: store)
        #expect(store.loadError != nil)
        #expect(await center.lookups == 0)
    }

    @Test func dismissedReportsStayClosedDuringPassiveRecovery() async throws {
        let original = try records()
        let center = PresentationNotificationCenter()
        let notices = AppNotices(center: center)
        await notices.synchronize(original, reporting: original.work[0].id)
        #expect(notices.reminder == .denied)
        notices.dismissReminder()
        await notices.synchronize(original)
        #expect(notices.reminder == .none)
        #expect(notices.synchronization?.result(for: original.work[0].id) == .denied)
        await notices.synchronize(original, reporting: original.work[0].id)
        #expect(notices.reminder == .denied)
    }

    @Test func passiveStartupRetainsContractPermissionIssuesWithoutOpeningABanner() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        var records = try records()
        let end = Date().addingTimeInterval(90 * 86_400)
        records.rooms[0].contract = Contract(start: Date(), end: end,
                                           notice: ContractNotice(timing: .date(end), reminderEnabled: true))
        try await repository.save(records)
        let store = RecordsStore(repository: repository)
        await store.load()
        let notices = AppNotices(center: PresentationNotificationCenter())
        await notices.sceneChanged(to: .active, store: store)
        #expect(notices.reminder == .none)
        #expect(notices.synchronization?.result(for: .contract(records.rooms[0].id)) == .denied)
        notices.dismissReminder()
        #expect(notices.synchronization?.result(for: .contract(records.rooms[0].id)) == .denied)
    }

    @Test(arguments: ["Asia/Tokyo", "America/New_York", "UTC"])
    func nativeTriggerPreservesThePlannedAbsoluteDate(zone: String) throws {
        let date = Date().addingTimeInterval(86_400)
        let expected = Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60)
        var records = try records()
        records.work[0].nextVisit = date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        let plan = try ReminderPlan(records: records, now: Date(), calendar: calendar)
        let request = try #require(plan.requests.first)
        let trigger = UNCalendarNotificationTrigger(dateMatching: request.components, repeats: false)
        #expect(trigger.nextTriggerDate() == expected)
        #expect(!trigger.repeats)
    }

    @Test func contractPresentationAndSchedulingUseTheSameJapanDate() async throws {
        var records = try records()
        let expiry = try #require(ISO8601DateFormatter().date(from: "2038-08-30T15:00:00Z"))
        let expected = try #require(ISO8601DateFormatter().date(from: "2038-02-28T00:00:00Z"))
        records.rooms[0].contract = Contract(start: Date(), end: expiry,
                                           notice: ContractNotice(timing: .monthsBeforeExpiry(6), advanceDays: 0, reminderEnabled: true))
        let center = PresentationNotificationCenter()
        await center.setPermission(.authorized)
        let notices = AppNotices(center: center)
        await notices.synchronize(records)
        let request = try #require(await center.requests.values.first { $0.kind == .contractDeadline })
        #expect(request.fireDate == expected)
        #expect(ContractDates.format.format(request.fireDate) == "2038年2月28日")
        #expect(ContractDates.calendar.component(.hour, from: request.fireDate) == 9)
        #expect(ContractDates.format.timeZone == ContractDates.timeZone)
    }

    @Test func selectingAContractNotificationWaitsForEveryEditorToClose() {
        let notices = AppNotices(center: PresentationNotificationCenter())
        let roomID = UUID()
        let first = UUID()
        let second = UUID()
        notices.beginEditing(first)
        notices.beginEditing(second)
        notices.receiveReminder(identifier: roomID.uuidString + ".contractAdvance", action: UNNotificationDefaultActionIdentifier)
        #expect(notices.openedReminder == nil)
        notices.endEditing(first)
        #expect(notices.openedReminder == nil)
        notices.endEditing(second)
        #expect(notices.openedReminder?.target == .contract(roomID))
    }

    @Test func notificationDismissalAndForeignIdentifiersDoNotNavigate() {
        let notices = AppNotices(center: PresentationNotificationCenter())
        notices.receiveReminder(identifier: UUID().uuidString + ".deadline", action: UNNotificationDismissActionIdentifier)
        #expect(notices.openedReminder == nil)
        notices.receiveReminder(identifier: "foreign", action: UNNotificationDefaultActionIdentifier)
        #expect(notices.openedReminder == nil)
    }

    @Test func anotherNotificationWaitsUntilThePresentedRecordCloses() {
        let notices = AppNotices(center: PresentationNotificationCenter())
        let workID = UUID()
        let roomID = UUID()
        notices.receiveReminder(identifier: workID.uuidString + ".visit", action: UNNotificationDefaultActionIdentifier)
        #expect(notices.openedReminder?.target == .work(workID))
        notices.receiveReminder(identifier: roomID.uuidString + ".contractDeadline", action: UNNotificationDefaultActionIdentifier)
        #expect(notices.openedReminder?.target == .work(workID))
        notices.reminderClosed()
        #expect(notices.openedReminder?.target == .contract(roomID))
        notices.reminderClosed()
        #expect(notices.openedReminder == nil)
    }

    @Test func anotherNotificationWaitsForTheDismissalAnimationToFinish() {
        let notices = AppNotices(center: PresentationNotificationCenter())
        let first = UUID()
        let second = UUID()
        notices.receiveReminder(identifier: first.uuidString + ".deadline", action: UNNotificationDefaultActionIdentifier)
        #expect(notices.openedReminder?.target == .work(first))
        notices.openedReminder = nil
        notices.receiveReminder(identifier: second.uuidString + ".contractDeadline", action: UNNotificationDefaultActionIdentifier)
        #expect(notices.openedReminder == nil)
        notices.reminderClosed()
        #expect(notices.openedReminder?.target == .contract(second))
    }

    @Test(arguments: ReminderRequest.Kind.allCases)
    func systemNotificationsContainNoRecordNamesOrContactInformation(kind: ReminderRequest.Kind) {
        let content = SystemReminderCenter.content(for: kind)
        #expect(!content.title.isEmpty)
        #expect(!content.body.isEmpty)
        #expect(content.userInfo.isEmpty)
        #expect(content.attachments.isEmpty)
        #expect(content.sound != nil)
        #expect(content.title.contains("対応") || content.title.contains("契約"))
    }

    @Test func contractPermissionRecoveryRetainsTheExactSnapshot() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        var original = try records()
        let date = Date().addingTimeInterval(90 * 86_400)
        original.rooms[0].contract = Contract(start: Date(), end: date,
                                            notice: ContractNotice(timing: .date(date), reminderEnabled: true))
        try await repository.save(original)
        let store = RecordsStore(repository: repository)
        await store.load()
        let bytes = try Data(contentsOf: directory.appendingPathComponent("records.json"))
        let center = PresentationNotificationCenter()
        let notices = AppNotices(center: center)
        await notices.synchronize(store.records, reporting: .contract(original.rooms[0].id))
        #expect(notices.reminder == .denied)
        await center.setPermission(.authorized)
        await notices.sceneChanged(to: .active, store: store)
        #expect(notices.reminder == .none)
        #expect(await center.requests.values.filter { $0.target == .contract(original.rooms[0].id) }.count == 2)
        #expect(store.records == original)
        #expect(try Data(contentsOf: directory.appendingPathComponent("records.json")) == bytes)
    }
}
