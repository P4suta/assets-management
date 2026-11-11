import Foundation
import Testing
@testable import PropertyCore

private func temporaryDirectory() -> URL {
    URL.temporaryDirectory.appendingPathComponent("PropertyCoreTests").appendingPathComponent(UUID().uuidString)
}

@Test func atomicSnapshotSurvivesRepositoryRecreation() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let original = try fixtureRecords()
    try await FileRecordsRepository(directory: directory).save(original)
    let loaded = try await FileRecordsRepository(directory: directory).load()
    #expect(loaded == original)
}

@Test func invalidSnapshotDoesNotOverwriteSavedRecords() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = FileRecordsRepository(directory: directory)
    let original = try fixtureRecords()
    try await repository.save(original)
    var invalid = original
    invalid.rooms[0].number = ""
    await #expect(throws: DomainError.required(.roomNumber)) { try await repository.save(invalid) }
    #expect(try await repository.load() == original)
}

@Test func corruptedStorageIsNeverTreatedAsAnEmptyAccount() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let bytes = Data("broken data".utf8)
    let url = directory.appendingPathComponent("records.json")
    try bytes.write(to: url)
    await #expect(throws: StorageError.corrupted) { try await FileRecordsRepository(directory: directory).load() }
    #expect(try Data(contentsOf: url) == bytes)
}

@Test func inaccessibleStorageIsNeverTreatedAsEmpty() async throws {
    let directory = temporaryDirectory()
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
    }
    let repository = FileRecordsRepository(directory: directory)
    try await repository.save(fixtureRecords())
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: directory.path)
    await #expect(throws: StorageError.unreadable) { try await repository.load() }
}

@Test func attachmentsAreCopiedAndRejectUnsafeNamesAndOversizedData() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = FileRecordsRepository(directory: directory)
    let bytes = Data("sample document".utf8)
    let name = try await repository.writeAttachment(bytes, extension: "txt")
    let url = try await repository.attachmentURL(named: name)
    #expect(try Data(contentsOf: url) == bytes)
    await #expect(throws: StorageError.unsafeFileName) { try await repository.attachmentURL(named: "../records.json") }
    await #expect(throws: StorageError.unsafeFileName) { try await repository.writeAttachment(bytes, extension: "../pdf") }
    await #expect(throws: StorageError.attachmentTooLarge) {
        try await repository.writeAttachment(Data(count: FileRecordsRepository.maximumAttachmentBytes + 1), extension: "pdf")
    }
    try await repository.removeAttachment(named: name)
    await #expect(throws: StorageError.missingAttachment) { try await repository.attachmentURL(named: name) }
}

private actor FaultRepository: RecordsRepository {
    let backing: FileRecordsRepository
    var failSave = true
    var created: String?
    init(directory: URL) { backing = FileRecordsRepository(directory: directory) }
    func load() async throws -> Records { try fixtureRecords() }
    func save(_ records: Records) async throws {
        if failSave { failSave = false; throw StorageError.unwritable }
        try await backing.save(records)
    }
    func writeAttachment(_ data: Data, extension fileExtension: String) async throws -> String {
        let name = try await backing.writeAttachment(data, extension: fileExtension)
        created = name
        return name
    }
    func attachmentURL(named name: String) async throws -> URL { try await backing.attachmentURL(named: name) }
    func removeAttachment(named name: String) async throws { try await backing.removeAttachment(named: name) }
}

@Test @MainActor func failedSaveKeepsPublishedRecordsAndAllowsRetry() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = RecordsStore(repository: FaultRepository(directory: directory))
    await store.load()
    let original = store.records
    let draft = RegistrationDraft(name: "青葉コート", roomNumber: "201")
    await #expect(throws: StorageError.unwritable) { try await store.save { try $0.registering(draft) } }
    #expect(store.records == original)
    #expect(!store.isSaving)
    try await store.save { try $0.registering(draft) }
    #expect(store.records.buildings.count == 2)
    #expect(try await FileRecordsRepository(directory: directory).load() == store.records)
}

@Test @MainActor func failedAttachmentCommitRemovesUnreferencedFile() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = FaultRepository(directory: directory)
    let store = RecordsStore(repository: repository)
    await store.load()
    let item = store.records.work[0]
    await #expect(throws: StorageError.unwritable) {
        try await store.importAttachment(Data("file".utf8), name: "依頼書.txt", extension: "txt", kind: .document,
                                         location: RecordLocation(buildingID: item.buildingID, roomID: item.roomID, workID: item.id))
    }
    #expect(store.records.attachments.isEmpty)
    let name = try #require(await repository.created)
    await #expect(throws: StorageError.missingAttachment) { try await repository.attachmentURL(named: name) }
}

@Test @MainActor func documentAndPhotoAdditionsRemainIndependentAfterRelaunch() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = FileRecordsRepository(directory: directory)
    let records = try fixtureRecords()
    try await repository.save(records)
    let store = RecordsStore(repository: repository)
    await store.load()
    let item = records.work[0]
    let location = RecordLocation(buildingID: item.buildingID, roomID: item.roomID, workID: item.id)
    try await store.importAttachment(Data("PDF".utf8), name: "依頼書.pdf", extension: "pdf", kind: .document, location: location)
    try await store.importAttachment(Data("photo".utf8), name: "現地写真.jpg", extension: "jpg", kind: .photo, location: location)
    let reloaded = try await FileRecordsRepository(directory: directory).load()
    #expect(reloaded.attachments.filter { $0.kind == .document }.count == 1)
    #expect(reloaded.attachments.filter { $0.kind == .photo }.count == 1)
}
