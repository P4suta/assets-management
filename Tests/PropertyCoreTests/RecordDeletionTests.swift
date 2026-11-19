import Foundation
import Testing
@testable import PropertyCore

@Suite struct RecordDeletionTests {
    @Test func deletingABuildingRemovesAllItsRecordsAndKeepsSharedContacts() throws {
        let records = try deletionFixture()
        let building = records.buildings[0]
        let room = records.rooms[0]
        let plan = try records.deletionPlan(for: .building(building.id))
        #expect(plan.name == building.name)
        #expect(plan.affected.contains(.contract(roomID: room.id)))
        #expect(plan.affected.contains(.equipment(roomID: room.id, id: room.equipment[0].id)))
        #expect(plan.affected.count == 10)
        let result = try records.deleting(plan)
        #expect(result.buildings == [records.buildings[1]])
        #expect(result.rooms == [records.rooms[1]])
        #expect(result.work == [records.work[2]])
        #expect(result.history.isEmpty)
        #expect(result.attachments == [records.attachments[3]])
        #expect(result.contacts.map(\.id) == records.contacts.map(\.id))
        #expect(result.contacts[0].buildingIDs == [records.buildings[1].id])
        #expect(try result.validated() == result)
    }

    @Test func deletingTheLastRoomKeepsCommonAreaWorkAndFiles() throws {
        let records = try deletionFixture()
        let result = try records.deleting(records.deletionPlan(for: .room(records.rooms[0].id)))
        #expect(result.buildings == records.buildings)
        #expect(result.rooms == [records.rooms[1]])
        #expect(result.work == Array(records.work.dropFirst()))
        #expect(result.attachments == [records.attachments[0], records.attachments[3]])
        #expect(result.contacts == records.contacts)
        #expect(try result.validated() == result)
    }

    @Test(arguments: WorkKind.allCases, WorkStatus.allCases)
    func workDeletionKeepsTheSignedContractAndOtherRecords(kind: WorkKind, status: WorkStatus) throws {
        var records = try deletionFixture()
        records.work[0].kind = kind
        records.work[0].status = status
        let result = try records.deleting(records.deletionPlan(for: .work(records.work[0].id)))
        #expect(result.rooms == records.rooms)
        #expect(result.work == Array(records.work.dropFirst()))
        #expect(result.history.isEmpty)
        #expect(result.attachments == [records.attachments[0], records.attachments[1], records.attachments[3]])
        #expect(result.contacts == records.contacts)
    }

    @Test func individualDeletionUsesTheSameIntegrityRules() throws {
        let records = try deletionFixture()
        let room = records.rooms[0]
        let contract = try records.deleting(records.deletionPlan(for: .contract(roomID: room.id)))
        #expect(contract.rooms[0].contract == nil)
        #expect(contract.work == records.work)
        #expect(contract.attachments == records.attachments)
        let equipment = try records.deleting(records.deletionPlan(for: .equipment(roomID: room.id, id: room.equipment[0].id)))
        #expect(equipment.rooms[0].equipment.isEmpty)
        #expect(equipment.rooms[0].contract == room.contract)
        let memo = try records.deleting(records.deletionPlan(for: .memo(records.history[0].id)))
        #expect(memo.history.isEmpty)
        #expect(memo.work == records.work)
        for attachment in records.attachments {
            let afterDeletion = try records.deleting(records.deletionPlan(for: .attachment(attachment.id)))
            #expect(afterDeletion.attachments == records.attachments.filter { $0.id != attachment.id })
            #expect(afterDeletion.work == records.work)
        }
        let id = records.contacts[0].id
        let contact = try records.deleting(records.deletionPlan(for: .contact(id)))
        #expect(contact == (try records.removingContact(id)))
    }

    @Test func changedScopeRequiresConfirmationEvenWithTheSameCounts() throws {
        let records = try deletionFixture()
        let plan = try records.deletionPlan(for: .building(records.buildings[0].id))
        var changed = records
        changed.attachments[0].id = UUID()
        let current = try changed.deletionPlan(for: plan.target)
        #expect(current.affected.count == plan.affected.count)
        #expect(throws: RecordDeletionError.changed(current)) { try changed.deleting(plan) }
        let deleted = try changed.deleting(current)
        #expect(throws: DomainError.invalidReference) { try deleted.deleting(current) }
    }

    @Test func replacementContractRequiresNewConfirmation() throws {
        let records = try deletionFixture()
        let plan = try records.deletionPlan(for: .contract(roomID: records.rooms[0].id))
        var changed = records
        changed.rooms[0].contract?.monthlyRent = 90_000
        let current = try changed.deletionPlan(for: plan.target)
        #expect(throws: RecordDeletionError.changed(current)) { try changed.deleting(plan) }
    }

    private func deletionFixture() throws -> Records {
        var records = try fixtureRecords().registering(RegistrationDraft(name: "別棟", roomNumber: "203"))
        let building = records.buildings[0]
        let room = records.rooms[0]
        let work = records.work[0]
        let contact = Contact(name: "設備会社", buildingIDs: records.buildings.map(\.id))
        records.contacts = [contact]
        records.buildings[0].agencyContactID = contact.id
        records.rooms[0].residentID = contact.id
        records.rooms[0].equipment = [Equipment(name: "給湯器")]
        records.work[0].contractorID = contact.id
        records.work.append(WorkItem(buildingID: building.id, kind: .inspection, title: "共用灯点検"))
        records.work.append(WorkItem(buildingID: records.buildings[1].id, title: "別棟の修繕"))
        records.history = [HistoryEntry(workID: work.id, contactID: contact.id, text: "点検済み")]
        records.attachments = [
            Attachment(buildingID: building.id, kind: .photo, name: "建物", storedName: UUID().uuidString + ".jpg"),
            Attachment(buildingID: building.id, roomID: room.id, kind: .photo, name: "部屋", storedName: UUID().uuidString + ".jpg"),
            Attachment(buildingID: building.id, roomID: room.id, workID: work.id, kind: .document,
                       name: "見積書", storedName: UUID().uuidString + ".pdf"),
            Attachment(buildingID: records.buildings[1].id, kind: .photo, name: "別棟", storedName: UUID().uuidString + ".jpg")
        ]
        return try records.validated()
    }
}
