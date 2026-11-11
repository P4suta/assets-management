import PropertyCore
import SwiftUI

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
