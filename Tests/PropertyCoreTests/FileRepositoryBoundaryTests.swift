import Foundation
import Testing
@testable import PropertyCore

private func repositorySandbox() -> URL {
    URL.temporaryDirectory.appendingPathComponent("RepositoryBoundaries").appendingPathComponent(UUID().uuidString)
}

@Suite @MainActor struct FileRepositoryBoundaryTests {
    @Test func loadingALegacySnapshotLeavesItsBytesUntilAnAtomicSave() async throws {
        let directory = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var original = try completeRecords()
        original.formatVersion = 1
        let bytes = try JSONEncoder().encode(original)
        let snapshot = directory.appendingPathComponent("records.json")
        try bytes.write(to: snapshot)
        let repository = FileRecordsRepository(directory: directory)
        var migrated = try await repository.load()
        #expect(migrated.formatVersion == 2)
        #expect(try Data(contentsOf: snapshot) == bytes)
        migrated.contacts[0].category = .insurance
        migrated.contacts[0].isEmergency = true
        try await repository.save(migrated)
        #expect(try await repository.load() == migrated)
        #expect(try Data(contentsOf: snapshot) != bytes)
        #expect(migrated.history == original.history)
        #expect(migrated.attachments == original.attachments)
    }

    @Test func invalidSnapshotRelationshipsAreReadFailures() async throws {
        let directory = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var invalid = try fixtureRecords()
        invalid.rooms[0].buildingID = UUID()
        let data = try JSONEncoder().encode(invalid)
        let url = directory.appendingPathComponent("records.json")
        try data.write(to: url)
        await #expect(throws: StorageError.corrupted) { try await FileRecordsRepository(directory: directory).load() }
        #expect(try Data(contentsOf: url) == data)
    }

    @Test(arguments: ["selfManaged", "renewal", "notStarted", "phone", "document", "other"])
    func anUnknownStoredEnumFailsClosed(token: String) async throws {
        let directory = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoded = try JSONEncoder().encode(completeRecords())
        let original = String(decoding: encoded, as: UTF8.self)
        let text = original.replacingOccurrences(of: "\"" + token + "\"", with: "\"unknown\"")
        #expect(text != original)
        let data = Data(text.utf8)
        let url = directory.appendingPathComponent("records.json")
        try data.write(to: url)
        await #expect(throws: StorageError.corrupted) { try await FileRecordsRepository(directory: directory).load() }
        #expect(try Data(contentsOf: url) == data)
    }

    @Test func futureSnapshotFormatsRemainDistinguishable() async throws {
        let directory = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var records = try fixtureRecords()
        records.formatVersion = 3
        let data = try JSONEncoder().encode(records)
        let url = directory.appendingPathComponent("records.json")
        try data.write(to: url)
        await #expect(throws: DomainError.unsupportedFormat) { try await FileRecordsRepository(directory: directory).load() }
        #expect(try Data(contentsOf: url) == data)
    }

    @Test func anAttachmentDirectoryIsNeverReturnedAsAFile() async throws {
        let directory = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let name = try await repository.writeAttachment(Data("file".utf8), extension: "txt")
        let url = try await repository.attachmentURL(named: name)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        await #expect(throws: StorageError.missingAttachment) { try await repository.attachmentURL(named: name) }
    }

    @Test func attachmentLinksCannotExposeAnotherFile() async throws {
        let sandbox = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let directory = sandbox.appendingPathComponent("Records")
        let repository = FileRecordsRepository(directory: directory)
        let bytes = Data("outside file".utf8)
        let name = try await repository.writeAttachment(Data("attachment".utf8), extension: "txt")
        let url = try await repository.attachmentURL(named: name)
        let outside = sandbox.appendingPathComponent("outside.txt")
        try bytes.write(to: outside)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: outside)
        await #expect(throws: StorageError.missingAttachment) { try await repository.attachmentURL(named: name) }
        #expect(try Data(contentsOf: outside) == bytes)
    }

    @Test func aRelocatedAttachmentDirectoryRejectsWrites() async throws {
        let sandbox = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let directory = sandbox.appendingPathComponent("Records")
        let repository = FileRecordsRepository(directory: directory)
        let name = try await repository.writeAttachment(Data("attachment".utf8), extension: "txt")
        let outside = sandbox.appendingPathComponent("Outside")
        let attachments = directory.appendingPathComponent("Attachments")
        try FileManager.default.moveItem(at: attachments, to: outside)
        try FileManager.default.createSymbolicLink(at: attachments, withDestinationURL: outside)
        await #expect(throws: StorageError.missingAttachment) { try await repository.attachmentURL(named: name) }
        await #expect(throws: StorageError.unwritable) { try await repository.writeAttachment(Data("new".utf8), extension: "txt") }
        #expect(try FileManager.default.contentsOfDirectory(atPath: outside.path) == [name])
    }

    @Test func aSnapshotLinkIsNotAnEmptyOrTrustedAccount() async throws {
        let sandbox = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }
        let directory = sandbox.appendingPathComponent("Records")
        let repository = FileRecordsRepository(directory: directory)
        let original = try fixtureRecords()
        try await repository.save(original)
        let outside = sandbox.appendingPathComponent("outside.json")
        let bytes = try JSONEncoder().encode(original)
        try bytes.write(to: outside)
        let snapshot = directory.appendingPathComponent("records.json")
        try FileManager.default.removeItem(at: snapshot)
        try FileManager.default.createSymbolicLink(at: snapshot, withDestinationURL: outside)
        await #expect(throws: StorageError.unreadable) { try await repository.load() }
        #expect(try Data(contentsOf: outside) == bytes)
    }

    @Test func aCancelledCopyDoesNotCreateAttachmentFiles() async throws {
        let directory = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let writing = Task { try await repository.writeAttachment(Data("file".utf8), extension: "txt") }
        writing.cancel()
        await #expect(throws: CancellationError.self) { try await writing.value }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("Attachments").path))
    }

    @Test func aRealWriteFailurePreservesThePreviousSnapshot() async throws {
        let directory = repositorySandbox()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        let repository = FileRecordsRepository(directory: directory)
        let original = try fixtureRecords()
        try await repository.save(original)
        let changed = try original.settingStatus(.completed, for: original.work[0].id)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        await #expect(throws: StorageError.unwritable) { try await repository.save(changed) }
        #expect(try await repository.load() == original)
    }

    @Test func theAttachmentSizeLimitIsInclusive() async throws {
        let directory = repositorySandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        #expect(FileRecordsRepository.maximumAttachmentBytes == 26_214_400)
        let data = Data(repeating: 0x61, count: 26_214_400)
        let name = try await repository.writeAttachment(data, extension: "txt")
        #expect(try Data(contentsOf: await repository.attachmentURL(named: name)) == data)
        await #expect(throws: StorageError.attachmentTooLarge) {
            try await repository.writeAttachment(Data(repeating: 0x61, count: 26_214_401), extension: "txt")
        }
    }
}
