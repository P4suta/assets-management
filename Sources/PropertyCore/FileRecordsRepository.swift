import Foundation

public enum StorageError: Error, Equatable, Sendable {
    case unreadable, corrupted, unwritable, attachmentTooLarge, unsafeFileName, missingAttachment
}

public protocol RecordsRepository: Sendable {
    func load() async throws -> Records
    func save(_ records: Records) async throws
    func writeAttachment(_ data: Data, extension fileExtension: String) async throws -> String
    func attachmentURL(named: String) async throws -> URL
    func removeAttachment(named: String) async throws
}

public actor FileRecordsRepository: RecordsRepository {
    public static let maximumAttachmentBytes = 25 * 1_024 * 1_024
    private let directory: URL
    private var snapshotURL: URL { directory.appendingPathComponent("records.json") }
    private var attachmentDirectory: URL { directory.appendingPathComponent("Attachments", isDirectory: true) }

    public init(directory: URL) { self.directory = directory }

    public func load() throws -> Records {
        let data: Data
        do { data = try Data(contentsOf: snapshotURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return Records() }
        catch { throw StorageError.unreadable }
        let records: Records
        do { records = try JSONDecoder().decode(Records.self, from: data) }
        catch { throw StorageError.corrupted }
        return try records.validated()
    }

    public func save(_ records: Records) throws {
        _ = try records.validated()
        try Task.checkCancellation()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try protectedWrite(encoder.encode(records), to: snapshotURL)
        } catch { throw StorageError.unwritable }
    }

    public func writeAttachment(_ data: Data, extension fileExtension: String) throws -> String {
        guard data.count <= Self.maximumAttachmentBytes else { throw StorageError.attachmentTooLarge }
        let name = UUID().uuidString + "." + fileExtension.lowercased()
        guard Records.safeStoredName(name) else { throw StorageError.unsafeFileName }
        do {
            try FileManager.default.createDirectory(at: attachmentDirectory, withIntermediateDirectories: true)
            try protectedWrite(data, to: attachmentDirectory.appendingPathComponent(name))
        } catch { throw StorageError.unwritable }
        return name
    }

    public func attachmentURL(named name: String) throws -> URL {
        guard Records.safeStoredName(name) else { throw StorageError.unsafeFileName }
        let url = attachmentDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { throw StorageError.missingAttachment }
        return url
    }

    public func removeAttachment(named name: String) throws {
        let url = try attachmentURL(named: name)
        do { try FileManager.default.removeItem(at: url) }
        catch { throw StorageError.unwritable }
    }

    private func protectedWrite(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
