import Foundation
import PropertyCore
import Testing
@testable import PropertyRecords

@Suite struct SampleRecordsTests {
    @Test(arguments: [Date(timeIntervalSince1970: 1_794_384_000), Date(timeIntervalSince1970: 1_794_445_200),
                      Date(timeIntervalSince1970: 2_000_000_000)])
    func notificationJourneysUseAnExplicitTemporalFixture(now: Date) throws {
        for past in [false, true] {
            let records = try SampleRecords.make(now: now, pastVisit: past)
            let visit = try #require(records.work.first?.nextVisit)
            let deadline = try #require(records.work.first?.dueDate)
            #expect((visit < now) == past)
            #expect((deadline < now) == past)
            #expect(abs(visit.timeIntervalSince(now)) < 172_800)
            #expect(abs(deadline.timeIntervalSince(now)) < 172_800)
            #expect(try records.validated() == records)
        }
    }
}
