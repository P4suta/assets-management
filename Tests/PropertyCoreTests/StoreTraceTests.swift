import Foundation
import Testing
@testable import PropertyCore

@Suite @MainActor struct StoreTraceTests {
    @Test func loadFailuresEmitTheirCategoryWithoutPublishingRecords() async throws {
        var events: [RecordsEvent] = []
        let repository = ControlledRepository(try fixtureRecords(), failures: [.load: .unreadable])
        let store = RecordsStore(repository: repository) { events.append($0) }
        #expect(events.isEmpty)
        await store.load()
        #expect(events == [.loadFailed(errorType: String(reflecting: StorageError.self))])
        #expect(store.records == Records())
        #expect(!store.isLoading)
        #expect(!store.isSaving)
    }

    @Test func saveTracesCorrelateFailureAndRetryWithTheirOwnOperations() async throws {
        var events: [RecordsEvent] = []
        let original = try fixtureRecords()
        let repository = ControlledRepository(original, failures: [.save: .unwritable])
        let store = RecordsStore(repository: repository) { events.append($0) }
        await store.load()
        await #expect(throws: StorageError.unwritable) { try await store.save { $0 } }
        guard case .saving(let failedID) = events.first else {
            Issue.record("Saving must emit a start event.")
            return
        }
        #expect(events == [.saving(operationID: failedID),
                           .saveFailed(operationID: failedID, errorType: String(reflecting: StorageError.self))])
        await repository.clearFailures()
        try await store.save { try $0.settingStatus(.completed, for: original.work[0].id) }
        guard case .saved(let savedID) = events.last else {
            Issue.record("A committed save must emit its completion event.")
            return
        }
        #expect(events.count == 4)
        #expect(events[2] == .saving(operationID: savedID))
        #expect(store.records.work[0].status == .completed)
    }
}
