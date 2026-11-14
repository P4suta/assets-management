import PropertyCore
import SwiftUI

struct WorkListView: View {
    @Binding var selection: UUID?
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var query = ""
    @State private var editor: EditorDestination?
    @State private var registration = false
    let onRegister: () -> Void

    private var active: [WorkItem] { store.records.matchingWork(query: query, completed: false) }
    private var completed: [WorkItem] { store.records.matchingWork(query: query, completed: true) }

    var body: some View {
        List(selection: $selection) {
            ReminderReport()
            if active.isEmpty && completed.isEmpty {
                ContentUnavailableView {
                    Label(query.isEmpty ? "対応の記録はありません" : "対応が見つかりません", systemImage: "checklist")
                } description: {
                    Text(query.isEmpty ? "修繕、契約更新、点検を追加できます。" : "物件名、部屋番号、対応内容を変更して検索してください。")
                } actions: {
                    if query.isEmpty { Button("対応を追加") { add() } }
                }
            } else {
                if !active.isEmpty {
                    Section {
                        rows(active)
                    } header: {
                        Text("対応").foregroundStyle(Color.primary).accessibilityIdentifier("work.section.active")
                    }
                }
                if !completed.isEmpty {
                    Section {
                        rows(completed)
                    } header: {
                        Text("対応済み").foregroundStyle(Color.primary).accessibilityIdentifier("work.section.completed")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("work.list")
        .id(notices.reminder)
        .navigationTitle("対応")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "検索")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("対応を追加", systemImage: "plus") { add() }
                    .accessibilityIdentifier("work.add")
            }
        }
        .editorPresentation($editor)
        .alert("物件を登録してください", isPresented: $registration) {
            Button("物件を登録", action: onRegister)
            Button("キャンセル", role: .cancel) {}
        } message: { Text("対応を追加する前に、建物を登録してください。") }
    }

    @ViewBuilder private func rows(_ values: [WorkItem]) -> some View {
        ForEach(values) { item in
            NavigationLink(value: item.id) { WorkRow(item: item, selected: selection == item.id) }
        }
    }

    private func add() {
        if store.records.buildings.isEmpty { registration = true }
        else { editor = .work(nil, nil, nil, .repair) }
    }
}

struct WorkDetailView: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var editor: EditorDestination?
    @State private var failure: String?
    let workID: UUID
    private var item: WorkItem? { store.records.work.first { $0.id == workID } }

    var body: some View {
        List {
            ReminderReport()
            if let item {
                ReminderReservationIssue(target: .work(item.id))
                Section {
                    Text(item.title).font(.title2).bold()
                    Text(store.records.locationText(item)).foregroundStyle(Color.secondary)
                }
                Section("内容") {
                    Picker("状態", selection: Binding(get: { item.status }, set: { setStatus($0) })) {
                        ForEach(WorkStatus.allCases, id: \.self) { status in
                            Label(status.title, systemImage: status.symbol).tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .symbolRenderingMode(.monochrome)
                    .contentAlignedRowSeparator()
                    .accessibilityValue(item.status.title)
                    .accessibilityIdentifier("work.status")
                    LabeledContent("期限", value: item.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "未設定")
                    if let estimate = item.estimate {
                        LabeledContent("見積額", value: yen(estimate))
                    }
                }
                WorkMemosSection(item: item) { editor = .history(item.id, $0) }
                RecordPhotosSection(location: RecordLocation(buildingID: item.buildingID, roomID: item.roomID, workID: item.id))
            } else {
                ContentUnavailableView("記録が見つかりません", systemImage: "exclamationmark.circle")
            }
        }
        .accessibilityIdentifier("work.detail")
        .recordPhotosPresentation(at: item.map { RecordLocation(buildingID: $0.buildingID, roomID: $0.roomID, workID: $0.id) })
        .id(notices.reminder)
        .navigationTitle(item.map { $0.kind.title + "の詳細" } ?? "対応")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let item {
                ToolbarItem(placement: .primaryAction) {
                    Button("編集", systemImage: "square.and.pencil") {
                        editor = .work(item.buildingID, item.roomID, item.id, item.kind)
                    }.accessibilityIdentifier("work.edit")
                }
            }
        }
        .editorPresentation($editor)
        .alert("保存できませんでした", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("閉じる", role: .cancel) {}
        } message: { Text(failure ?? "") }
    }

    private func setStatus(_ status: WorkStatus) {
        Task {
            do {
                try await notices.setStatus(status, for: workID, store: store)
            } catch { failure = errorMessage(error) }
        }
    }
}
