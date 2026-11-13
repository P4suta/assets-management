import PropertyCore
import SwiftUI

struct BuildingListView: View {
    @Binding var selection: UUID?
    @Environment(RecordsStore.self) private var store
    @State private var query = ""
    @State private var editor: EditorDestination?
    @State private var appInformation = false

    private var buildings: [Building] {
        store.records.buildings.filter { building in
            query.isEmpty || building.name.localizedStandardContains(query)
                || building.address.localizedStandardContains(query)
                || store.records.rooms.contains { $0.buildingID == building.id && $0.number.localizedStandardContains(query) }
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List(selection: $selection) {
            if buildings.isEmpty {
                ContentUnavailableView {
                    Label(query.isEmpty ? "物件を登録しましょう" : "物件が見つかりません", systemImage: "building.2")
                } description: {
                    Text(query.isEmpty ? "建物と部屋を登録して、修繕や連絡を記録できます。" : "建物名、住所、部屋番号を変更して検索してください。")
                } actions: {
                    if query.isEmpty { Button("物件を追加") { editor = .registration }.accessibilityIdentifier("property.firstAdd") }
                }
            } else {
                Section("建物") {
                    ForEach(buildings) { building in
                        NavigationLink(value: building.id) {
                            let selected = selection == building.id
                            VStack(alignment: .leading, spacing: 8) {
                                Text(building.name).recordForeground(Color.primary, selected: selected)
                                Text(building.management.title + " · \(store.records.rooms.filter { $0.buildingID == building.id }.count)部屋")
                                    .font(.subheadline).recordForeground(Color.secondary, selected: selected)
                            }.padding(.vertical, 4).accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .navigationTitle("物件")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "検索")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("アプリについて", systemImage: "info.circle") { appInformation = true }
                    .accessibilityIdentifier("app-info.open")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("物件を追加", systemImage: "plus") { editor = .registration }
                    .accessibilityIdentifier("property.add")
            }
        }
        .editorPresentation($editor)
        .sheet(isPresented: $appInformation) { AppInformationView() }
    }
}

struct BuildingDetailView: View {
    @Environment(RecordsStore.self) private var store
    @State private var editor: EditorDestination?
    let buildingID: UUID
    private var building: Building? { store.records.buildings.first { $0.id == buildingID } }

    var body: some View {
        List {
            if let building {
                Section {
                    Text(building.name).font(.title2).bold()
                    Text(building.management.title).foregroundStyle(Color.secondary)
                    if !building.address.isEmpty { Text(building.address) }
                    if !building.notes.isEmpty { Text(building.notes) }
                }
                Section("部屋") {
                    ForEach(store.records.rooms.filter { $0.buildingID == buildingID }.sorted { $0.number < $1.number }) { room in
                        NavigationLink { RoomDetailView(roomID: room.id) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(room.number + "号室")
                                Text(room.residentID.flatMap { id in store.records.contacts.first { $0.id == id }?.name } ?? "入居者は未登録")
                                    .font(.subheadline).foregroundStyle(Color.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                    Button("部屋を追加", systemImage: "plus") { editor = .room(buildingID, nil) }
                }
                if building.management == .agency || building.agencyContactID != nil {
                    Section("管理会社") {
                        if let id = building.agencyContactID {
                            NavigationLink("管理会社の連絡先") { ContactDetailView(contactID: id) }
                        } else {
                            Button("管理会社の連絡先を登録") { editor = .contact(nil, .agency(buildingID)) }
                        }
                    }
                }
                RecordPhotosSection(location: RecordLocation(buildingID: buildingID))
            }
        }
        .accessibilityIdentifier("property.detail")
        .recordPhotosPresentation(at: RecordLocation(buildingID: buildingID))
        .navigationTitle("建物")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if building != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("建物を編集", systemImage: "square.and.pencil") { editor = .building(buildingID) }
                        .accessibilityIdentifier("property.edit")
                }
            }
        }
        .editorPresentation($editor)
    }
}

struct RoomDetailView: View {
    @Environment(RecordsStore.self) private var store
    @State private var editor: EditorDestination?
    let roomID: UUID
    private var room: Room? { store.records.rooms.first { $0.id == roomID } }

    var body: some View {
        List {
            if let room {
                Section("入居者と契約") {
                    if let id = room.residentID {
                        NavigationLink {
                            ContactDetailView(contactID: id)
                        } label: {
                            LabeledContent("入居者", value: store.records.contacts.first { $0.id == id }?.name ?? "未登録")
                        }
                    } else {
                        Button("入居者を登録") { editor = .contact(nil, .resident(roomID)) }
                    }
                    NavigationLink {
                        ContractDetailView(roomID: roomID)
                    } label: { Text("賃貸借契約") }
                    LabeledContent("家賃", value: yen(room.contract?.monthlyRent))
                }
                Section("部屋の情報") {
                    NavigationLink("設備") { EquipmentListView(roomID: roomID) }
                    if !room.notes.isEmpty { Text(room.notes) }
                }
                RecordPhotosSection(location: RecordLocation(buildingID: room.buildingID, roomID: roomID))
            }
        }
        .accessibilityIdentifier("room.detail")
        .recordPhotosPresentation(at: room.map { RecordLocation(buildingID: $0.buildingID, roomID: $0.id) })
        .navigationTitle(room.map { $0.number + "号室" } ?? "部屋")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let room {
                ToolbarItem(placement: .primaryAction) {
                    Button("部屋を編集", systemImage: "square.and.pencil") { editor = .room(room.buildingID, roomID) }
                        .accessibilityIdentifier("room.edit")
                }
            }
        }
        .editorPresentation($editor)
    }
}

struct ContractDetailView: View {
    @Environment(RecordsStore.self) private var store
    @State private var editor: EditorDestination?
    let roomID: UUID
    private var room: Room? { store.records.rooms.first { $0.id == roomID } }

    var body: some View {
        List {
            ReminderReport()
            if let contract = room?.contract {
                if let room {
                    Section {
                        Text(store.records.buildings.first { $0.id == room.buildingID }?.name ?? "")
                        Text(room.number + "号室")
                    }
                }
                Section("現在の契約") {
                    LabeledContent("契約開始日", value: contract.start.formatted(ContractDates.format))
                    LabeledContent("契約満了日", value: contract.end.formatted(ContractDates.format))
                    LabeledContent("家賃", value: yen(contract.monthlyRent))
                }
                if let notice = contract.notice, let deadline = notice.deadline(expiry: contract.end, calendar: ContractDates.calendar) {
                    Section {
                        LabeledContent("予告期限", value: deadline.formatted(ContractDates.format))
                        LabeledContent("通知の設定", value: notice.reminderEnabled ? "オン" : "オフ")
                        if notice.reminderEnabled { LabeledContent("期限当日の通知", value: "午前9時") }
                        if notice.reminderEnabled, notice.advanceDays > 0 {
                            LabeledContent("事前通知", value: "\(notice.advanceDays)日前の午前9時")
                        }
                    } header: { Text("更新・解約の予告") }
                      footer: { Text("日付と通知時刻は日本時間が基準です。") }
                    ReminderReservationIssue(target: .contract(roomID))
                }
            } else {
                ContentUnavailableView("契約は未登録です", systemImage: "doc.text",
                                       description: Text("契約期間と家賃を登録できます。"))
            }
        }
        .accessibilityIdentifier("contract.detail")
        .navigationTitle("賃貸借契約")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if room != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(room?.contract == nil ? "契約を登録" : "契約を編集", systemImage: "square.and.pencil") {
                        editor = .contract(roomID)
                    }
                    .accessibilityIdentifier("contract.edit")
                }
            }
        }
        .editorPresentation($editor)
    }
}

