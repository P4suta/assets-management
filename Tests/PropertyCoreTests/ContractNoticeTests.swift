import Foundation
import Testing
@testable import PropertyCore

@Suite struct ContractNoticeTests {
    private func date(_ value: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: value))
    }

    private func calendar(_ zone: String = "Asia/Tokyo") throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        return calendar
    }

    @Test func explicitDeadlineNeverChangesWithExpiry() throws {
        let deadline = try date("2027-02-01T00:00:00Z")
        let notice = ContractNotice(timing: .date(deadline))
        for expiry in ["2027-08-01T00:00:00Z", "2028-01-31T00:00:00Z"] {
            #expect(notice.deadline(expiry: try date(expiry), calendar: try calendar()) == deadline)
        }
    }

    @Test(arguments: [("2028-08-31T03:00:00Z", 6, "2028-02-29T03:00:00Z"),
                      ("2027-08-31T03:00:00Z", 6, "2027-02-28T03:00:00Z"),
                      ("2027-03-31T03:00:00Z", 1, "2027-02-28T03:00:00Z")])
    func relativeDeadlineUsesCalendarMonths(example: (String, Int, String)) throws {
        let notice = ContractNotice(timing: .monthsBeforeExpiry(example.1))
        #expect(notice.deadline(expiry: try date(example.0), calendar: try calendar()) == (try date(example.2)))
    }

    @Test func invalidNoticeInputsAreRejectedBeforeSaving() throws {
        for timing in [ContractNoticeTiming.monthsBeforeExpiry(0), .monthsBeforeExpiry(Int.max),
                       .date(Date(timeIntervalSince1970: .infinity))] {
            var records = try completeRecords()
            records.rooms[0].contract?.notice = ContractNotice(timing: timing)
            #expect(throws: DomainError.invalidNotice) { try records.validated() }
        }
        for days in [-1, 366, Int.max] {
            var records = try completeRecords()
            records.rooms[0].contract?.notice = ContractNotice(timing: .monthsBeforeExpiry(6), advanceDays: days)
            #expect(throws: DomainError.invalidNotice) { try records.validated() }
        }
    }

    @Test(arguments: [ContractNoticeTiming.date(Date(timeIntervalSince1970: 1_900_000_000)), .monthsBeforeExpiry(6)])
    func noticeRoundTripsWithItsContract(timing: ContractNoticeTiming) throws {
        var records = try completeRecords()
        records.rooms[0].contract?.notice = ContractNotice(timing: timing, advanceDays: 90, reminderEnabled: true)
        let bytes = try JSONEncoder().encode(records.validated())
        #expect(try JSONDecoder().decode(Records.self, from: bytes).validated() == records)
    }
}
