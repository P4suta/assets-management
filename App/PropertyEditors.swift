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
                Picker("管理方法", selection: $session.value.management) {
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
                Picker("管理方法", selection: $session.value.management) {
                    ForEach(ManagementMode.allCases, id: \.self) { Text($0.title).tag($0) }
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
                Picker("入居者", selection: $session.value.residentID) {
                    Text("未登録").tag(UUID?.none)
                    ForEach(store.records.contacts) { Text($0.name).tag(Optional($0.id)) }
                }
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
                InputField(title: "氏名（必須）", text: $session.value.name, identifier: "contact.name")
                InputField(title: "会社名", text: $session.value.company)
                InputField(title: "電話番号", text: $session.value.phone, identifier: "contact.phone").keyboardType(.phonePad)
                InputField(title: "メールアドレス", text: $session.value.email, identifier: "contact.email")
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                InputField(title: "メモ", text: $session.value.notes, multiline: true)
            }
        }
        .onAppear { session.prepare { store.records.contacts.first { $0.id == contactID } ?? session.value } }
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
    @Bindable var session: EditorSession<ContractFields>
    let roomID: UUID

    var body: some View {
        EditorSheet(feedback: session.feedback, title: "契約を編集", dirty: session.dirty, canSave: session.value.rent.isValid, save: {
            let fields = session.value
            let contract = Contract(start: fields.start, end: fields.end, monthlyRent: try fields.rent.value())
            try await store.save { records in
                var records = records
                guard let index = records.rooms.firstIndex(where: { $0.id == roomID }) else { throw DomainError.invalidReference }
                records.rooms[index].contract = contract
                return records
            }
        }) {
            Section {
                DatePicker("契約開始日", selection: $session.value.start, displayedComponents: .date)
                DatePicker("契約満了日", selection: $session.value.end, displayedComponents: .date)
                AmountField(title: "月額家賃（円）", input: $session.value.rent, identifier: "contract.rent")
            } footer: { Text("締結済みの契約内容を登録してください。") }
        }
        .onAppear {
            session.prepare {
                guard let contract = store.records.rooms.first(where: { $0.id == roomID })?.contract else { return session.value }
                return ContractFields(start: contract.start, end: contract.end,
                                      rent: AmountInput(contract.monthlyRent.map(String.init) ?? ""))
            }
        }
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
