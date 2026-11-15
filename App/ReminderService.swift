import Observation
import PropertyCore
import SwiftUI
import UserNotifications

@MainActor @Observable
final class AppNotices {
    var reminder: ReminderResult = .none
    private(set) var synchronization: ReminderSyncReport?
    private var reportedTarget: ReminderTarget?
    var openedReminder: OpenedReminder?
    private var reminderIsPresented = false
    private var pendingTarget: ReminderTarget?
    private var editors: Set<UUID> = []
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private let coordinator: ReminderCoordinator

    init(center: any ReminderNotificationCenter = SystemReminderCenter()) {
        coordinator = ReminderCoordinator(center: center, contractCalendar: ContractDates.calendar)
    }

    func sceneChanged(to phase: ScenePhase, store: RecordsStore) async {
        guard phase == .active, !store.isLoading, store.loadError == nil else { return }
        await synchronize(store.records)
    }

    func setStatus(_ status: WorkStatus, for id: UUID, store: RecordsStore) async throws {
        try await store.save { try $0.settingStatus(status, for: id) }
        await synchronize(store.records, reporting: id)
    }

    func synchronize(_ records: Records, reporting id: UUID? = nil) async {
        await synchronize(records, reporting: id.map(ReminderTarget.work))
    }

    func synchronize(_ records: Records, reporting target: ReminderTarget?) async {
        generation &+= 1
        let current = generation
        if let target { reportedTarget = target }
        let report = await coordinator.synchronize(records, requestingAuthorizationFor: target)
        guard !report.isSuperseded else { return }
        synchronization = report
        guard current == generation, let reportedTarget else { return }
        reminder = report.result(for: reportedTarget)
    }

    func retry(_ records: Records) async {
        await synchronize(records, reporting: reportedTarget)
    }

    func dismissReminder() {
        generation &+= 1
        reportedTarget = nil
        reminder = .none
    }

    func receiveReminder(identifier: String, action: String) {
        guard action == UNNotificationDefaultActionIdentifier,
              let target = ReminderRequest.target(for: identifier) else { return }
        pendingTarget = target
        presentPendingReminder()
    }

    func beginEditing(_ id: UUID) { editors.insert(id) }

    func endEditing(_ id: UUID) {
        editors.remove(id)
        presentPendingReminder()
    }

    func reminderClosed() {
        openedReminder = nil
        reminderIsPresented = false
        presentPendingReminder()
    }

    private func presentPendingReminder() {
        guard editors.isEmpty, !reminderIsPresented, let pendingTarget else { return }
        reminderIsPresented = true
        openedReminder = OpenedReminder(target: pendingTarget)
        self.pendingTarget = nil
    }
}

struct ReminderReservationIssue: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppNotices.self) private var notices
    @Environment(RecordsStore.self) private var store
    let target: ReminderTarget

    private var result: ReminderResult { notices.synchronization?.result(for: target) ?? .none }

    var body: some View {
        if result == .denied && notices.reminder != .denied {
            Section("通知の状態") {
                LabeledContent("通知の許可", value: "未許可")
                if notices.synchronization?.authorization == .notDetermined {
                    Button("通知を許可する", systemImage: "bell") {
                        Task { await notices.synchronize(store.records, reporting: target) }
                    }
                } else {
                    Button("通知設定を開く", systemImage: "gearshape") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                }
            }
        } else if result == .failed && notices.reminder != .failed {
            Section("通知の状態") {
                Text("通知の予約に失敗しました。")
                Button("通知を再試行", systemImage: "arrow.clockwise") {
                    Task { await notices.retry(store.records) }
                }
            }
        }
    }
}

struct OpenedReminder: Identifiable {
    let id = UUID()
    let target: ReminderTarget
}

final class ReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    let notices: AppNotices

    init(notices: AppNotices) { self.notices = notices }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier
        let action = response.actionIdentifier
        await notices.receiveReminder(identifier: identifier, action: action)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                           willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        ReminderRequest.owns(notification.request.identifier) ? [.banner, .sound] : []
    }
}

struct SystemReminderCenter: ReminderNotificationCenter {
    func authorization() async -> ReminderAuthorization {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .authorized
        case .notDetermined: .notDetermined
        case .denied: .denied
        @unknown default: .denied
        }
    }

    func requestAuthorization() async throws -> ReminderAuthorization {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        return await authorization()
    }

    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func remove(identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ request: ReminderRequest) async throws {
        let content = Self.content(for: request.kind)
        let trigger = UNCalendarNotificationTrigger(dateMatching: request.components, repeats: false)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: request.identifier,
                                                                            content: content, trigger: trigger))
    }

    static func content(for kind: ReminderRequest.Kind) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        switch kind {
        case .deadline:
            content.title = "対応の期限"
            content.body = "記録した対応の期限です。内容を確認してください。"
        case .visit:
            content.title = "対応の予定"
            content.body = "記録した予定の時刻です。内容を確認してください。"
        case .contractAdvance:
            content.title = "契約の予告期限"
            content.body = "予告期限が近づいています。契約内容と必要な手続きを確認してください。"
        case .contractDeadline:
            content.title = "契約の予告期限"
            content.body = "記録した予告期限です。必要な手続きを確認してください。"
        }
        content.sound = .default
        return content
    }
}

struct ReminderReport: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppNotices.self) private var notices
    @Environment(RecordsStore.self) private var store

    var body: some View {
        if notices.reminder != .none {
            Section("通知") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(message).font(.body).foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if notices.reminder == .denied {
                        Button("設定を開く", systemImage: "gearshape") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    if notices.reminder == .failed {
                        Button("通知を再試行", systemImage: "arrow.clockwise") {
                            Task { await notices.retry(store.records) }
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                    Button("閉じる", systemImage: "xmark") { notices.dismissReminder() }
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var message: String {
        switch notices.reminder {
        case .none: ""
        case .denied: "通知は許可されていません。記録は保存済みです。"
        case .pastDate: "過去の日時には通知を予約できません。記録は保存済みです。通知する場合は期限や予定の日時を変更してください。"
        case .failed: "記録は保存できましたが、通知を予約できませんでした。通知を再試行してください。"
        }
    }
}
