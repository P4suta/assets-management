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
        await notices.synchronize(original, reporting: original.work[0].id)
        #expect(notices.reminder == .denied)
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
}
