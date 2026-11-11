import Foundation
import Testing
@testable import PropertyCore

private enum Command {
    case status(WorkStatus), move(Int), confirm

    static var alphabet: [Self] {
        WorkStatus.allCases.map(Self.status) + [.move(0), .move(1), .confirm]
    }
}

private func transitionFixture(kind: WorkKind) throws -> Records {
    var records = try fixtureRecords()
    let building = Building(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4)), name: "青葉コート")
    let room = Room(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)), buildingID: building.id, number: "101")
    records.buildings.append(building)
    records.rooms.append(room)
    records.work[0].kind = kind
    if kind == .renewal {
        records.work[0].renewalDraft = Contract(start: Date(timeIntervalSince1970: 1_800_086_400),
                                               end: Date(timeIntervalSince1970: 1_860_000_000), monthlyRent: 85_000)
    }
    records.history = [HistoryEntry(workID: records.work[0].id, date: Date(timeIntervalSince1970: 1_700_000_100), text: "受付")]
    records.attachments = [Attachment(buildingID: records.buildings[0].id, roomID: records.rooms[0].id,
                                     workID: records.work[0].id, kind: .document, name: "見積書.pdf",
                                     storedName: "00000000-0000-0000-0000-000000000006.pdf",
                                     createdAt: Date(timeIntervalSince1970: 1_700_000_200))]
    return try records.validated()
}

@Suite struct TransitionModelTests {
    @Test(arguments: WorkKind.allCases)
    func allThreeCommandTracesPreserveLinkedRecords(kind: WorkKind) throws {
        let original = try transitionFixture(kind: kind)
        let commands = Command.alphabet
        let traceCount = commands.count * commands.count * commands.count
        for trace in 0..<traceCount {
            var actual = original
            var expected = original
            var remaining = trace
            for step in 0..<3 {
                let command = commands[remaining % commands.count]
                remaining /= commands.count
                switch command {
                case .status(let status):
                    expected.work[0].status = status
                    actual = try actual.settingStatus(status, for: original.work[0].id)
                case .move(let target):
                    expected.work[0].buildingID = original.buildings[target].id
                    expected.work[0].roomID = original.rooms[target].id
                    expected.attachments[0].buildingID = original.buildings[target].id
                    expected.attachments[0].roomID = original.rooms[target].id
                    var moved = actual.work[0]
                    moved.buildingID = original.buildings[target].id
                    moved.roomID = original.rooms[target].id
                    actual = try actual.savingWork(moved)
                case .confirm:
                    if kind == .renewal {
                        if expected.work[0].status != .completed {
                            let target = expected.work[0].roomID == original.rooms[0].id ? 0 : 1
                            expected.rooms[target].contract = original.work[0].renewalDraft
                            expected.work[0].status = .completed
                        }
                        actual = try actual.confirmingRenewal(original.work[0].id)
                    } else {
                        #expect(throws: DomainError.missingRenewal) { try actual.confirmingRenewal(original.work[0].id) }
                    }
                }
                #expect(actual == expected, "Kind \(kind), trace \(trace), step \(step)")
                let active = actual.matchingWork(query: "", completed: false).map(\.id)
                let completed = actual.matchingWork(query: "", completed: true).map(\.id)
                #expect(active + completed == [original.work[0].id])
                #expect(completed.isEmpty == (expected.work[0].status != .completed))
            }
        }
    }

    @Test func rejectedCommandsPreserveTheirInput() throws {
        let original = try transitionFixture(kind: .repair)
        #expect(throws: DomainError.invalidReference) { try original.settingStatus(.completed, for: UUID()) }
        var misplaced = original.work[0]
        misplaced.buildingID = original.buildings[1].id
        #expect(throws: DomainError.invalidReference) { try original.savingWork(misplaced) }
        #expect(try original.validated() == original)
    }
}
