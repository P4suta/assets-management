import Foundation
import Testing
@testable import PropertyCore

private func orderedWorkFixture() throws -> [WorkItem] {
    let original = try fixtureRecords().work[0]
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    return (0..<6).map { index in
        var item = original
        item.id = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(index + 1)))
        item.dueDate = index < 3 ? date : index == 3 ? date.addingTimeInterval(60) : nil
        item.receivedAt = date.addingTimeInterval(index == 0 || index == 4 ? -60 : 0)
        return item
    }
}

private func permutations<Element>(_ elements: [Element]) -> [[Element]] {
    guard !elements.isEmpty else { return [[]] }
    return elements.indices.flatMap { index in
        var rest = elements
        let first = rest.remove(at: index)
        return permutations(rest).map { [first] + $0 }
    }
}

@Suite struct OrderingContractTests {
    @Test func everyWorkPermutationHasTheSameDeadlineReceiptAndIdentifierOrder() throws {
        let ordered = try orderedWorkFixture()
        var records = try fixtureRecords()
        for input in permutations(ordered) {
            records.work = input
            #expect(records.matchingWork(query: "", completed: false).map(\.id) == ordered.map(\.id))
        }
        for left in ordered.indices {
            for right in ordered.indices {
                let expected: ComparisonResult = left == right ? .orderedSame : left < right ? .orderedAscending : .orderedDescending
                #expect(ordered[left].compareForDisplay(to: ordered[right]) == expected)
            }
        }
    }

    @Test func notificationOrderIsChronologicalAndStableForSharedTimes() throws {
        var records = try fixtureRecords()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        records.work = try orderedWorkFixture()
        for index in records.work.indices {
            records.work[index].reminderEnabled = false
            records.work[index].visitReminderEnabled = true
            records.work[index].nextVisit = date.addingTimeInterval(index < 3 ? 300 : 600)
        }
        let expectedIDs = records.work.map { $0.id.uuidString + ".visit" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let plan = try ReminderPlan(records: records, now: date, calendar: calendar)
        for input in permutations(records.work) {
            records.work = input
            let reordered = try ReminderPlan(records: records, now: date, calendar: calendar)
            #expect(reordered.requests.map(\.identifier) == expectedIDs)
        }
        for left in plan.requests.indices {
            for right in plan.requests.indices {
                let expected: ComparisonResult = left == right ? .orderedSame : left < right ? .orderedAscending : .orderedDescending
                #expect(plan.requests[left].compareForRegistration(to: plan.requests[right]) == expected)
            }
        }
    }

    @Test func storedNamesRejectEachIndependentInvalidPart() {
        let id = "00000000-0000-0000-0000-000000000001"
        for ext in ["pdf", "jpg", "jpeg", "png", "heic", "txt"] {
            #expect(Records.safeStoredName(id + "." + ext))
            #expect(Records.safeStoredName(id + "." + ext.uppercased()))
            #expect(!Records.safeStoredName("../" + id + "." + ext))
            #expect(!Records.safeStoredName("folder/" + id + "." + ext))
            #expect(!Records.safeStoredName("not-an-identifier." + ext))
        }
        for ext in ["", "exe", "json", "pdf.exe", "pdf/", "pdf\n"] {
            #expect(!Records.safeStoredName(id + "." + ext))
        }
    }

    @Test func aSameDayContractAndNewWorkRemainSupported() throws {
        var records = try fixtureRecords()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        records.rooms[0].contract = Contract(start: date, end: date)
        #expect(try records.validated() == records)
        let added = WorkItem(buildingID: records.buildings[0].id, title: "共用照明の点検")
        #expect(!added.reminderEnabled)
        #expect(!added.visitReminderEnabled)
        let saved = try records.savingWork(added)
        #expect(saved.work == records.work + [added])
    }
}
