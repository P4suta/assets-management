import Foundation
import Testing
@testable import PropertyCore

@Suite struct ContactDirectoryTests {
    @Test func formatOneSnapshotsUpgradeWithoutLosingRecords() throws {
        var original = try completeRecords()
        original.formatVersion = 1
        var snapshot = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var contacts = try #require(snapshot["contacts"] as? [[String: Any]])
        for index in contacts.indices {
            contacts[index].removeValue(forKey: "category")
            contacts[index].removeValue(forKey: "isEmergency")
            contacts[index].removeValue(forKey: "buildingIDs")
        }
        snapshot["contacts"] = contacts
        let bytes = try JSONSerialization.data(withJSONObject: snapshot)
        let migrated = try JSONDecoder().decode(Records.self, from: bytes)
        var expected = original
        expected.formatVersion = 2
        #expect(migrated == expected)
        #expect(try migrated.validated() == expected)
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(migrated)) as? [String: Any])
        #expect(encoded["formatVersion"] as? Int == 2)
    }

    @Test(arguments: ContactCategory.allCases)
    func categoriesAndEmergencyPriorityRoundTrip(category: ContactCategory) throws {
        var records = try completeRecords()
        records.contacts[0].category = category
        records.contacts[0].isEmergency = true
        records.contacts[0].buildingIDs = [records.buildings[0].id]
        let bytes = try JSONEncoder().encode(records.validated())
        #expect(try JSONDecoder().decode(Records.self, from: bytes).validated() == records)
    }

    @Test func directorySearchCoversContactFieldsAndLinkedProperties() throws {
        var records = try completeRecords()
        let id = records.contacts[0].id
        records.contacts[0].name = "メンテナンス窓口"
        records.contacts[0].company = "Ｍｉｄｏｒｉ設備"
        records.contacts[0].phone = "０９０−１２３４−５６７８"
        records.contacts[0].email = "alerts@example.com"
        records.contacts[0].notes = "夜間の水漏れ受付"
        records.contacts[0].buildingIDs = [records.buildings[0].id]
        for query in ["窓口", "midori", "0901234", "ALERTS@", "夜間", records.buildings[0].name, "  "] {
            #expect(records.matchingContacts(query: query).map(\.id).contains(id), "Missing match for \(query)")
        }
        #expect(records.matchingContacts(query: "該当する連絡先なし").isEmpty)
    }

    @Test func emergencyContactsSortBeforeOtherServicesWithStableTies() throws {
        var records = try fixtureRecords()
        let firstID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10))
        let secondID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11))
        let urgentID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12))
        records.contacts = [Contact(id: secondID, name: "保険窓口"),
                            Contact(id: firstID, name: "保険窓口"),
                            Contact(id: urgentID, name: "設備窓口", category: .maintenance, isEmergency: true)]
        #expect(records.matchingContacts(query: "").map(\.id) == [urgentID, firstID, secondID])
        #expect(records.contacts[2].category == .maintenance)
    }

    @Test func relatedBuildingsCombineExplicitAndExistingAssignments() throws {
        var records = try completeRecords().registering(RegistrationDraft(name: "青葉コート", roomNumber: "101"))
        let id = records.contacts[0].id
        records.rooms[0].residentID = id
        records.buildings[0].agencyContactID = id
        records.contacts[0].buildingIDs = [records.buildings[0].id, records.buildings[1].id]
        #expect(records.relatedBuildings(for: id).map(\.id) == records.buildings.map(\.id))
        #expect(records.relatedBuildings(for: UUID()).isEmpty)
    }

    @Test(arguments: 0..<4)
    func legacyAssignmentsIndependentlyAssociateAContactWithItsBuilding(assignment: Int) throws {
        var records = try completeRecords()
        let id = records.contacts[0].id
        records.buildings[0].agencyContactID = nil
        records.rooms[0].residentID = nil
        records.work[0].contractorID = nil
        records.history[0].contactID = nil
        #expect(records.relatedBuildings(for: id).isEmpty)
        switch assignment {
        case 0: records.buildings[0].agencyContactID = id
        case 1: records.rooms[0].residentID = id
        case 2: records.work[0].contractorID = id
        default: records.history[0].contactID = id
        }
        #expect(records.relatedBuildings(for: id).map(\.id) == [records.buildings[0].id])
    }

    @Test func deletingAContactClearsAssignmentsWithoutRemovingOtherRecords() throws {
        var records = try completeRecords()
        let id = records.contacts[0].id
        records.rooms[0].residentID = id
        records.buildings[0].agencyContactID = id
        records.work[0].contractorID = id
        records.history[0].contactID = id
        let original = records
        let result = try records.removingContact(id)
        #expect(!result.contacts.contains { $0.id == id })
        #expect(result.rooms[0].residentID == nil)
        #expect(result.buildings[0].agencyContactID == nil)
        #expect(result.work[0].contractorID == nil)
        #expect(result.history[0].contactID == nil)
        #expect(result.rooms[0].contract == original.rooms[0].contract)
        #expect(result.work[0].title == original.work[0].title)
        #expect(result.history[0].text == original.history[0].text)
        #expect(result.attachments == original.attachments)
        #expect(try result.validated() == result)
        #expect(records == original)
        #expect(throws: DomainError.invalidReference) { try records.removingContact(UUID()) }
    }

    @Test func contactPropertyLinksRejectMissingAndDuplicateBuildings() throws {
        var records = try completeRecords()
        records.contacts[0].buildingIDs = [records.buildings[0].id, UUID()]
        #expect(throws: DomainError.invalidReference) { try records.validated() }
        records.contacts[0].buildingIDs = [records.buildings[0].id, records.buildings[0].id]
        #expect(throws: DomainError.duplicateIdentifier) { try records.validated() }
    }
}
