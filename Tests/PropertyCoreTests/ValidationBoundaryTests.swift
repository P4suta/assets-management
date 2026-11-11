import Foundation
import Testing
@testable import PropertyCore

func completeRecords() throws -> Records {
    var records = try fixtureRecords()
    let contact = Contact(name: "連絡先")
    records.contacts = [contact]
    records.buildings[0].agencyContactID = contact.id
    records.rooms[0].residentID = contact.id
    records.rooms[0].equipment = [Equipment(name: "給湯器", installedOn: Date(timeIntervalSince1970: 1_600_000_000))]
    records.work[0].kind = .renewal
    records.work[0].contractorID = contact.id
    records.work[0].dueDate = Date(timeIntervalSince1970: 1_750_000_000)
    records.work[0].nextVisit = Date(timeIntervalSince1970: 1_740_000_000)
    records.work[0].renewalDraft = Contract(start: Date(timeIntervalSince1970: 1_800_086_400),
                                         end: Date(timeIntervalSince1970: 1_860_000_000), monthlyRent: 85_000)
    records.history = [HistoryEntry(workID: records.work[0].id, contactID: contact.id, text: "連絡内容")]
    records.attachments = [Attachment(buildingID: records.buildings[0].id, roomID: records.rooms[0].id,
                                     workID: records.work[0].id, kind: .document, name: "書類.pdf",
                                     storedName: UUID().uuidString + ".pdf")]
    return try records.validated()
}

private enum DateSlot: CaseIterable {
    case contractStart, contractEnd, renewalStart, renewalEnd, installed, received, due, visit, history, attachment

    func replace(in records: inout Records, with date: Date) {
        switch self {
        case .contractStart: records.rooms[0].contract?.start = date
        case .contractEnd: records.rooms[0].contract?.end = date
        case .renewalStart: records.work[0].renewalDraft?.start = date
        case .renewalEnd: records.work[0].renewalDraft?.end = date
        case .installed: records.rooms[0].equipment[0].installedOn = date
        case .received: records.work[0].receivedAt = date
        case .due: records.work[0].dueDate = date
        case .visit: records.work[0].nextVisit = date
        case .history: records.history[0].date = date
        case .attachment: records.attachments[0].createdAt = date
        }
    }
}

@Suite struct ValidationBoundaryTests {
    @Test(arguments: DateSlot.allCases, [Double.nan, .infinity, -.infinity])
    private func datesMustBeFinite(slot: DateSlot, interval: Double) throws {
        var records = try completeRecords()
        slot.replace(in: &records, with: Date(timeIntervalSince1970: interval))
        #expect(throws: DomainError.invalidDates) { try records.validated() }
    }

    @Test(arguments: ["203\n", "\r203", "\t203\u{3000}", "\u{00A0}203\u{00A0}"])
    func surroundingWhitespaceDoesNotCreateADifferentRoom(number: String) throws {
        var records = try fixtureRecords()
        records.rooms.append(Room(buildingID: records.buildings[0].id, number: number))
        #expect(throws: DomainError.duplicateRoom) { try records.validated() }
    }

    @Test func undatedWorkFollowsEveryFiniteDeadline() throws {
        var records = try fixtureRecords()
        var dated = records.work[0]
        dated.id = UUID()
        dated.title = "期限あり"
        dated.dueDate = Date.distantFuture.addingTimeInterval(86_400)
        records.work.append(dated)
        let sorted = records.matchingWork(query: "", completed: false)
        #expect(sorted.map(\.id) == [dated.id, records.work[0].id])
    }

    @Test func confirmingACompletedRenewalNeverReplacesALaterContract() throws {
        let records = try completeRecords()
        let id = records.work[0].id
        var confirmed = try records.confirmingRenewal(id)
        confirmed.rooms[0].contract = Contract(start: Date(timeIntervalSince1970: 1_900_000_000),
                                              end: Date(timeIntervalSince1970: 1_960_000_000), monthlyRent: 90_000)
        #expect(try confirmed.confirmingRenewal(id) == confirmed)
    }

    @Test(arguments: [Int.min, -1, 1_000_000_000_001, Int.max])
    func everyAmountBoundaryRejectsInvalidValues(amount: Int) throws {
        let original = try completeRecords()
        var records = original
        records.rooms[0].contract?.monthlyRent = amount
        #expect(throws: DomainError.invalidAmount) { try records.validated() }
        records = original
        records.work[0].estimate = amount
        #expect(throws: DomainError.invalidAmount) { try records.validated() }
        records = original
        records.work[0].renewalDraft?.monthlyRent = amount
        #expect(throws: DomainError.invalidAmount) { try records.validated() }
    }

    @Test(arguments: [0, 1, 1_000_000_000_000, nil] as [Int?])
    func amountBoundaryEndpointsRemainValid(amount: Int?) throws {
        var records = try completeRecords()
        records.rooms[0].contract?.monthlyRent = amount
        records.work[0].estimate = amount
        records.work[0].renewalDraft?.monthlyRent = amount
        #expect(try records.validated() == records)
    }

    @Test(arguments: ["", " ", "\n\t", "\u{3000}\u{00A0}"])
    func everyRequiredFieldRejectsBlankText(text: String) throws {
        let original = try completeRecords()
        var records = original
        records.buildings[0].name = text
        #expect(throws: DomainError.required(.buildingName)) { try records.validated() }
        records = original
        records.rooms[0].number = text
        #expect(throws: DomainError.required(.roomNumber)) { try records.validated() }
        records = original
        records.work[0].title = text
        #expect(throws: DomainError.required(.workTitle)) { try records.validated() }
        records = original
        records.contacts[0].name = text
        #expect(throws: DomainError.required(.contactName)) { try records.validated() }
        records = original
        records.history[0].text = text
        #expect(throws: DomainError.required(.historyText)) { try records.validated() }
        records = original
        records.rooms[0].equipment[0].name = text
        #expect(throws: DomainError.required(.equipmentName)) { try records.validated() }
    }
}
