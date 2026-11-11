import Foundation
import Testing
@testable import PropertyCore

@Suite struct SerializationTests {
    @Test(arguments: ManagementMode.allCases, WorkKind.allCases)
    func everyPersistedVariantRoundTrips(management: ManagementMode, kind: WorkKind) throws {
        for status in WorkStatus.allCases {
            for method in CommunicationMethod.allCases {
                for attachmentKind in [AttachmentKind.document, .photo] {
                    var records = try completeRecords()
                    records.buildings[0].management = management
                    records.work[0].kind = kind
                    records.work[0].status = status
                    if kind != .renewal { records.work[0].renewalDraft = nil }
                    records.history[0].method = method
                    records.attachments[0].kind = attachmentKind
                    let encoded = try JSONEncoder().encode(records.validated())
                    #expect(try JSONDecoder().decode(Records.self, from: encoded).validated() == records)
                }
            }
        }
    }
}