struct EquipmentListView: View {
    @Environment(RecordsStore.self) private var store
    @State private var editor: EditorDestination?
    let roomID: UUID
    private var equipment: [Equipment] { store.records.rooms.first { $0.id == roomID }?.equipment ?? [] }

    var body: some View {
        List {
            if equipment.isEmpty {
                ContentUnavailableView("設備は未登録です", systemImage: "gearshape",
                                       description: Text("型番や設置日を記録できます。"))
            }
            ForEach(equipment) { item in
                Button { editor = .equipment(roomID, item.id) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name).foregroundStyle(Color.primary)
                        if !item.model.isEmpty { Text(item.model).foregroundStyle(Color.secondary) }
                        if let date = item.installedOn {
                            Text("設置日 " + date.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(Color.secondary)
                        }
                        if !item.notes.isEmpty { Text(item.notes).foregroundStyle(Color.secondary) }
                    }.padding(.vertical, 4)
                }
            }
        }
        .accessibilityIdentifier("equipment.list")
        .navigationTitle("設備")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("設備を追加", systemImage: "plus") { editor = .equipment(roomID, nil) }
            }
        }
        .editorPresentation($editor)
    }
}

struct ContactDetailView: View {
    @Environment(RecordsStore.self) private var store
    @State private var editor: EditorDestination?
    @State private var confirmingDeletion = false
    @State private var deleting = false
    @State private var message: String?
    let contactID: UUID
    private var contact: Contact? { store.records.contacts.first { $0.id == contactID } }

