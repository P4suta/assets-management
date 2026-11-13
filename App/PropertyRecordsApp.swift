import PropertyCore
import SwiftUI

@main
struct PropertyRecordsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: RecordsStore
    @State private var notices = AppNotices()

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
                }
                .tabViewStyle(.sidebarAdaptable)
                .sheet(item: $editor) { EditorDestinationView(destination: $0) }
            }
        }
        .onChange(of: store.isLoading) { _, loading in
            if !loading, store.records.buildings.isEmpty { selectedTab = 1 }
        }
    }
}
