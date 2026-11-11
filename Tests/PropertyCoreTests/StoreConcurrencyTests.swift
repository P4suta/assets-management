import Foundation
import Testing

@testable import PropertyCore

enum RepositoryOperation: Hashable, Sendable {
  case load, save, write, remove
}

actor ControlledRepository: RecordsRepository {
  private(set) var stored: Records
  private(set) var files: [String: Data] = [:]
  private var suspended: Set<RepositoryOperation>
  private var failures: [RepositoryOperation: StorageError]
  private var counts: [RepositoryOperation: Int] = [:]
  private var arrivals: [RepositoryOperation: [CheckedContinuation<Void, Never>]] = [:]
  private var resumes: [RepositoryOperation: [CheckedContinuation<Void, Never>]] = [:]

  init(
    _ stored: Records, suspended: Set<RepositoryOperation> = [],
    failures: [RepositoryOperation: StorageError] = [:]
  ) {
    self.stored = stored
    self.suspended = suspended
    self.failures = failures
  }

  func load() async throws -> Records {
    let snapshot = stored
    try await checkpoint(.load)
    return snapshot
  }

  func save(_ records: Records) async throws {
    try await checkpoint(.save)
    stored = records
  }

  func writeAttachment(_ data: Data, extension fileExtension: String) async throws -> String {
    try await checkpoint(.write)
    let name = UUID().uuidString + "." + fileExtension
    files[name] = data
    return name
  }

  func attachmentURL(named name: String) throws -> URL {
    guard files[name] != nil else { throw StorageError.missingAttachment }
    return URL.temporaryDirectory.appendingPathComponent(name)
  }

  func removeAttachment(named name: String) async throws {
    try await checkpoint(.remove)
    files.removeValue(forKey: name)
  }

  func waitFor(_ operation: RepositoryOperation) async {
    if counts[operation, default: 0] > 0 { return }
    await withCheckedContinuation { arrivals[operation, default: []].append($0) }
  }

  func release(_ operation: RepositoryOperation) {
    suspended.remove(operation)
    for continuation in resumes.removeValue(forKey: operation) ?? [] { continuation.resume() }
  }

  func clearFailures() { failures = [:] }
  func count(_ operation: RepositoryOperation) -> Int { counts[operation, default: 0] }

  private func checkpoint(_ operation: RepositoryOperation) async throws {
    counts[operation, default: 0] += 1
    for continuation in arrivals.removeValue(forKey: operation) ?? [] { continuation.resume() }
    if suspended.contains(operation) {
      await withCheckedContinuation { resumes[operation, default: []].append($0) }
    }
    if let failure = failures[operation] { throw failure }
  }
}

