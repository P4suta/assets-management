import PropertyCore
import SwiftUI

@main
struct PropertyRecordsApp: App {
    @State private var store: RecordsStore
    @State private var notices = AppNotices()

    init() {
        _store = State(initialValue: RecordsStore(repository: RepositoryFactory.make()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(notices)
                .tint(Color("AccentColor"))
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .task { await store.load() }
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
                        NavigationStack {
                            WorkListView {
                                selectedTab = 1
                                editor = .registration
                            }
                        }
                    }
                    Tab("物件", systemImage: "building.2.fill", value: 1) {
                        NavigationStack { BuildingListView() }
                    }
                }
                .sheet(item: $editor) { EditorDestinationView(destination: $0) }
            }
        }
        .onChange(of: store.isLoading) { _, loading in
            if !loading, store.records.buildings.isEmpty { selectedTab = 1 }
        }
    }
}
