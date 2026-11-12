import PropertyCore
import SwiftUI

struct BuildingListView: View {
    @Environment(\.dynamicTypeSize) private var textSize
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
        List {
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
                        NavigationLink { BuildingDetailView(buildingID: building.id) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(building.name).foregroundStyle(Color.primary)
                                Text(building.management.title + " · \(store.records.rooms.filter { $0.buildingID == building.id }.count)部屋")
                                    .font(.subheadline).foregroundStyle(Color.secondary)
                                let count = store.records.work.filter { $0.buildingID == building.id && $0.status != .completed }.count
                                Text("未完了の対応 \(count)件").font(.footnote).foregroundStyle(Color.secondary)
                            }.padding(.vertical, 4).accessibilityElement(children: .combine)
                        }
                        .contextMenu { Button("編集") { editor = .building(building.id) } }
                        .swipeActions { Button("編集") { editor = .building(building.id) } }
                    }
                }
            }
        }
        .navigationTitle("物件")
        .navigationBarTitleDisplayMode(textSize.isAccessibilitySize ? .inline : .large)
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
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
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
                        .contextMenu { Button("編集") { editor = .room(buildingID, room.id) } }
                        .swipeActions { Button("編集") { editor = .room(buildingID, room.id) } }
                    }
                    Button("部屋を追加", systemImage: "plus") { editor = .room(buildingID, nil) }
                }
                Section("建物の情報") {
                    NavigationLink("書類") { DocumentsView(location: RecordLocation(buildingID: buildingID)) }
                    if let id = building.agencyContactID {
                        NavigationLink("管理会社の連絡先") { ContactDetailView(contactID: id) }
                    } else if building.management == .agency {
                        Button("管理会社の連絡先を登録") { editor = .contact(nil, .agency(buildingID)) }
                    }
                    Button("建物を編集", systemImage: "square.and.pencil") { editor = .building(buildingID) }
                }
                Section("共用部分の対応") {
                    let common = store.records.work.filter { $0.buildingID == buildingID && $0.roomID == nil }
                    if common.isEmpty { Text("対応の記録はありません").foregroundStyle(Color.secondary) }
                    ForEach(common) { item in
                        NavigationLink { WorkDetailView(workID: item.id) } label: { WorkRow(item: item) }
                    }
                    Button("共用部分の対応を追加", systemImage: "plus") { editor = .work(buildingID, nil, nil, .repair) }
                }
            }
        }
        .navigationTitle("建物")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
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
                    } label: { Text(room.contract == nil ? "契約を登録" : "賃貸借契約") }
                    LabeledContent("家賃", value: yen(room.contract?.monthlyRent))
                }
                Section("部屋の情報") {
                    NavigationLink("設備") { EquipmentListView(roomID: roomID) }
                    NavigationLink("書類") {
                        DocumentsView(location: RecordLocation(buildingID: room.buildingID, roomID: roomID))
                    }
                    if !room.notes.isEmpty { Text(room.notes) }
                }
                Section("過去と進行中の対応") {
                    ForEach(store.records.work.filter { $0.roomID == roomID }.sorted { $0.receivedAt > $1.receivedAt }) { item in
                        NavigationLink { WorkDetailView(workID: item.id) } label: { WorkRow(item: item) }
                    }
                    Button("対応を追加", systemImage: "plus") { editor = .work(room.buildingID, roomID, nil, .repair) }
                }
            }
        }
        .navigationTitle(room.map { $0.number + "号室" } ?? "部屋")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let room {
                ToolbarItem(placement: .primaryAction) {
                    Button("部屋を編集", systemImage: "square.and.pencil") { editor = .room(room.buildingID, roomID) }
                }
            }
        }
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
    }
}

struct ContractDetailView: View {
    @Environment(RecordsStore.self) private var store
    @State private var editor: EditorDestination?
    let roomID: UUID
    private var room: Room? { store.records.rooms.first { $0.id == roomID } }

    var body: some View {
        List {
            if let contract = room?.contract {
                Section("現在の契約") {
                    LabeledContent("契約開始日", value: contract.start.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("契約満了日", value: contract.end.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("家賃", value: yen(contract.monthlyRent))
                }
            } else {
                ContentUnavailableView("契約は未登録です", systemImage: "doc.text",
                                       description: Text("契約期間と家賃を登録できます。"))
            }
            Section {
                Button("契約を編集", systemImage: "square.and.pencil") { editor = .contract(roomID) }
                if let room {
                    Button("契約更新の対応を追加", systemImage: "calendar") {
                        editor = .work(room.buildingID, roomID, nil, .renewal)
                    }
                }
            }
            Section("契約更新の対応") {
                ForEach(store.records.work.filter { $0.roomID == roomID && $0.kind == .renewal }) { item in
                    NavigationLink { WorkDetailView(workID: item.id) } label: { WorkRow(item: item) }
                }
            }
        }
        .navigationTitle("賃貸借契約")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
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
                .contextMenu { Button("編集") { editor = .equipment(roomID, item.id) } }
                .swipeActions { Button("編集") { editor = .equipment(roomID, item.id) } }
            }
        }
        .navigationTitle("設備")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("設備を追加", systemImage: "plus") { editor = .equipment(roomID, nil) }
            }
        }
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
    }
}

struct ContactDetailView: View {
    @Environment(RecordsStore.self) private var store
    @State private var editor: EditorDestination?
    let contactID: UUID
    private var contact: Contact? { store.records.contacts.first { $0.id == contactID } }

    var body: some View {
        List {
            if let contact {
                Section("連絡先") {
                    Text(contact.name).font(.title2).bold()
                    if !contact.company.isEmpty { LabeledContent("会社名", value: contact.company) }
                    if !contact.phone.isEmpty {
                        if let url = URL(string: "tel:" + contact.phone.filter { $0.isNumber || $0 == "+" }) {
                            Link(destination: url) { LabeledContent("電話", value: contact.phone) }
                        }
                    }
                    if !contact.email.isEmpty, let url = URL(string: "mailto:" + contact.email) {
                        Link(destination: url) { LabeledContent("メール", value: contact.email) }
                    }
                    if !contact.notes.isEmpty { Text(contact.notes) }
                }
                Section { Text("連絡履歴は対応の詳細から記録できます。").foregroundStyle(Color.secondary) }
            }
        }
        .navigationTitle("連絡先")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("連絡先を編集", systemImage: "square.and.pencil") { editor = .contact(contactID, .none) }
            }
        }
        .sheet(item: $editor) { EditorDestinationView(destination: $0) }
    }
}
