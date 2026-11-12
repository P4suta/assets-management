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

enum EditorDestination: Identifiable {
    case registration
    case building(UUID)
    case room(UUID, UUID?)
    case work(UUID?, UUID?, UUID?, WorkKind)
    case contact(UUID?, ContactAssignment)
    case contract(UUID)
    case equipment(UUID, UUID?)
    case history(UUID, UUID?)
    case schedule(UUID)
    case renewal(UUID)

    var id: String { String(describing: self) }
}

enum ContactAssignment {
    case none, resident(UUID), contractor(UUID), agency(UUID)
}

struct EditorDestinationView: View {
    @Environment(RecordsStore.self) private var store
    let destination: EditorDestination

    @ViewBuilder var body: some View {
        switch destination {
        case .registration: PropertyEditor()
        case .building(let id):
            if let value = store.records.buildings.first(where: { $0.id == id }) { BuildingEditor(original: value) }
        case .room(let buildingID, let id): RoomEditor(buildingID: buildingID, roomID: id)
        case .work(let buildingID, let roomID, let id, let kind):
            WorkEditor(buildingID: buildingID, roomID: roomID, workID: id, kind: kind)
        case .contact(let id, let assignment): ContactEditor(contactID: id, assignment: assignment)
        case .contract(let id): ContractEditor(roomID: id)
        case .equipment(let roomID, let id): EquipmentEditor(roomID: roomID, equipmentID: id)
        case .history(let workID, let id): HistoryEditor(workID: workID, entryID: id)
        case .schedule(let id): ScheduleEditor(workID: id)
        case .renewal(let id): RenewalEditor(workID: id)
        }
    }
}
