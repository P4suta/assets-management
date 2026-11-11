import Foundation
import Testing
@testable import PropertyCore

func fixtureRecords() throws -> Records {
    var records = try Records().registering(RegistrationDraft(name: "桜通りレジデンス", roomNumber: "203"))
    let building = try #require(records.buildings.first)
    var room = try #require(records.rooms.first)
    room.contract = Contract(start: Date(timeIntervalSince1970: 1_700_000_000),
                             end: Date(timeIntervalSince1970: 1_800_000_000), monthlyRent: 82_000)
    records.rooms[0] = room
    records.work = [WorkItem(buildingID: building.id, roomID: room.id, title: "給湯器から水漏れ", estimate: 38_500)]
    return records
}

@Test func duplicateRoomsAreRejectedWithinABuilding() throws {
    var records = try fixtureRecords()
    let original = try #require(records.rooms.first)
    records.rooms.append(Room(buildingID: original.buildingID, number: " 203 "))
    #expect(throws: DomainError.duplicateRoom) { try records.validated() }
}

@Test func sameRoomNumberCanExistInAnotherBuilding() throws {
    let records = try fixtureRecords().registering(RegistrationDraft(name: "青葉コート", roomNumber: "203"))
    #expect(records.rooms.count == 2)
}

@Test func roomCannotReferToAnotherBuildingsWork() throws {
    var records = try fixtureRecords().registering(RegistrationDraft(name: "青葉コート", roomNumber: "201"))
    records.work[0].buildingID = records.buildings[1].id
    #expect(throws: DomainError.invalidReference) { try records.validated() }
}

@Test func commonAreaRepairDoesNotRequireARoom() throws {
    var records = try fixtureRecords()
    records.work[0].roomID = nil
    #expect(try records.validated().work[0].roomID == nil)
}

@Test func completionAndReopeningPreserveEstimateAndHistory() throws {
    var records = try fixtureRecords()
    let item = try #require(records.work.first)
    records.history = [HistoryEntry(workID: item.id, text: "業者へ連絡")]
    let completed = try records.settingStatus(.completed, for: item.id)
    #expect(completed.work[0].estimate == 38_500)
    #expect(completed.history == records.history)
    #expect(completed.matchingWork(query: "", completed: false).isEmpty)
    #expect(completed.matchingWork(query: "", completed: true).count == 1)
    #expect(try completed.settingStatus(.inProgress, for: item.id).work[0].status == .inProgress)
}

@Test func renewalDraftDoesNotReplaceSignedContract() throws {
    var records = try fixtureRecords()
    let signed = records.rooms[0].contract
    records.work[0].kind = .renewal
    let draft = Contract(start: Date(timeIntervalSince1970: 1_800_086_400),
                         end: Date(timeIntervalSince1970: 1_860_000_000), monthlyRent: 85_000)
    records.work[0].renewalDraft = draft
    _ = try records.validated()
    #expect(records.rooms[0].contract == signed)
    let confirmed = try records.confirmingRenewal(records.work[0].id)
    #expect(confirmed.rooms[0].contract == draft)
    #expect(confirmed.work[0].status == .completed)
}

@Test func renewalCannotBeConfirmedWithoutRoomAndTerms() throws {
    var records = try fixtureRecords()
    records.work[0].kind = .renewal
    #expect(throws: DomainError.missingRenewal) { try records.confirmingRenewal(records.work[0].id) }
}

@Test func contractDatesAndAmountsAreValidated() throws {
    var records = try fixtureRecords()
    records.rooms[0].contract = Contract(start: .distantFuture, end: .distantPast)
    #expect(throws: DomainError.invalidDates) { try records.validated() }
    records.rooms[0].contract = Contract(start: .distantPast, end: .distantFuture, monthlyRent: -1)
    #expect(throws: DomainError.invalidAmount) { try records.validated() }
}

@Test func searchFindsBuildingRoomAndJapaneseContent() throws {
    let records = try fixtureRecords()
    for query in ["桜通り", "203", "水漏れ"] {
        #expect(records.matchingWork(query: query, completed: false).count == 1)
    }
    #expect(records.matchingWork(query: "該当なし", completed: false).isEmpty)
}

@Test func deadlinesSortBeforeUndatedWork() throws {
    var records = try fixtureRecords()
    var first = records.work[0]
    first.id = UUID()
    first.title = "期限あり"
    first.dueDate = .distantPast
    records.work.append(first)
    #expect(records.matchingWork(query: "", completed: false).first?.id == first.id)
}

@Test func identifiersAndReferencesCannotBeDuplicatedOrDangling() throws {
    var records = try fixtureRecords()
    records.buildings.append(records.buildings[0])
    #expect(throws: DomainError.duplicateIdentifier) { try records.validated() }
    records.buildings.removeLast()
    records.rooms[0].residentID = UUID()
    #expect(throws: DomainError.invalidReference) { try records.validated() }
}

@Test func attachmentCannotEscapeContainerOrCrossProperties() throws {
    var records = try fixtureRecords()
    let item = records.work[0]
    records.attachments = [Attachment(buildingID: item.buildingID, roomID: item.roomID, workID: item.id,
                                      kind: .document, name: "契約書.pdf", storedName: "../records.json")]
    #expect(throws: DomainError.invalidAttachment) { try records.validated() }
    records.attachments[0].storedName = UUID().uuidString + ".pdf"
    records.attachments[0].roomID = nil
    #expect(throws: DomainError.invalidReference) { try records.validated() }
}

@Test func futureFormatsFailClosed() {
    var records = Records()
    records.formatVersion = 2
    #expect(throws: DomainError.unsupportedFormat) { try records.validated() }
}

@Test func movingWorkRelocatesItsAttachmentsAtomically() throws {
    var records = try fixtureRecords().registering(RegistrationDraft(name: "青葉コート", roomNumber: "201"))
    var item = records.work[0]
    records.attachments = [Attachment(buildingID: item.buildingID, roomID: item.roomID, workID: item.id,
                                      kind: .photo, name: "写真.jpg", storedName: UUID().uuidString + ".jpg")]
    item.buildingID = records.buildings[1].id
    item.roomID = records.rooms[1].id
    let moved = try records.savingWork(item)
    #expect(moved.attachments[0].buildingID == item.buildingID)
    #expect(moved.attachments[0].roomID == item.roomID)
    #expect(moved.history == records.history)
    #expect(moved.rooms == records.rooms)
}

@Test func renewalRequiresASpecificRoom() throws {
    var records = try fixtureRecords()
    records.work[0].kind = .renewal
    records.work[0].roomID = nil
    #expect(throws: DomainError.missingRenewal) { try records.validated() }
}
