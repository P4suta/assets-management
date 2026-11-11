import Observation
import PropertyCore
import SwiftUI
import UserNotifications

enum ReminderResult: Equatable {
    case none, denied, pastDate, failed
}

@MainActor @Observable
final class AppNotices {
    var reminder: ReminderResult = .none
}

@MainActor
enum ReminderService {
    static func setStatus(_ status: WorkStatus, for id: UUID, store: RecordsStore) async throws -> ReminderResult {
        try await store.save { try $0.settingStatus(status, for: id) }
        guard let item = store.records.work.first(where: { $0.id == id }) else { return .none }
        return await schedule(item)
    }

    static func cancel(_ id: UUID) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers(id))
    }

    static func schedule(_ item: WorkItem) async -> ReminderResult {
        let center = UNUserNotificationCenter.current()
        await cancel(item.id)
        guard item.status != .completed, item.reminderEnabled || item.visitReminderEnabled else { return .none }
        do {
            var settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
                settings = await center.notificationSettings()
            }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return .denied }
            var dates: [(String, Date)] = []
            if item.reminderEnabled, let due = item.dueDate,
               let date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: due) {
                dates.append((identifiers(item.id)[0], date))
            }
            if item.visitReminderEnabled, let visit = item.nextVisit { dates.append((identifiers(item.id)[1], visit)) }
            let future = dates.filter { $0.1 > Date() }
            for (identifier, date) in future {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = identifier.hasSuffix(".visit") ? "予定の時刻です。" : "対応の期限です。"
                content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            }
            return future.count == dates.count ? .none : .pastDate
        } catch { return .failed }
    }

    private static func identifiers(_ id: UUID) -> [String] {
        [id.uuidString + ".deadline", id.uuidString + ".visit"]
    }
}

struct ReminderReport: View {
    @Environment(AppNotices.self) private var notices
    @Environment(\.openURL) private var openURL

    var body: some View {
        if notices.reminder != .none {
            Section("通知") {
                Text(message).foregroundStyle(Color.secondary)
                if notices.reminder == .denied {
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
                Button("閉じる") { notices.reminder = .none }
            }
        }
    }

    private var message: String {
        switch notices.reminder {
        case .none: ""
        case .denied: "記録は保存できましたが、通知は許可されていません。設定で通知を許可した後、期限や予定を保存し直してください。"
        case .pastDate: "過去の日時には通知を予約できません。記録は保存済みです。通知する場合は期限や予定の日時を変更してください。"
        case .failed: "記録は保存できましたが、通知を予約できませんでした。期限や予定の編集から保存し直してください。"
        }
    }
}
