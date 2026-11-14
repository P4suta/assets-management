import PropertyCore
import SwiftUI

struct PropertyEditor: View {
    @Environment(RecordsStore.self) private var store
    @Bindable var session: EditorSession<RegistrationDraft>

    var body: some View {
        EditorSheet(feedback: session.feedback, title: "物件を追加", dirty: session.dirty, save: {
            try await store.save { try $0.registering(session.value) }
        }) {
            Section {
                InputField(title: "建物名（必須）", text: $session.value.name, identifier: "property.name")
                InputField(title: "部屋番号（必須）", text: $session.value.roomNumber, identifier: "property.room")
                InputField(title: "所在地", text: $session.value.address, identifier: "property.address", multiline: true)
                SelectionField(title: "管理方法", value: session.value.management.title, selection: $session.value.management) {
                    ForEach(ManagementMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } footer: { Text("保存すると建物と部屋を登録します。記録は端末内に保存します。") }
        }
    }
}

struct BuildingEditor: View {
    @Environment(RecordsStore.self) private var store
    @Bindable var session: EditorSession<Building>
    let original: Building

    var body: some View {
        EditorSheet(feedback: session.feedback, title: "建物を編集", dirty: session.dirty, save: {
            try await store.save { records in
                var records = records
                records.buildings.upsert(session.value)
                return records
            }
        }) {
            Section {
                InputField(title: "建物名（必須）", text: $session.value.name, identifier: "property.name")
                InputField(title: "所在地", text: $session.value.address, identifier: "property.address", multiline: true)
                SelectionField(title: "管理方法", value: session.value.management.title, selection: $session.value.management) {
                    ForEach(ManagementMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("property.management")
                if session.value.management == .agency || session.value.agencyContactID != nil {
                    SelectionField(title: "管理会社の連絡先", value: store.records.contacts.first { $0.id == session.value.agencyContactID }?.name ?? "未登録",
                                   selection: $session.value.agencyContactID) {
                        Text("未登録").tag(UUID?.none)
                        ForEach(store.records.contacts) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .accessibilityIdentifier("property.agency")
                }
                InputField(title: "メモ", text: $session.value.notes, multiline: true)
            }
        }
        .onAppear { session.prepare { original } }
    }
}

struct RoomEditor: View {
    @Environment(RecordsStore.self) private var store
    @Bindable var session: EditorSession<Room>
    let roomID: UUID?

    var body: some View {
        EditorSheet(feedback: session.feedback, title: roomID == nil ? "部屋を追加" : "部屋を編集", dirty: session.dirty, save: {
            try await store.save { records in
                var records = records
                records.rooms.upsert(session.value)
                return records
            }
        }) {
            Section {
                InputField(title: "部屋番号（必須）", text: $session.value.number, identifier: "room.number")
                SelectionField(title: "入居者", value: store.records.contacts.first { $0.id == session.value.residentID }?.name ?? "未登録",
                               selection: $session.value.residentID) {
                    Text("未登録").tag(UUID?.none)
                    ForEach(store.records.contacts) { Text($0.name).tag(Optional($0.id)) }
                }
                .accessibilityIdentifier("room.resident")
                InputField(title: "メモ", text: $session.value.notes, multiline: true)
            }
        }
        .onAppear { session.prepare { store.records.rooms.first { $0.id == roomID } ?? session.value } }
    }
}

struct ContactEditor: View {
    @Environment(RecordsStore.self) private var store
    @Bindable var session: EditorSession<Contact>
    let contactID: UUID?
    let assignment: ContactAssignment

    var body: some View {
        EditorSheet(feedback: session.feedback, title: contactID == nil ? "連絡先を追加" : "連絡先を編集", dirty: session.dirty, save: save) {
            Section {
                InputField(title: "名称（必須）", text: $session.value.name, identifier: "contact.name")
                InputField(title: "会社名", text: $session.value.company, identifier: "contact.company")
                InputField(title: "電話番号", text: $session.value.phone, identifier: "contact.phone").keyboardType(.phonePad)
                InputField(title: "メールアドレス", text: $session.value.email, identifier: "contact.email")
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                InputField(title: "メモ", text: $session.value.notes, identifier: "contact.notes", multiline: true)
            }
            Section("分類") {
                SelectionField(title: "種類", value: session.value.category.title, selection: $session.value.category) {
                    ForEach(ContactCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("contact.category")
                Toggle("緊急連絡先", isOn: $session.value.isEmergency)
                    .accessibilityIdentifier("contact.emergency")
            }
            if !store.records.buildings.isEmpty {
                Section {
                    ForEach(store.records.buildings) { building in
                        Toggle(building.name, isOn: Binding(get: {
                            session.value.buildingIDs.contains(building.id)
                        }, set: { selected in
                            session.value.buildingIDs.removeAll { $0 == building.id }
                            if selected { session.value.buildingIDs.append(building.id) }
                        }))
                    }
                } header: { Text("追加で関連付ける物件") } footer: {
                    Text("入居者や管理会社として登録した物件にも関連付けられます。")
                }
            }
        }
        .onAppear {
            session.prepare {
                if let contact = store.records.contacts.first(where: { $0.id == contactID }) { return contact }
                var contact = session.value
                switch assignment {
                case .resident: contact.category = .resident
                case .agency: contact.category = .management
                case .contractor: contact.category = .maintenance
                case .none: break
                }
                return contact
            }
        }
    }

    private func save() async throws {
        let draft = session.value
        try await store.save { records in
            var records = records
            records.contacts.upsert(draft)
            switch assignment {
            case .none: break
            case .resident(let id):
                guard let index = records.rooms.firstIndex(where: { $0.id == id }) else { throw DomainError.invalidReference }
                records.rooms[index].residentID = draft.id
            case .contractor(let id):
                guard let index = records.work.firstIndex(where: { $0.id == id }) else { throw DomainError.invalidReference }
                records.work[index].contractorID = draft.id
            case .agency(let id):
                guard let index = records.buildings.firstIndex(where: { $0.id == id }) else { throw DomainError.invalidReference }
                records.buildings[index].agencyContactID = draft.id
            }
            return records
        }
    }
}

struct ContractEditor: View {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @Bindable var session: EditorSession<ContractFields>
    let roomID: UUID

    var body: some View {
        EditorSheet(feedback: session.feedback, title: "契約を編集", dirty: session.dirty, canSave: session.value.rent.isValid, save: {
            let fields = session.value
            let contract = Contract(start: fields.start, end: fields.end, monthlyRent: try fields.rent.value(), notice: fields.notice)
            try await store.save { records in
                var records = records
                guard let index = records.rooms.firstIndex(where: { $0.id == roomID }) else { throw DomainError.invalidReference }
                records.rooms[index].contract = contract
                return records
            }
            await notices.synchronize(store.records, reporting: .contract(roomID))
        }) {
            Section {
                DatePicker("契約開始日", selection: $session.value.start, displayedComponents: .date)
                DatePicker("契約満了日", selection: $session.value.end, displayedComponents: .date)
                AmountField(title: "月額家賃（円）", input: $session.value.rent, identifier: "contract.rent")
            } footer: { Text("締結済みの契約内容を登録してください。") }
            ContractNoticeFields(fields: $session.value)
        }
        .environment(\.calendar, ContractDates.calendar)
        .environment(\.timeZone, ContractDates.timeZone)
        .onAppear {
            session.prepare {
                guard let contract = store.records.rooms.first(where: { $0.id == roomID })?.contract else { return session.value }
                return ContractFields(start: contract.start, end: contract.end,
                                      rent: AmountInput(contract.monthlyRent.map(String.init) ?? ""), notice: contract.notice)
            }
        }
    }
}

private struct ContractNoticeFields: View {
    @Binding var fields: ContractFields

    var body: some View {
        Section {
            Toggle("予告期限を記録", isOn: Binding(get: { fields.notice != nil }, set: {
                fields.notice = $0 ? ContractNotice(timing: .date(fields.end)) : nil
            }))
            .accessibilityIdentifier("contract.notice.record")
            if let notice = fields.notice {
                SelectionField(title: "期限の指定方法", value: timingTitle, selection: Binding(get: {
                    if case .monthsBeforeExpiry = notice.timing { return true }
                    return false
                }, set: {
                    fields.notice?.timing = $0 ? .monthsBeforeExpiry(1) : .date(fields.end)
                })) {
                    Text("日付を指定").tag(false)
                    Text("満了日から計算").tag(true)
                }
                .accessibilityIdentifier("contract.notice.timing")
                switch notice.timing {
                case .date(let date):
                    DatePicker("予告期限", selection: Binding(get: { date }, set: { fields.notice?.timing = .date($0) }),
                               displayedComponents: .date)
                        .accessibilityIdentifier("contract.notice.date")
                case .monthsBeforeExpiry(let months):
                    Stepper("満了日の\(months)か月前", value: Binding(get: { months }, set: {
                        fields.notice?.timing = .monthsBeforeExpiry($0)
                    }), in: 1...1_200)
                    .accessibilityIdentifier("contract.notice.months")
                    if let deadline = notice.deadline(expiry: fields.end, calendar: ContractDates.calendar) {
                        LabeledContent("予告期限", value: deadline.formatted(ContractDates.format))
                    }
                }
                Toggle("期限を通知", isOn: Binding(get: { notice.reminderEnabled }, set: { fields.notice?.reminderEnabled = $0 }))
                    .accessibilityIdentifier("contract.notice.notify")
                if notice.reminderEnabled {
                    SelectionField(title: "事前通知", value: notice.advanceDays == 0 ? "なし" : "\(notice.advanceDays)日前",
                                   selection: Binding(get: { notice.advanceDays }, set: { fields.notice?.advanceDays = $0 })) {
                        Text("なし").tag(0)
                        Text("7日前").tag(7)
                        Text("30日前").tag(30)
                        Text("90日前").tag(90)
                        if ![0, 7, 30, 90].contains(notice.advanceDays) { Text("\(notice.advanceDays)日前").tag(notice.advanceDays) }
                    }
                    .accessibilityIdentifier("contract.notice.advance")
                }
            }
        } header: { Text("更新・解約の予告") } footer: {
            Text("契約書に記載された予告期限を設定してください。日付と午前9時の通知は日本時間が基準です。")
        }
    }

    private var timingTitle: String {
        if let notice = fields.notice, case .monthsBeforeExpiry = notice.timing { return "満了日から計算" }
        return "日付を指定"
    }
}

struct EquipmentEditor: View {
    @Environment(RecordsStore.self) private var store
    @Bindable var session: EditorSession<Equipment>
    let roomID: UUID
    let equipmentID: UUID?

    var body: some View {
        EditorSheet(feedback: session.feedback, title: equipmentID == nil ? "設備を追加" : "設備を編集", dirty: session.dirty, save: {
            try await store.save { records in
                var records = records
                guard let index = records.rooms.firstIndex(where: { $0.id == roomID }) else { throw DomainError.invalidReference }
                records.rooms[index].equipment.upsert(session.value)
                return records
            }
        }) {
            Section {
                InputField(title: "設備名（必須）", text: $session.value.name, identifier: "equipment.name")
                InputField(title: "型番", text: $session.value.model, identifier: "equipment.model")
                Toggle("設置日を記録", isOn: Binding(get: { session.value.installedOn != nil },
                                               set: { session.value.installedOn = $0 ? Date() : nil }))
                if session.value.installedOn != nil {
                    DatePicker("設置日", selection: Binding(get: { session.value.installedOn ?? Date() },
                                                          set: { session.value.installedOn = $0 }),
                               displayedComponents: .date)
                }
                InputField(title: "メモ", text: $session.value.notes, multiline: true)
            }
        }
        .onAppear {
            session.prepare {
                store.records.rooms.first(where: { $0.id == roomID })?.equipment.first(where: { $0.id == equipmentID }) ?? session.value
            }
        }
    }
}