@Suite @MainActor struct StoreConcurrencyTests {
  @Test func writesRequireASuccessfulLoad() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original)
    let store = RecordsStore(repository: repository)
    #expect(store.isLoading)
    #expect(!store.isSaving)
    await #expect(throws: StoreError.notLoaded) {
      try await store.save { try $0.registering(RegistrationDraft(name: "追加", roomNumber: "1")) }
    }
    #expect(await repository.count(.save) == 0)
    #expect(await repository.stored == original)
  }

  @Test @MainActor func aSuspendedLoadCannotRaceAWrite() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original, suspended: [.load])
    let store = RecordsStore(repository: repository)
    let loading = Task { await store.load() }
    await repository.waitFor(.load)
    await #expect(throws: StoreError.busy) {
      try await store.save { try $0.registering(RegistrationDraft(name: "追加", roomNumber: "1")) }
    }
    await repository.release(.load)
    await loading.value
    #expect(await repository.count(.save) == 0)
    #expect(store.records == original)
    #expect(await repository.stored == store.records)
  }

  @Test @MainActor func overlappingLoadsUseOneRepositoryRead() async throws {
    let repository = ControlledRepository(try fixtureRecords(), suspended: [.load])
    let store = RecordsStore(repository: repository)
    let first = Task { await store.load() }
    await repository.waitFor(.load)
    let release = Task { await repository.release(.load) }
    await store.load()
    await release.value
    await first.value
    #expect(await repository.count(.load) == 1)
    #expect(!store.isLoading)
    #expect(store.loadError == nil)
  }

  @Test @MainActor func failedLoadsBlockWritesUntilRecovery() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original, failures: [.load: .unreadable])
    let store = RecordsStore(repository: repository)
    await store.load()
    #expect(store.loadError as? StorageError == .unreadable)
    await #expect(throws: StoreError.notLoaded) { try await store.save { $0 } }
    #expect(await repository.count(.save) == 0)
    await repository.clearFailures()
    await store.load()
    #expect(store.loadError == nil)
    try await store.save { try $0.settingStatus(.completed, for: original.work[0].id) }
    #expect(store.records.work[0].status == .completed)
  }

  @Test @MainActor func aPendingCommitExcludesAllOtherMutations() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original, suspended: [.save])
    let store = RecordsStore(repository: repository)
    await store.load()
    let saving = Task {
      try await store.save { try $0.settingStatus(.completed, for: original.work[0].id) }
    }
    await repository.waitFor(.save)
    #expect(store.isSaving)
    #expect(!store.isLoading)
    #expect(store.records == original)
    await #expect(throws: StoreError.busy) { try await store.save { $0 } }
    await #expect(throws: StoreError.busy) {
      try await store.importAttachment(
        Data("file".utf8), name: "書類.txt", extension: "txt", kind: .document,
        location: RecordLocation(buildingID: original.buildings[0].id))
    }
    await store.load()
    #expect(await repository.count(.load) == 1)
    await repository.release(.save)
    try await saving.value
    #expect(store.records == (try await repository.load()))
    #expect(store.records.work[0].status == .completed)
    #expect(!store.isSaving)
  }

  @Test @MainActor func cancellationBeforeSavingDoesNotReachTheRepository() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original)
    let store = RecordsStore(repository: repository)
    await store.load()
    let saving = Task {
      try await store.save { try $0.settingStatus(.completed, for: original.work[0].id) }
    }
    saving.cancel()
    await #expect(throws: CancellationError.self) { try await saving.value }
    #expect(await repository.count(.save) == 0)
    #expect(store.records == original)
    #expect(!store.isSaving)
  }

  @Test @MainActor func aSuccessfulCommitStillPublishesAfterCancellation() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original, suspended: [.save])
    let store = RecordsStore(repository: repository)
    await store.load()
    let saving = Task {
      try await store.save { try $0.settingStatus(.completed, for: original.work[0].id) }
    }
    await repository.waitFor(.save)
    saving.cancel()
    await repository.release(.save)
    try await saving.value
    #expect(store.records == (try await repository.load()))
    #expect(store.records.work[0].status == .completed)
  }

  @Test @MainActor func invalidAttachmentMetadataDoesNotCopyAFile() async throws {
    let repository = ControlledRepository(try fixtureRecords())
    let store = RecordsStore(repository: repository)
    await store.load()
    await #expect(throws: DomainError.invalidReference) {
      try await store.importAttachment(
        Data("file".utf8), name: "書類.txt", extension: "txt", kind: .document,
        location: RecordLocation(buildingID: UUID()))
    }
    #expect(await repository.count(.write) == 0)
    #expect(await repository.count(.save) == 0)
    #expect(await repository.files.isEmpty)
  }

  @Test @MainActor func rollbackFailurePreservesBothErrorsAndPublishedRecords() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(
      original, failures: [.save: .unwritable, .remove: .missingAttachment])
    var events: [RecordsEvent] = []
    let store = RecordsStore(repository: repository) { events.append($0) }
    await store.load()
    do {
      try await store.importAttachment(
        Data("file".utf8), name: "書類.txt", extension: "txt", kind: .document,
        location: RecordLocation(buildingID: original.buildings[0].id))
      Issue.record("The metadata commit must fail.")
    } catch let error as AttachmentRollbackError {
      #expect(error.primary as? StorageError == .unwritable)
      #expect(error.cleanup as? StorageError == .missingAttachment)
    }
    #expect(store.records == original)
    #expect(await repository.stored == original)
    #expect(!store.isSaving)
    #expect(events == [.attachmentRollbackFailed(errorType: String(reflecting: StorageError.self))])
  }

  @Test func attachmentImportsRequireLoadedRecords() async throws {
    let repository = ControlledRepository(try fixtureRecords())
    let store = RecordsStore(repository: repository)
    await #expect(throws: StoreError.notLoaded) {
      try await store.importAttachment(Data("file".utf8), name: "書類.txt", extension: "txt", kind: .document,
                                       location: RecordLocation(buildingID: UUID()))
    }
    #expect(await repository.count(.write) == 0)
    #expect(await repository.count(.save) == 0)
  }

  @Test func cancellingAnAttachmentCopyRollsBackBeforeMetadataCommit() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original, suspended: [.write])
    let store = RecordsStore(repository: repository)
    await store.load()
    let importing = Task {
      try await store.importAttachment(Data("file".utf8), name: "書類.txt", extension: "txt", kind: .document,
                                       location: RecordLocation(buildingID: original.buildings[0].id))
    }
    await repository.waitFor(.write)
    await #expect(throws: StoreError.busy) { try await store.save { $0 } }
    importing.cancel()
    await repository.release(.write)
    await #expect(throws: CancellationError.self) { try await importing.value }
    #expect(await repository.count(.save) == 0)
    #expect(await repository.count(.remove) == 1)
    #expect(await repository.files.isEmpty)
    #expect(store.records == original)
    #expect(!store.isSaving)
  }

  @Test func cancellingALoadKeepsRecordsUnpublishedAndAllowsRetry() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original, suspended: [.load])
    let store = RecordsStore(repository: repository)
    let loading = Task { await store.load() }
    await repository.waitFor(.load)
    loading.cancel()
    await repository.release(.load)
    await loading.value
    #expect(store.records == Records())
    #expect(store.loadError is CancellationError)
    #expect(!store.isLoading)
    await store.load()
    #expect(store.records == original)
    #expect(store.loadError == nil)
  }

  @Test func cancellationDuringTransformationStopsBeforeSaving() async throws {
    let original = try fixtureRecords()
    let repository = ControlledRepository(original)
    let store = RecordsStore(repository: repository)
    await store.load()
    let saving = Task {
      try await store.save { records in
        withUnsafeCurrentTask { $0?.cancel() }
        return try records.settingStatus(.completed, for: original.work[0].id)
      }
    }
    await #expect(throws: CancellationError.self) { try await saving.value }
    #expect(await repository.count(.save) == 0)
    #expect(store.records == original)
    #expect(!store.isSaving)
  }
}
