import Foundation
import Observation
import OSLog

public enum StoreError: Error, Equatable, Sendable {
    case busy, notLoaded
}

public struct AttachmentRollbackError: Error {
    public let primary: any Error
    public let cleanup: any Error
}

public struct RecordLocation: Hashable, Sendable {
    public var buildingID: UUID
    public var roomID: UUID?
    public var workID: UUID?

    public init(buildingID: UUID, roomID: UUID? = nil, workID: UUID? = nil) {
        self.buildingID = buildingID
        self.roomID = roomID
        self.workID = workID
    }
}

@MainActor @Observable
public final class RecordsStore {
    public private(set) var records = Records()
    private enum Phase {
        case unloaded, loading, ready, saving, failed(any Error)
    }
    private var phase: Phase = .unloaded
    public var isLoading: Bool {
        switch phase { case .unloaded, .loading: true; default: false }
    }
    public var isSaving: Bool {
        if case .saving = phase { true } else { false }
    }
    public var loadError: (any Error)? {
        if case .failed(let error) = phase { error } else { nil }
    }
    @ObservationIgnored private let repository: any RecordsRepository
    @ObservationIgnored private let logger = Logger(subsystem: "com.p4suta.PropertyRecords", category: "Storage")

    public init(repository: any RecordsRepository) { self.repository = repository }

    public func load() async {
        switch phase { case .loading, .saving: return; default: break }
        phase = .loading
        do {
            try Task.checkCancellation()
            let loaded = try await repository.load().validated()
            try Task.checkCancellation()
            records = loaded
            phase = .ready
        } catch {
            phase = .failed(error)
            logger.error("records.load failed errorType=\(String(reflecting: type(of: error)), privacy: .public)")
        }
    }

    public func save(_ transform: (Records) throws -> Records) async throws {
        try beginSaving()
        defer { phase = .ready }
        let operationID = UUID().uuidString
        logger.debug("records.save started operation=\(operationID, privacy: .public)")
        do {
            let proposed = try transform(records).validated()
            try Task.checkCancellation()
            try await repository.save(proposed)
            records = proposed
            logger.debug("records.save committed operation=\(operationID, privacy: .public)")
        } catch {
            logger.error("records.save failed operation=\(operationID, privacy: .public) errorType=\(String(reflecting: type(of: error)), privacy: .public)")
            throw error
        }
    }

    public func importAttachment(_ data: Data, name: String, extension fileExtension: String,
                                 kind: AttachmentKind, location: RecordLocation) async throws {
        try beginSaving()
        defer { phase = .ready }
        var proposed = records
        let provisional = UUID().uuidString + "." + fileExtension.lowercased()
        proposed.attachments.append(Attachment(buildingID: location.buildingID, roomID: location.roomID,
                                               workID: location.workID, kind: kind, name: name, storedName: provisional))
        _ = try proposed.validated()
        try Task.checkCancellation()
        let storedName = try await repository.writeAttachment(data, extension: fileExtension)
        do {
            try Task.checkCancellation()
            proposed.attachments[proposed.attachments.count - 1].storedName = storedName
            _ = try proposed.validated()
            try await repository.save(proposed)
            records = proposed
        } catch {
            do { try await repository.removeAttachment(named: storedName) }
            catch let cleanup {
                logger.error("attachment.rollback failed errorType=\(String(reflecting: type(of: cleanup)), privacy: .public)")
                throw AttachmentRollbackError(primary: error, cleanup: cleanup)
            }
            throw error
        }
    }

    public func attachmentURL(_ attachment: Attachment) async throws -> URL {
        try await repository.attachmentURL(named: attachment.storedName)
    }

    private func beginSaving() throws {
        switch phase {
        case .loading, .saving: throw StoreError.busy
        case .unloaded, .failed: throw StoreError.notLoaded
        case .ready: break
        }
        try Task.checkCancellation()
        phase = .saving
    }
}
