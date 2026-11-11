import PropertyCore
import SwiftUI

struct WorkListView: View {
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var query = ""
    @State private var completed = false
    @State private var editor: EditorDestination?
    @State private var registration = false
    @State private var failure: String?
    let onRegister: () -> Void

    private var items: [WorkItem] { store.records.matchingWork(query: query, completed: completed) }
    private var upcoming: [WorkItem] {
        items.filter { ($0.dueDate ?? .distantFuture) <= Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date() }
    }
    private var later: [WorkItem] {
        let ids = Set(upcoming.map(\.id))
        return items.filter { !ids.contains($0.id) }
    }

    var body: some View {
        List {
            ReminderReport()
            if items.isEmpty {
                ContentUnavailableView {
                    Label(query.isEmpty ? (completed ? "完了した対応はありません" : "対応の記録はありません") : "対応が見つかりません",
                          systemImage: completed ? "checkmark" : "checklist")
                } description: {
                    Text(query.isEmpty ? "修繕、契約更新、点検を追加できます。" : "物件名、部屋番号、対応内容を変更して検索してください。")
                } actions: {
                    if query.isEmpty, !completed { Button("対応を追加") { add() } }
                }
            } else {
                if !upcoming.isEmpty { Section("期限が近い対応") { rows(upcoming) } }
                if !later.isEmpty { Section("今後の対応") { rows(later) } }
            }
            Section {
                Button(completed ? "未完了の対応" : "完了した対応", systemImage: completed ? "checklist" : "checkmark") {
                    completed.toggle()
                }.accessibilityIdentifier("work.completedFilter")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(completed ? "完了した対応" : "対応")
        .navigationBarTitleDisplayMode(textSize.isAccessibilitySize ? .inline : .large)
        .navigationSubtitle(Text(Date(), format: .dateTime.year().month().day()))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "検索")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("対応を追加", systemImage: "plus") { add() }
                    .accessibilityIdentifier("work.add")
            }
        }
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
        .alert("物件を登録してください", isPresented: $registration) {
            Button("物件を登録", action: onRegister)
            Button("キャンセル", role: .cancel) {}
        } message: { Text("対応を追加する前に、建物と部屋を登録してください。") }
        .alert("保存できませんでした", isPresented: hasFailure) {
            Button("閉じる", role: .cancel) {}
        } message: { Text(failure ?? "") }
    }

    private var hasFailure: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    @ViewBuilder private func rows(_ values: [WorkItem]) -> some View {
        ForEach(values) { item in
            NavigationLink { WorkDetailView(workID: item.id) } label: { WorkRow(item: item) }
                .swipeActions {
                    Button(item.status == .completed ? "再開" : "完了", systemImage: "checkmark") { changeStatus(item) }
                    Button("編集", systemImage: "square.and.pencil") {
                        editor = .work(item.buildingID, item.roomID, item.id, item.kind)
                    }
                }
                .contextMenu {
                    Button(item.status == .completed ? "再開" : "完了", systemImage: "checkmark") { changeStatus(item) }
                    Button("編集", systemImage: "square.and.pencil") {
                        editor = .work(item.buildingID, item.roomID, item.id, item.kind)
                    }
                }
        }
    }

    private func add() {
        if store.records.buildings.isEmpty { registration = true }
        else { editor = .work(nil, nil, nil, .repair) }
    }

    private func changeStatus(_ item: WorkItem) {
        Task {
            do {
                notices.reminder = try await ReminderService.setStatus(item.status == .completed ? .inProgress : .completed,
                                                                      for: item.id, store: store)
            } catch { failure = errorMessage(error) }
        }
    }
}

