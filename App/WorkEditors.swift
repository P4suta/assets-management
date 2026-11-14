import PropertyCore
import SwiftUI

struct WorkEditor: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @Bindable var session: EditorSession<WorkFields>
    let workID: UUID?

    var body: some View {
        EditorSheet(feedback: session.feedback, title: session.value.item.kind.title + (workID == nil ? "を追加" : "を編集"),
                    dirty: session.dirty, canSave: session.value.estimate.isValid, save: save) {
            Section("対象") {
                SelectionField(title: "建物", value: store.records.buildings.first { $0.id == session.value.item.buildingID }?.name ?? "未選択",
                               selection: $session.value.item.buildingID) {
                    ForEach(store.records.buildings) { Text($0.name).tag($0.id) }
                }.accessibilityIdentifier("work.building")
                SelectionField(title: "部屋", value: store.records.rooms.first { $0.id == session.value.item.roomID }.map { $0.number + "号室" } ?? "共用部分",
                               selection: $session.value.item.roomID) {
                    Text("共用部分").tag(UUID?.none).disabled(session.value.item.kind == .renewal)
                    ForEach(store.records.rooms.filter { $0.buildingID == session.value.item.buildingID }) {
                        Text($0.number + "号室").tag(Optional($0.id))
                    }
                }.accessibilityIdentifier("work.room")
            }
            Section("内容") {
                SelectionField(title: "種類", value: session.value.item.kind.title, selection: $session.value.item.kind) {
                    ForEach(WorkKind.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                InputField(title: "対応内容（必須）", text: $session.value.item.title, identifier: "work.title", multiline: true)
                SelectionField(title: "状態", value: session.value.item.status.title, selection: $session.value.item.status) {
                    ForEach(WorkStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                InputField(title: "メモ", text: $session.value.item.notes, identifier: "work.notes", multiline: true)
                AmountField(title: "見積額（円）", input: $session.value.estimate, identifier: "work.estimate")
            }
            Section("期限") {
                Toggle("期限を設定", isOn: Binding(get: { session.value.item.dueDate != nil },
                                             set: { session.value.item.dueDate = $0 ? Date() : nil }))
                if session.value.item.dueDate != nil {
                    DatePicker("期限", selection: Binding(get: { session.value.item.dueDate ?? Date() },
                                                        set: { session.value.item.dueDate = $0 }),
                               displayedComponents: .date).accessibilityIdentifier("work.deadline")
                    Toggle("期限を通知", isOn: $session.value.item.reminderEnabled)
                }
            }
        }
        .onChange(of: session.value.item.buildingID) { _, _ in
            if let id = session.value.item.roomID,
               !store.records.rooms.contains(where: { $0.id == id && $0.buildingID == session.value.item.buildingID }) {
                session.value.item.roomID = nil
            }
        }
        .onChange(of: session.value.item.kind) { _, kind in
            if kind == .renewal, session.value.item.roomID == nil {
                session.value.item.roomID = store.records.rooms.first { $0.buildingID == session.value.item.buildingID }?.id
            }
        }
        .onAppear {
            session.prepare {
                var item = session.value.item
                if let original = store.records.work.first(where: { $0.id == workID }) {
                    item = original
                } else if !store.records.buildings.contains(where: { $0.id == item.buildingID }),
                          let first = store.records.buildings.first {
                    item.buildingID = first.id
                }
                return WorkFields(item)
            }
        }
    }

    private func save() async throws {
        var item = session.value.item
        item.estimate = try session.value.estimate.value()
        if item.kind != .renewal { item.renewalDraft = nil }
        if item.dueDate == nil { item.reminderEnabled = false }
        if item.buildingID != session.baseline.item.buildingID || item.roomID != session.baseline.item.roomID { item.renewalDraft = nil }
        try await store.save { try $0.savingWork(item) }
        await notices.synchronize(store.records, reporting: item.id)
    }
}

struct HistoryEditor: View {
    @Environment(RecordsStore.self) private var store
    @Bindable var session: EditorSession<HistoryEntry>
    let entryID: UUID?

    var body: some View {
        EditorSheet(feedback: session.feedback, title: entryID == nil ? "メモを追加" : "メモを編集", dirty: session.dirty, save: {
            try await store.save { records in
                var records = records
                records.history.upsert(session.value)
                return records
            }
        }) {
            Section {
                InputField(title: "メモ（必須）", text: $session.value.text, identifier: "history.text", multiline: true)
            }
        }
        .onAppear { session.prepare { store.records.history.first { $0.id == entryID } ?? session.value } }
    }
}

struct ScheduleEditor: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @Bindable var session: EditorSession<ScheduleFields>
    let workID: UUID

    var body: some View {
        EditorSheet(feedback: session.feedback, title: "次の予定を編集", dirty: session.dirty, save: {
            guard var item = store.records.work.first(where: { $0.id == workID }) else { throw DomainError.invalidReference }
            let fields = session.value
            item.nextVisit = fields.enabled ? fields.date : nil
            item.visitReminderEnabled = fields.enabled && fields.notify
            try await store.save { records in
                var records = records
                records.work.upsert(item)
                return records
            }
            await notices.synchronize(store.records, reporting: item.id)
        }) {
            Section {
                Toggle("予定を設定", isOn: $session.value.enabled)
                if session.value.enabled { DatePicker("予定日時", selection: $session.value.date).accessibilityIdentifier("schedule.date") }
                Toggle("予定を通知", isOn: $session.value.notify)
            } footer: { Text("通知を許可しなくても、予定は保存できます。").fixedSize(horizontal: false, vertical: true) }
        }
        .onAppear {
            session.prepare {
                guard let item = store.records.work.first(where: { $0.id == workID }) else { return session.value }
                return ScheduleFields(date: item.nextVisit ?? session.value.date, enabled: item.nextVisit != nil,
                                      notify: item.visitReminderEnabled)
            }
        }
    }
}

struct RenewalEditor: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @Bindable var session: EditorSession<RenewalFields>
    let workID: UUID

    var body: some View {
        EditorSheet(feedback: session.feedback, title: "契約更新を編集", dirty: session.dirty, canSave: session.value.rent.isValid, save: {
            guard var item = store.records.work.first(where: { $0.id == workID }), item.roomID != nil else {
                throw DomainError.missingRenewal
            }
            let fields = session.value
            item.renewalDraft = Contract(start: fields.start, end: fields.end, monthlyRent: try fields.rent.value())
            item.dueDate = fields.due
            item.status = .inProgress
            item.reminderEnabled = fields.notify
            try await store.save { records in
                var records = records
                records.work.upsert(item)
                return records
            }
            await notices.synchronize(store.records, reporting: item.id)
        }) {
            Section("更新後の契約（下書き）") {
                DatePicker("契約開始日", selection: $session.value.start, displayedComponents: .date)
                DatePicker("契約満了日", selection: $session.value.end, displayedComponents: .date)
                AmountField(title: "月額家賃（円）", input: $session.value.rent, identifier: "renewal.rent")
            }
            .environment(\.calendar, ContractDates.calendar)
            .environment(\.timeZone, ContractDates.timeZone)
            Section {
                DatePicker("期限", selection: $session.value.due, displayedComponents: .date).accessibilityIdentifier("renewal.deadline")
                Toggle("期限を通知", isOn: $session.value.notify)
            } header: { Text("対応の期限") }
              footer: { Text("下書きを保存しても、現在の契約期間は変わりません。締結後に契約内容を確定してください。") }
        }
        .onAppear {
            session.prepare {
                guard let item = store.records.work.first(where: { $0.id == workID }) else { return session.value }
                let contract = item.renewalDraft ?? store.records.rooms.first { $0.id == item.roomID }?.contract
                let start: Date
                let end: Date
                if let draft = item.renewalDraft {
                    start = draft.start
                    end = draft.end
                } else {
                    start = ContractDates.calendar.date(byAdding: .day, value: 1, to: contract?.end ?? Date()) ?? Date()
                    end = ContractDates.calendar.date(byAdding: .year, value: 2, to: start) ?? start
                }
                return RenewalFields(start: start, end: end, due: item.dueDate ?? Date(),
                                     rent: AmountInput(contract?.monthlyRent.map(String.init) ?? ""), notify: item.reminderEnabled)
            }
        }
    }
}