    var body: some View {
        List {
            if let contact {
                Section("連絡先") {
                    Text(contact.name).font(.title2).bold()
                    LabeledContent("種類", value: contact.category.title)
                    if contact.isEmergency { Label("緊急連絡先", systemImage: "exclamationmark.circle") }
                    if !contact.company.isEmpty { LabeledContent("会社名", value: contact.company) }
                    if !contact.phone.isEmpty {
                        if let url = contact.telephoneURL {
                            Link(destination: url) { LabeledContent("電話", value: contact.phone) }
                                .accessibilityLabel("電話")
                                .accessibilityValue(contact.phone)
                                .accessibilityIdentifier("contact.phone.open")
                        } else {
                            LabeledContent("電話", value: contact.phone).textSelection(.enabled)
                        }
                    }
                    if !contact.email.isEmpty {
                        if let url = contact.emailURL {
                            Link(destination: url) { LabeledContent("メール", value: contact.email) }
                                .accessibilityLabel("メール")
                                .accessibilityValue(contact.email)
                                .accessibilityIdentifier("contact.email.open")
                        } else {
                            LabeledContent("メール", value: contact.email).textSelection(.enabled)
                        }
                    }
                    if !contact.notes.isEmpty { Text(contact.notes) }
                }
                let buildings = store.records.relatedBuildings(for: contact.id)
                if !buildings.isEmpty {
                    Section("関連する物件") {
                        ForEach(buildings) { Text($0.name) }
                    }
                }
                Section {
                    if let message { Text(message).accessibilityIdentifier("contact.error") }
                    Button("連絡先を削除", role: .destructive) { confirmingDeletion = true }
                        .disabled(deleting)
                }
            } else {
                ContentUnavailableView("連絡先は削除されました", systemImage: "person.crop.rectangle.stack")
            }
        }
        .accessibilityIdentifier("contact.detail")
        .navigationTitle("連絡先")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if contact != nil { ToolbarItem(placement: .primaryAction) {
                Button("連絡先を編集", systemImage: "square.and.pencil") { editor = .contact(contactID, .none) }
                    .accessibilityIdentifier("contact.edit")
            } }
        }
        .editorPresentation($editor)
        .alert("連絡先を削除", isPresented: $confirmingDeletion) {
            Button("削除", role: .destructive) {
                deleting = true
                Task {
                    do { try await store.save { try $0.removingContact(contactID) } }
                    catch { message = errorMessage(error) }
                    deleting = false
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("物件への割り当ても解除します。対応のメモと写真は残ります。") }
    }
}
