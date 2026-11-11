import Foundation

public struct Records: Codable, Equatable, Sendable {
    public var formatVersion = 1
    public var buildings: [Building] = []
    public var rooms: [Room] = []
    public var contacts: [Contact] = []
    public var work: [WorkItem] = []
    public var history: [HistoryEntry] = []
    public var attachments: [Attachment] = []

    public init() {}

    public func registering(_ draft: RegistrationDraft) throws -> Records {
        var result = self
        let building = Building(name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                                address: draft.address, management: draft.management)
        result.buildings.append(building)
        result.rooms.append(Room(buildingID: building.id,
                                 number: draft.roomNumber.trimmingCharacters(in: .whitespacesAndNewlines)))
        return try result.validated()
    }

    public func settingStatus(_ status: WorkStatus, for id: UUID) throws -> Records {
        var result = self
        guard let index = result.work.firstIndex(where: { $0.id == id }) else {
            throw DomainError.invalidReference
        }
        result.work[index].status = status
        return try result.validated()
    }

    public func confirmingRenewal(_ id: UUID) throws -> Records {
        var result = self
        guard let workIndex = work.firstIndex(where: { $0.id == id }),
              work[workIndex].kind == .renewal,
              let draft = work[workIndex].renewalDraft,
              let roomID = work[workIndex].roomID,
              let roomIndex = rooms.firstIndex(where: { $0.id == roomID }) else {
            throw DomainError.missingRenewal
        }
        result.rooms[roomIndex].contract = draft
        result.work[workIndex].status = .completed
        return try result.validated()
    }

    public func savingWork(_ item: WorkItem) throws -> Records {
        var result = self
        result.work.upsert(item)
        for index in result.attachments.indices where result.attachments[index].workID == item.id {
            result.attachments[index].buildingID = item.buildingID
            result.attachments[index].roomID = item.roomID
        }
        return try result.validated()
    }

    public func validated() throws -> Records {
        guard formatVersion == 1 else { throw DomainError.unsupportedFormat }
        try unique(buildings.map(\.id))
        try unique(rooms.map(\.id))
        try unique(contacts.map(\.id))
        try unique(work.map(\.id))
        try unique(history.map(\.id))
        try unique(attachments.map(\.id))
        let buildingIDs = Set(buildings.map(\.id))
        let contactIDs = Set(contacts.map(\.id))
        let workIDs = Set(work.map(\.id))
        for building in buildings {
            try required(building.name, .buildingName)
            try reference(building.agencyContactID, in: contactIDs)
        }
        var roomKeys = Set<String>()
        for room in rooms {
            try required(room.number, .roomNumber)
            guard buildingIDs.contains(room.buildingID) else { throw DomainError.invalidReference }
            let key = room.buildingID.uuidString + ":" + room.number.trimmingCharacters(in: .whitespaces).lowercased()
            guard roomKeys.insert(key).inserted else { throw DomainError.duplicateRoom }
            try reference(room.residentID, in: contactIDs)
            if let contract = room.contract { try validate(contract) }
            try unique(room.equipment.map(\.id))
            for equipment in room.equipment { try required(equipment.name, .equipmentName) }
        }
        for contact in contacts { try required(contact.name, .contactName) }
        for item in work {
            try required(item.title, .workTitle)
            try location(buildingID: item.buildingID, roomID: item.roomID)
            if item.kind == .renewal, item.roomID == nil { throw DomainError.missingRenewal }
            try reference(item.contractorID, in: contactIDs)
            try amount(item.estimate)
            if let draft = item.renewalDraft {
                guard item.kind == .renewal, item.roomID != nil else { throw DomainError.missingRenewal }
                try validate(draft)
            }
        }
        for entry in history {
            try required(entry.text, .historyText)
            guard workIDs.contains(entry.workID) else { throw DomainError.invalidReference }
            try reference(entry.contactID, in: contactIDs)
        }
        for attachment in attachments {
            try location(buildingID: attachment.buildingID, roomID: attachment.roomID)
            try reference(attachment.workID, in: workIDs)
            if let id = attachment.workID, let item = work.first(where: { $0.id == id }) {
                guard item.buildingID == attachment.buildingID, item.roomID == attachment.roomID else {
                    throw DomainError.invalidReference
                }
            }
            guard !attachment.name.isEmpty, Self.safeStoredName(attachment.storedName) else {
                throw DomainError.invalidAttachment
            }
        }
        return self
    }

    public func matchingWork(query: String, completed: Bool) -> [WorkItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return work.filter { item in
            guard (item.status == .completed) == completed else { return false }
            let building = buildings.first { $0.id == item.buildingID }?.name ?? ""
            let room = rooms.first { $0.id == item.roomID }?.number ?? ""
            return query.isEmpty || [item.title, item.notes, building, room]
                .contains { $0.localizedStandardContains(query) }
        }.sorted {
            if $0.dueDate != $1.dueDate { return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            return $0.receivedAt < $1.receivedAt
        }
    }

    public static func safeStoredName(_ name: String) -> Bool {
        let url = URL(fileURLWithPath: name)
        return name == url.lastPathComponent && UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
            && ["pdf", "jpg", "jpeg", "png", "heic", "txt"].contains(url.pathExtension.lowercased())
    }

    private func location(buildingID: UUID, roomID: UUID?) throws {
        guard buildings.contains(where: { $0.id == buildingID }) else { throw DomainError.invalidReference }
        if let roomID, !rooms.contains(where: { $0.id == roomID && $0.buildingID == buildingID }) {
            throw DomainError.invalidReference
        }
    }

    private func reference(_ id: UUID?, in identifiers: Set<UUID>) throws {
        if let id, !identifiers.contains(id) { throw DomainError.invalidReference }
    }

    private func unique(_ identifiers: [UUID]) throws {
        guard Set(identifiers).count == identifiers.count else { throw DomainError.duplicateIdentifier }
    }

    private func required(_ text: String, _ field: Field) throws {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw DomainError.required(field) }
    }

    private func amount(_ value: Int?) throws {
        if let value, !(0...1_000_000_000_000).contains(value) { throw DomainError.invalidAmount }
    }

    private func validate(_ contract: Contract) throws {
        guard contract.end >= contract.start else { throw DomainError.invalidDates }
        try amount(contract.monthlyRent)
    }
}

extension Array where Element: Identifiable {
    public mutating func upsert(_ element: Element) {
        if let index = firstIndex(where: { $0.id == element.id }) { self[index] = element }
        else { append(element) }
    }
}
