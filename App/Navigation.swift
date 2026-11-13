import PropertyCore
import SwiftUI

struct WorkNavigationView: View {
    @State private var selection: UUID?
    let onRegister: () -> Void

    var body: some View {
        NavigationSplitView {
            WorkListView(selection: $selection, onRegister: onRegister)
        } detail: {
            NavigationStack {
                if let selection {
                    WorkDetailView(workID: selection)
                } else {
                    ContentUnavailableView("対応を選択", systemImage: "checklist",
                                           description: Text("一覧から修繕、契約更新、点検を選択してください。"))
                }
            }
            .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct BuildingNavigationView: View {
    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            BuildingListView(selection: $selection)
        } detail: {
            NavigationStack {
                if let selection {
                    BuildingDetailView(buildingID: selection)
                } else {
                    ContentUnavailableView("物件を選択", systemImage: "building.2",
                                           description: Text("建物を選択すると、部屋や共用部分の記録を確認できます。"))
                }
            }
            .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

@MainActor struct EditorDestination: Identifiable {
    let id = UUID()
    let content: Content

    enum Content {
        case registration(EditorSession<RegistrationDraft>)
        case building(UUID, EditorSession<Building>)
        case room(UUID?, EditorSession<Room>)
        case work(UUID?, EditorSession<WorkFields>)
        case contact(UUID?, ContactAssignment, EditorSession<Contact>)
        case contract(UUID, EditorSession<ContractFields>)
        case equipment(UUID, UUID?, EditorSession<Equipment>)
        case history(UUID?, EditorSession<HistoryEntry>)
        case schedule(UUID, EditorSession<ScheduleFields>)
        case renewal(UUID, EditorSession<RenewalFields>)
    }

    static var registration: Self { Self(content: .registration(EditorSession(RegistrationDraft()))) }

    static func building(_ id: UUID) -> Self {
        Self(content: .building(id, EditorSession(Building(id: id, name: ""))))
    }

    static func room(_ buildingID: UUID, _ id: UUID?) -> Self {
        Self(content: .room(id, EditorSession(Room(id: id ?? UUID(), buildingID: buildingID, number: ""))))
    }

    static func work(_ buildingID: UUID?, _ roomID: UUID?, _ id: UUID?, _ kind: WorkKind) -> Self {
        let item = WorkItem(id: id ?? UUID(), buildingID: buildingID ?? UUID(), roomID: roomID, kind: kind, title: "")
        return Self(content: .work(id, EditorSession(WorkFields(item))))
    }

    static func contact(_ id: UUID?, _ assignment: ContactAssignment) -> Self {
        Self(content: .contact(id, assignment, EditorSession(Contact(id: id ?? UUID(), name: ""))))
    }

    static func contract(_ roomID: UUID) -> Self {
        let start = Date()
        let end = Calendar.current.date(byAdding: .year, value: 2, to: start) ?? start
        return Self(content: .contract(roomID, EditorSession(ContractFields(start: start, end: end))))
    }

    static func equipment(_ roomID: UUID, _ id: UUID?) -> Self {
        Self(content: .equipment(roomID, id, EditorSession(Equipment(id: id ?? UUID(), name: ""))))
    }

    static func history(_ workID: UUID, _ id: UUID?) -> Self {
        Self(content: .history(id, EditorSession(HistoryEntry(id: id ?? UUID(), workID: workID, text: ""))))
    }

    static func schedule(_ workID: UUID) -> Self {
        Self(content: .schedule(workID, EditorSession(ScheduleFields(date: Date()))))
    }

    static func renewal(_ workID: UUID) -> Self {
        let date = Date()
        return Self(content: .renewal(workID, EditorSession(RenewalFields(start: date, end: date, due: date))))
    }
}

enum ContactAssignment {
    case none, resident(UUID), contractor(UUID), agency(UUID)
}

struct EditorDestinationView: View {
    @Environment(RecordsStore.self) private var store
    let destination: EditorDestination

    @ViewBuilder var body: some View {
        switch destination.content {
        case .registration(let session): PropertyEditor(session: session)
        case .building(let id, let session):
            if let value = store.records.buildings.first(where: { $0.id == id }) { BuildingEditor(session: session, original: value) }
        case .room(let id, let session): RoomEditor(session: session, roomID: id)
        case .work(let id, let session): WorkEditor(session: session, workID: id)
        case .contact(let id, let assignment, let session): ContactEditor(session: session, contactID: id, assignment: assignment)
        case .contract(let id, let session): ContractEditor(session: session, roomID: id)
        case .equipment(let roomID, let id, let session): EquipmentEditor(session: session, roomID: roomID, equipmentID: id)
        case .history(let id, let session): HistoryEditor(session: session, entryID: id)
        case .schedule(let id, let session): ScheduleEditor(session: session, workID: id)
        case .renewal(let id, let session): RenewalEditor(session: session, workID: id)
        }
    }
}
