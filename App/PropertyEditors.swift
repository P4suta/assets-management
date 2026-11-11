import PropertyCore
import SwiftUI

struct PropertyEditor: View {
    @Environment(RecordsStore.self) private var store
    @State private var draft = RegistrationDraft()

    var body: some View {
        EditorSheet(title: "物件を追加", dirty: draft != RegistrationDraft(), save: {
            try await store.save { try $0.registering(draft) }
        }) {
            Section {
                InputField(title: "建物名（必須）", text: $draft.name, identifier: "property.name")
                InputField(title: "部屋番号（必須）", text: $draft.roomNumber, identifier: "property.room")
                InputField(title: "所在地", text: $draft.address, identifier: "property.address", multiline: true)
                Picker("管理方法", selection: $draft.management) {
                    ForEach(ManagementMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            } footer: { Text("保存すると建物と部屋を登録します。記録は端末内に保存します。") }
        }
    }
}

struct BuildingEditor: View {
    @Environment(RecordsStore.self) private var store
    @State private var draft: Building
    let original: Building

    init(original: Building) {
        self.original = original
        _draft = State(initialValue: original)
    }

    var body: some View {
        EditorSheet(title: "建物を編集", dirty: draft != original, save: {
            try await store.save { records in
                var records = records
                records.buildings.upsert(draft)
                return records
            }
        }) {
            Section {
                InputField(title: "建物名（必須）", text: $draft.name, identifier: "property.name")
                InputField(title: "所在地", text: $draft.address, identifier: "property.address", multiline: true)
                Picker("管理方法", selection: $draft.management) {
                    ForEach(ManagementMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                InputField(title: "メモ", text: $draft.notes, multiline: true)
            }
        }
    }
}

struct RoomEditor: View {
    @Environment(RecordsStore.self) private var store
    @State private var draft: Room
    @State private var baseline: Room
    @State private var prepared = false
    let roomID: UUID?

    init(buildingID: UUID, roomID: UUID?) {
        self.roomID = roomID
        let room = Room(id: roomID ?? UUID(), buildingID: buildingID, number: "")
        _draft = State(initialValue: room)
        _baseline = State(initialValue: room)
    }

    var body: some View {
        EditorSheet(title: roomID == nil ? "部屋を追加" : "部屋を編集", dirty: draft != baseline, save: {
            try await store.save { records in
                var records = records
                records.rooms.upsert(draft)
                return records
            }
        }) {
            Section {
                InputField(title: "部屋番号（必須）", text: $draft.number, identifier: "room.number")
                Picker("入居者", selection: $draft.residentID) {
                    Text("未登録").tag(UUID?.none)
                    ForEach(store.records.contacts) { Text($0.name).tag(Optional($0.id)) }
                }
                InputField(title: "メモ", text: $draft.notes, multiline: true)
            }
        }
        .onAppear {
            guard !prepared else { return }
            if let original = store.records.rooms.first(where: { $0.id == roomID }) { draft = original }
            baseline = draft
            prepared = true
        }
    }
}

struct ContactEditor: View {
    @Environment(RecordsStore.self) private var store
    @State private var draft: Contact
    @State private var baseline: Contact
    @State private var prepared = false
    let contactID: UUID?
    let assignment: ContactAssignment

    init(contactID: UUID?, assignment: ContactAssignment) {
        self.contactID = contactID
        self.assignment = assignment
        let value = Contact(id: contactID ?? UUID(), name: "")
        _draft = State(initialValue: value)
        _baseline = State(initialValue: value)
    }

    var body: some View {
        EditorSheet(title: contactID == nil ? "連絡先を追加" : "連絡先を編集", dirty: draft != baseline, save: save) {
            Section {
                InputField(title: "氏名（必須）", text: $draft.name, identifier: "contact.name")
                InputField(title: "会社名", text: $draft.company)
                InputField(title: "電話番号", text: $draft.phone, identifier: "contact.phone").keyboardType(.phonePad)
                InputField(title: "メールアドレス", text: $draft.email, identifier: "contact.email")
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                InputField(title: "メモ", text: $draft.notes, multiline: true)
            }
        }
        .onAppear {
            guard !prepared else { return }
            if let original = store.records.contacts.first(where: { $0.id == contactID }) { draft = original }
            baseline = draft
            prepared = true
        }
    }

    private func save() async throws {
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
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    @State private var rent = ""
    @State private var baseline: Contract?
    @State private var baselineRent = ""
    @State private var prepared = false
    let roomID: UUID

    private var dirty: Bool { baseline.map { $0.start != start || $0.end != end } ?? false || rent != baselineRent }

    var body: some View {
        EditorSheet(title: "契約を編集", dirty: dirty, save: {
            let contract = Contract(start: start, end: end, monthlyRent: try amountValue(rent))
            try await store.save { records in
                var records = records
                guard let index = records.rooms.firstIndex(where: { $0.id == roomID }) else { throw DomainError.invalidReference }
                records.rooms[index].contract = contract
                return records
            }
        }) {
            Section {
                DatePicker("契約開始日", selection: $start, displayedComponents: .date)
                DatePicker("契約満了日", selection: $end, displayedComponents: .date)
                InputField(title: "月額家賃（円）", text: $rent, identifier: "contract.rent").keyboardType(.numberPad)
            } footer: { Text("締結済みの契約内容を登録してください。") }
        }
        .onAppear {
            guard !prepared else { return }
            if let contract = store.records.rooms.first(where: { $0.id == roomID })?.contract {
                start = contract.start
                end = contract.end
                rent = contract.monthlyRent.map(String.init) ?? ""
            }
            baseline = Contract(start: start, end: end)
            baselineRent = rent
            prepared = true
        }
    }
}

struct EquipmentEditor: View {
    @Environment(RecordsStore.self) private var store
    @State private var draft: Equipment
    @State private var baseline: Equipment
    @State private var prepared = false
    let roomID: UUID
    let equipmentID: UUID?

    init(roomID: UUID, equipmentID: UUID?) {
        self.roomID = roomID
        self.equipmentID = equipmentID
        let value = Equipment(id: equipmentID ?? UUID(), name: "")
        _draft = State(initialValue: value)
        _baseline = State(initialValue: value)
    }

    var body: some View {
        EditorSheet(title: equipmentID == nil ? "設備を追加" : "設備を編集", dirty: draft != baseline, save: {
            try await store.save { records in
                var records = records
                guard let index = records.rooms.firstIndex(where: { $0.id == roomID }) else { throw DomainError.invalidReference }
                records.rooms[index].equipment.upsert(draft)
                return records
            }
        }) {
            Section {
                InputField(title: "設備名（必須）", text: $draft.name, identifier: "equipment.name")
                InputField(title: "型番", text: $draft.model, identifier: "equipment.model")
                Toggle("設置日を記録", isOn: Binding(get: { draft.installedOn != nil }, set: { draft.installedOn = $0 ? Date() : nil }))
                if draft.installedOn != nil {
                    DatePicker("設置日", selection: Binding(get: { draft.installedOn ?? Date() }, set: { draft.installedOn = $0 }),
                               displayedComponents: .date)
                }
                InputField(title: "メモ", text: $draft.notes, multiline: true)
            }
        }
        .onAppear {
            guard !prepared else { return }
            if let original = store.records.rooms.first(where: { $0.id == roomID })?.equipment.first(where: { $0.id == equipmentID }) {
                draft = original
            }
            baseline = draft
            prepared = true
        }
    }
}
