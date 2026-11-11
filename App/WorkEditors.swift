import PropertyCore
import SwiftUI

struct WorkEditor: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var draft: WorkItem
    @State private var baseline: WorkItem
    @State private var estimate = ""
    @State private var baselineEstimate = ""
    @State private var prepared = false
    let workID: UUID?
    private var dirty: Bool { draft != baseline || estimate != baselineEstimate }

    init(buildingID: UUID?, roomID: UUID?, workID: UUID?, kind: WorkKind) {
        self.workID = workID
        let item = WorkItem(id: workID ?? UUID(), buildingID: buildingID ?? UUID(), roomID: roomID, kind: kind, title: "")
        _draft = State(initialValue: item)
        _baseline = State(initialValue: item)
    }

    var body: some View {
        EditorSheet(title: draft.kind.title + (workID == nil ? "を追加" : "を編集"), dirty: dirty, save: save) {
            Section("対象") {
                Picker("建物", selection: $draft.buildingID) {
                    ForEach(store.records.buildings) { Text($0.name).tag($0.id) }
                }.accessibilityIdentifier("work.building")
                Picker("部屋", selection: $draft.roomID) {
                    Text("共用部分").tag(UUID?.none).disabled(draft.kind == .renewal)
                    ForEach(store.records.rooms.filter { $0.buildingID == draft.buildingID }) {
                        Text($0.number + "号室").tag(Optional($0.id))
                    }
                }.accessibilityIdentifier("work.room")
            }
            Section("内容") {
                Picker("種類", selection: $draft.kind) {
                    ForEach(WorkKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                InputField(title: "対応内容（必須）", text: $draft.title, identifier: "work.title", multiline: true)
                DatePicker("受付", selection: $draft.receivedAt)
                Picker("状態", selection: $draft.status) {
                    ForEach(WorkStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                InputField(title: "詳細", text: $draft.notes, identifier: "work.notes", multiline: true)
                Picker("業者", selection: $draft.contractorID) {
                    Text("未登録").tag(UUID?.none)
                    ForEach(store.records.contacts) { Text($0.name).tag(Optional($0.id)) }
                }
                InputField(title: "見積額（円）", text: $estimate, identifier: "work.estimate").keyboardType(.numberPad)
            }
            Section("期限") {
                Toggle("期限を設定", isOn: Binding(get: { draft.dueDate != nil }, set: { draft.dueDate = $0 ? Date() : nil }))
                if draft.dueDate != nil {
                    DatePicker("期限", selection: Binding(get: { draft.dueDate ?? Date() }, set: { draft.dueDate = $0 }),
                               displayedComponents: .date).accessibilityIdentifier("work.deadline")
                    Toggle("期限を通知", isOn: $draft.reminderEnabled)
                }
            }
        }
        .onChange(of: draft.buildingID) { _, _ in
            if let id = draft.roomID, !store.records.rooms.contains(where: { $0.id == id && $0.buildingID == draft.buildingID }) {
                draft.roomID = nil
            }
        }
        .onChange(of: draft.kind) { _, kind in
            if kind == .renewal, draft.roomID == nil {
                draft.roomID = store.records.rooms.first { $0.buildingID == draft.buildingID }?.id
            }
        }
        .onAppear {
            guard !prepared else { return }
            if let original = store.records.work.first(where: { $0.id == workID }) {
                draft = original
            } else if !store.records.buildings.contains(where: { $0.id == draft.buildingID }),
                      let first = store.records.buildings.first {
                draft.buildingID = first.id
            }
            estimate = draft.estimate.map(String.init) ?? ""
            baseline = draft
            baselineEstimate = estimate
            prepared = true
        }
    }

    private func save() async throws {
        var item = draft
        item.estimate = try amountValue(estimate)
        if item.kind != .renewal { item.renewalDraft = nil }
        if item.dueDate == nil { item.reminderEnabled = false }
        if item.buildingID != baseline.buildingID || item.roomID != baseline.roomID { item.renewalDraft = nil }
        try await store.save { try $0.savingWork(item) }
        notices.reminder = await ReminderService.schedule(item)
    }
}

struct HistoryEditor: View {
    @Environment(RecordsStore.self) private var store
    @State private var draft: HistoryEntry
    @State private var baseline: HistoryEntry
    @State private var prepared = false
    let entryID: UUID?

    init(workID: UUID, entryID: UUID?) {
        self.entryID = entryID
        let entry = HistoryEntry(id: entryID ?? UUID(), workID: workID, text: "")
        _draft = State(initialValue: entry)
        _baseline = State(initialValue: entry)
    }

    var body: some View {
        EditorSheet(title: entryID == nil ? "連絡履歴を追加" : "連絡履歴を編集", dirty: draft != baseline, save: {
            try await store.save { records in
                var records = records
                records.history.upsert(draft)
                return records
            }
        }) {
            Section {
                DatePicker("連絡日時", selection: $draft.date)
                Picker("連絡方法", selection: $draft.method) {
                    ForEach(CommunicationMethod.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("相手", selection: $draft.contactID) {
                    Text("未指定").tag(UUID?.none)
                    ForEach(store.records.contacts) { Text($0.name).tag(Optional($0.id)) }
                }
                InputField(title: "連絡内容（必須）", text: $draft.text, identifier: "history.text", multiline: true)
            }
        }
        .onAppear {
            guard !prepared else { return }
            if let original = store.records.history.first(where: { $0.id == entryID }) { draft = original }
            baseline = draft
            prepared = true
        }
    }
}

struct ScheduleEditor: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var date = Date()
    @State private var enabled = true
    @State private var notify = false
    @State private var baselineDate = Date()
    @State private var baselineEnabled = true
    @State private var baselineNotify = false
    @State private var prepared = false
    let workID: UUID

    var body: some View {
        EditorSheet(title: "次の予定を編集", dirty: date != baselineDate || enabled != baselineEnabled || notify != baselineNotify, save: {
            guard var item = store.records.work.first(where: { $0.id == workID }) else { throw DomainError.invalidReference }
            item.nextVisit = enabled ? date : nil
            item.visitReminderEnabled = enabled && notify
            try await store.save { records in
                var records = records
                records.work.upsert(item)
                return records
            }
            notices.reminder = await ReminderService.schedule(item)
        }) {
            Section {
                Toggle("予定を設定", isOn: $enabled)
                if enabled { DatePicker("予定日時", selection: $date).accessibilityIdentifier("schedule.date") }
                Toggle("予定を通知", isOn: $notify)
            } footer: { Text("通知を許可しなくても、予定は保存できます。").fixedSize(horizontal: false, vertical: true) }
        }
        .onAppear {
            guard !prepared else { return }
            if let item = store.records.work.first(where: { $0.id == workID }) {
                date = item.nextVisit ?? Date()
                enabled = item.nextVisit != nil
                notify = item.visitReminderEnabled
            }
            baselineDate = date
            baselineEnabled = enabled
            baselineNotify = notify
            prepared = true
        }
    }
}

struct RenewalEditor: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var start = Date()
    @State private var end = Date()
    @State private var due = Date()
    @State private var rent = ""
    @State private var notify = false
    @State private var baseline = ""
    @State private var prepared = false
    let workID: UUID
    private var signature: String { "\(start.timeIntervalSince1970)|\(end.timeIntervalSince1970)|\(due.timeIntervalSince1970)|\(rent)|\(notify)" }

    var body: some View {
        EditorSheet(title: "契約更新を編集", dirty: prepared && signature != baseline, save: {
            guard var item = store.records.work.first(where: { $0.id == workID }), item.roomID != nil else {
                throw DomainError.missingRenewal
            }
            item.renewalDraft = Contract(start: start, end: end, monthlyRent: try amountValue(rent))
            item.dueDate = due
            item.status = .inProgress
            item.reminderEnabled = notify
            try await store.save { records in
                var records = records
                records.work.upsert(item)
                return records
            }
            notices.reminder = await ReminderService.schedule(item)
        }) {
            Section("更新後の契約（下書き）") {
                DatePicker("契約開始日", selection: $start, displayedComponents: .date)
                DatePicker("契約満了日", selection: $end, displayedComponents: .date)
                InputField(title: "月額家賃（円）", text: $rent, identifier: "renewal.rent").keyboardType(.numberPad)
            }
            Section {
                DatePicker("期限", selection: $due, displayedComponents: .date).accessibilityIdentifier("renewal.deadline")
                Toggle("期限を通知", isOn: $notify)
            } header: { Text("対応の期限") }
              footer: { Text("下書きを保存しても、現在の契約期間は変わりません。締結後に契約内容を確定してください。") }
        }
        .onAppear {
            guard !prepared, let item = store.records.work.first(where: { $0.id == workID }) else { return }
            let contract = item.renewalDraft ?? store.records.rooms.first { $0.id == item.roomID }?.contract
            if let draft = item.renewalDraft {
                start = draft.start
                end = draft.end
            } else {
                start = Calendar.current.date(byAdding: .day, value: 1, to: contract?.end ?? Date()) ?? Date()
                end = Calendar.current.date(byAdding: .year, value: 2, to: start) ?? start
            }
            rent = contract?.monthlyRent.map(String.init) ?? ""
            due = item.dueDate ?? Date()
            notify = item.reminderEnabled
            baseline = signature
            prepared = true
        }
    }
}