struct WorkDetailView: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var editor: EditorDestination?
    @State private var failure: String?
    @State private var confirmRenewal = false
    let workID: UUID
    private var item: WorkItem? { store.records.work.first { $0.id == workID } }

    var body: some View {
        List {
            ReminderReport()
            if let item {
                Section {
                    Text(item.title).font(.title2).bold()
                    Text(store.records.locationText(item)).foregroundStyle(Color.secondary)
                }
                Section("内容") {
                    Menu {
                        ForEach(WorkStatus.allCases, id: \.self) { status in
                            Button(status.title, systemImage: status.symbol) { setStatus(status) }
                        }
                    } label: {
                        LabeledContent("状態") { StatusLabel(status: item.status) }
                    }
                    .accessibilityLabel("状態")
                    .accessibilityValue(item.status.title)
                    .accessibilityIdentifier("work.status")
                    LabeledContent("期限", value: item.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "未設定")
                    LabeledContent("受付", value: item.receivedAt.formatted(date: .abbreviated, time: .shortened))
                    if !item.notes.isEmpty { Text(item.notes).foregroundStyle(Color.primary) }
                    if item.status != .completed {
                        Button(item.status == .notStarted ? "対応を開始" : "完了にする",
                               systemImage: item.status == .notStarted ? "clock" : "checkmark") {
                            setStatus(item.status == .notStarted ? .inProgress : .completed)
                        }.accessibilityIdentifier("work.advance")
                    }
                }
                related(item)
                if item.kind == .renewal { renewal(item) }
                Section {
                    Button(item.kind.title + "を編集", systemImage: "square.and.pencil") {
                        editor = .work(item.buildingID, item.roomID, item.id, item.kind)
                    }
                }
            } else {
                ContentUnavailableView("記録が見つかりません", systemImage: "exclamationmark.circle")
            }
        }
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
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
        .confirmationDialog("更新契約を確定しますか？", isPresented: $confirmRenewal, titleVisibility: .visible) {
            Button("契約内容を確定") {
                Task {
                    do {
                        try await store.save { try $0.confirmingRenewal(workID) }
                        await ReminderService.cancel(workID)
                    } catch { failure = errorMessage(error) }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("部屋の契約期間と家賃を更新し、対応を完了します。") }
        .alert("保存できませんでした", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("閉じる", role: .cancel) {}
        } message: { Text(failure ?? "") }
    }

    @ViewBuilder private func related(_ item: WorkItem) -> some View {
        Section("関連情報") {
            NavigationLink {
                HistoryView(workID: item.id)
            } label: {
                LabeledContent("連絡履歴", value: "\(store.records.history.filter { $0.workID == item.id }.count)件")
            }
            if let id = item.contractorID {
                NavigationLink { ContactDetailView(contactID: id) } label: {
                    LabeledContent("業者", value: store.records.contacts.first { $0.id == id }?.name ?? "未登録")
                }
            } else {
                Button("業者を登録", systemImage: "person.crop.circle.badge.plus") {
                    editor = .contact(nil, .contractor(item.id))
                }
            }
            NavigationLink {
                DocumentsView(location: RecordLocation(buildingID: item.buildingID, roomID: item.roomID, workID: item.id))
            } label: {
                LabeledContent("写真・書類", value: "\(store.records.attachments.filter { $0.workID == item.id }.count)点")
            }
            LabeledContent("見積額", value: yen(item.estimate))
            Button {
                editor = .schedule(item.id)
            } label: {
                LabeledContent("次の予定", value: item.nextVisit?.formatted(date: .abbreviated, time: .shortened) ?? "未設定")
            }
            .accessibilityLabel("次の予定")
            .accessibilityValue(item.nextVisit?.formatted(date: .abbreviated, time: .shortened) ?? "未設定")
            .accessibilityIdentifier("work.schedule")
        }
    }

    @ViewBuilder private func renewal(_ item: WorkItem) -> some View {
        Section("契約更新") {
            if let room = store.records.rooms.first(where: { $0.id == item.roomID }), let contract = room.contract {
                LabeledContent("現在の開始日", value: contract.start.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("現在の満了日", value: contract.end.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("家賃", value: yen(contract.monthlyRent))
            }
            if let draft = item.renewalDraft {
                LabeledContent("更新後の開始日", value: draft.start.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("更新後の満了日", value: draft.end.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("更新後の家賃", value: yen(draft.monthlyRent))
                if item.status != .completed {
                    Button("更新契約を確定", systemImage: "checkmark.seal") { confirmRenewal = true }
                }
            }
            Button("更新内容と期限を編集", systemImage: "calendar") { editor = .renewal(item.id) }
        }
    }

    private func setStatus(_ status: WorkStatus) {
        Task {
            do {
                notices.reminder = try await ReminderService.setStatus(status, for: workID, store: store)
            } catch { failure = errorMessage(error) }
        }
    }
}

struct HistoryView: View {
    @Environment(RecordsStore.self) private var store
    @State private var editor: EditorDestination?
    let workID: UUID
    private var entries: [HistoryEntry] { store.records.history.filter { $0.workID == workID }.sorted { $0.date > $1.date } }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView("連絡履歴はありません", systemImage: "bubble.left",
                                       description: Text("電話や訪問で確認した内容を記録できます。"))
            }
            ForEach(entries) { entry in
                Button { editor = .history(workID, entry.id) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.text).foregroundStyle(Color.primary)
                        Text(entry.method.title + " · " + entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(Color.secondary)
                        if let id = entry.contactID, let contact = store.records.contacts.first(where: { $0.id == id }) {
                            Text(contact.name).font(.subheadline).foregroundStyle(Color.secondary)
                        }
                    }.padding(.vertical, 4)
                }
                .contextMenu { Button("編集") { editor = .history(workID, entry.id) } }
                .swipeActions { Button("編集") { editor = .history(workID, entry.id) } }
            }
        }
        .navigationTitle("連絡履歴")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("連絡履歴を追加", systemImage: "plus") { editor = .history(workID, nil) }
            }
        }
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
    }
}
