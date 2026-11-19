import Foundation

public enum RecordDeletionTarget: Hashable, Sendable {
    case building(UUID)
    case room(UUID)
    case contract(roomID: UUID)
    case equipment(roomID: UUID, id: UUID)
    case work(UUID)
    case memo(UUID)
    case attachment(UUID)
    case contact(UUID)
}

public struct RecordDeletionPlan: Equatable, Sendable {
    public let target: RecordDeletionTarget
    public let name: String
    public let affected: Set<RecordDeletionTarget>
    public let attachmentKinds: [UUID: AttachmentKind]
    public let attachment: Attachment?
    fileprivate let contract: Contract?
    fileprivate let links: Set<RecordDeletionTarget>

    public var affectsReminders: Bool {
        affected.contains {
            switch $0 {
            case .contract, .work: true
            default: false
            }
        }
    }
}

public enum RecordDeletionError: Error, Equatable, Sendable {
    case changed(RecordDeletionPlan)
}

extension Records {
    public func deletionPlan(for target: RecordDeletionTarget) throws -> RecordDeletionPlan {
        let name: String
        var removedRooms: [Room] = []
        var removedWork: [WorkItem] = []
        var removedAttachments: [Attachment] = []
        var contract: Contract?
        var attachment: Attachment?
        var links: Set<RecordDeletionTarget> = []
        switch target {
        case .building(let id):
            guard let building = buildings.first(where: { $0.id == id }) else { throw DomainError.invalidReference }
            name = building.name
            removedRooms = rooms.filter { $0.buildingID == id }
            removedWork = work.filter { $0.buildingID == id }
            removedAttachments = attachments.filter { $0.buildingID == id }
            links = Set(contacts.filter { $0.buildingIDs.contains(id) }.map { .contact($0.id) })
        case .room(let id):
            guard let room = rooms.first(where: { $0.id == id }) else { throw DomainError.invalidReference }
            name = room.number
            removedRooms = [room]
            removedWork = work.filter { $0.roomID == id }
            removedAttachments = attachments.filter { $0.roomID == id }
        case .contract(let roomID):
            guard let room = rooms.first(where: { $0.id == roomID }), let terms = room.contract else {
                throw DomainError.invalidReference
            }
            name = room.number
            contract = terms
        case .equipment(let roomID, let id):
            guard let item = rooms.first(where: { $0.id == roomID })?.equipment.first(where: { $0.id == id }) else {
                throw DomainError.invalidReference
            }
            name = item.name
        case .work(let id):
            guard let item = work.first(where: { $0.id == id }) else { throw DomainError.invalidReference }
            name = item.title
            removedWork = [item]
            removedAttachments = attachments.filter { $0.workID == id }
        case .memo(let id):
            guard let memo = history.first(where: { $0.id == id }) else { throw DomainError.invalidReference }
            name = memo.text
        case .attachment(let id):
            guard let file = attachments.first(where: { $0.id == id }) else { throw DomainError.invalidReference }
            name = file.name
            attachment = file
            removedAttachments = [file]
        case .contact(let id):
            guard let contact = contacts.first(where: { $0.id == id }) else { throw DomainError.invalidReference }
            name = contact.name
            links.formUnion(buildings.filter { $0.agencyContactID == id }.map { .building($0.id) })
            links.formUnion(rooms.filter { $0.residentID == id }.map { .room($0.id) })
            links.formUnion(work.filter { $0.contractorID == id }.map { .work($0.id) })
            links.formUnion(history.filter { $0.contactID == id }.map { .memo($0.id) })
        }

        var affected: Set<RecordDeletionTarget> = [target]
        for room in removedRooms {
            affected.insert(.room(room.id))
            if room.contract != nil { affected.insert(.contract(roomID: room.id)) }
            affected.formUnion(room.equipment.map { .equipment(roomID: room.id, id: $0.id) })
        }
        let workIDs = Set(removedWork.map(\.id))
        affected.formUnion(removedWork.map { .work($0.id) })
        affected.formUnion(history.filter { workIDs.contains($0.workID) }.map { .memo($0.id) })
        affected.formUnion(removedAttachments.map { .attachment($0.id) })
        let kinds = Dictionary(removedAttachments.map { ($0.id, $0.kind) }, uniquingKeysWith: { first, _ in first })
        return RecordDeletionPlan(target: target, name: name, affected: affected,
                                  attachmentKinds: kinds, attachment: attachment, contract: contract, links: links)
    }

    public func deleting(_ approved: RecordDeletionPlan) throws -> Records {
        let current = try deletionPlan(for: approved.target)
        guard current == approved else { throw RecordDeletionError.changed(current) }
        if case .contact(let id) = current.target { return try removingContact(id) }

        var result = self
        let affected = current.affected
        result.buildings.removeAll { affected.contains(.building($0.id)) }
        result.rooms.removeAll { affected.contains(.room($0.id)) }
        result.work.removeAll { affected.contains(.work($0.id)) }
        result.history.removeAll { affected.contains(.memo($0.id)) }
        result.attachments.removeAll { affected.contains(.attachment($0.id)) }
        switch current.target {
        case .building(let id):
            for index in result.contacts.indices where result.contacts[index].buildingIDs.contains(id) {
                result.contacts[index].buildingIDs.removeAll { $0 == id }
            }
        case .contract(let roomID):
            guard let index = result.rooms.firstIndex(where: { $0.id == roomID }) else { throw DomainError.invalidReference }
            result.rooms[index].contract = nil
        case .equipment(let roomID, let id):
            guard let index = result.rooms.firstIndex(where: { $0.id == roomID }) else { throw DomainError.invalidReference }
            result.rooms[index].equipment.removeAll { $0.id == id }
        default: break
        }
        return try result.validated()
    }
}
