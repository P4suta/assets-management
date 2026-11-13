import PropertyCore
import SwiftUI
import UserNotifications

@main
struct PropertyRecordsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: RecordsStore
    @State private var notices = AppNotices()
    private let reminderDelegate: ReminderDelegate

    init() {
        _store = State(initialValue: RecordsStore(repository: RepositoryFactory.make()))
        let notices = AppNotices()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           ProcessInfo.processInfo.environment["UITEST_NOTICE"] == "denied" {
            notices.reminder = .denied
        }
        #endif
        _notices = State(initialValue: notices)
        reminderDelegate = ReminderDelegate(notices: notices)
        UNUserNotificationCenter.current().delegate = reminderDelegate
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .confirmExternalNavigation()
                .environment(store)
                .environment(notices)
                .tint(Color("AccentColor"))
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .task { await store.load() }
                .onChange(of: store.isLoading) { _, loading in
                    if !loading {
                        Task { await notices.sceneChanged(to: scenePhase, store: store) }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    Task { await notices.sceneChanged(to: phase, store: store) }
                }
        }
    }
}

private struct RootView: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var selectedTab = 0
    @State private var editor: EditorDestination?

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("記録を読み込み中")
            } else if let error = store.loadError {
                ContentUnavailableView {
                    Label("記録を読み込めませんでした", systemImage: "exclamationmark.triangle")
                } description: { Text(errorMessage(error)) } actions: {
                    Button("再試行") { Task { await store.load() } }
                }
            } else {
                TabView(selection: $selectedTab) {
                    Tab("対応", systemImage: "checklist", value: 0) {
                        WorkNavigationView {
                            selectedTab = 1
                            editor = .registration
                        }
                    }
                    Tab("物件", systemImage: "building.2.fill", value: 1) {
                        BuildingNavigationView()
                    }
                    Tab("連絡先", systemImage: "person.crop.rectangle.stack.fill", value: 2) {
                        ContactNavigationView()
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                .editorPresentation($editor)
                .sheet(item: Binding(get: { notices.openedReminder }, set: { notices.openedReminder = $0 }),
                       onDismiss: { notices.reminderClosed() }) { reminder in
                    ReminderDestinationView(target: reminder.target)
                }
            }
        }
        .onChange(of: store.isLoading) { _, loading in
            if !loading, store.records.buildings.isEmpty { selectedTab = 1 }
        }
    }
}

private struct ReminderDestinationView: View {
    @Environment(RecordsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: ReminderTarget

    var body: some View {
        NavigationStack {
            Group {
                switch target {
                case .work(let id):
                    if store.records.work.contains(where: { $0.id == id }) {
                        WorkDetailView(workID: id)
                    } else { missingRecord }
                case .contract(let id):
                    if store.records.rooms.contains(where: { $0.id == id && $0.contract != nil }) {
                        ContractDetailView(roomID: id)
                    } else { missingRecord }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
        .confirmExternalNavigation()
    }

    private var missingRecord: some View {
        ContentUnavailableView("通知の記録が見つかりません", systemImage: "bell.slash",
                               description: Text("記録が削除されたか、契約内容が変更されています。"))
    }
}
