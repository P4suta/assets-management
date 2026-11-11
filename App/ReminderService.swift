import Observation
import PropertyCore
import SwiftUI
import UserNotifications

@MainActor @Observable
final class AppNotices {
    var reminder: ReminderResult = .none
    private var reportedWorkID: UUID?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private let coordinator: ReminderCoordinator

    init(center: any ReminderNotificationCenter = SystemReminderCenter()) {
        coordinator = ReminderCoordinator(center: center)
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
        generation &+= 1
        let current = generation
        if let id { reportedWorkID = id }
        let report = await coordinator.synchronize(records, requestingAuthorizationFor: id)
        guard current == generation, let reportedWorkID else { return }
        reminder = report.result(for: reportedWorkID)
    }

    func retry(_ records: Records) async {
        await synchronize(records, reporting: reportedWorkID)
    }

    func dismissReminder() {
        generation &+= 1
        reportedWorkID = nil
        reminder = .none
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
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.kind == .visit ? "予定の時刻です。" : "対応の期限です。"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: request.components, repeats: false)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: request.identifier,
                                                                            content: content, trigger: trigger))
    }
}

struct ReminderReport: View {
    @Environment(AppNotices.self) private var notices
    @Environment(RecordsStore.self) private var store

    var body: some View {
        if notices.reminder != .none {
            Section("通知") {
                Text(message).font(.body).foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if notices.reminder == .denied {
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            Task { await UIApplication.shared.open(url) }
                        }
                    }
                }
                if notices.reminder == .failed {
                    Button("通知を再試行", systemImage: "arrow.clockwise") {
                        Task { await notices.retry(store.records) }
                    }
                }
                Button("閉じる") { notices.dismissReminder() }
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
