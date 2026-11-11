import Foundation
import Observation

public enum StoreError: Error, Equatable, Sendable {
    case busy, notLoaded
}

public enum RecordsEvent: Equatable, Sendable {
    case loadFailed(errorType: String)
    case saving(operationID: UUID)
    case saved(operationID: UUID)
    case saveFailed(operationID: UUID, errorType: String)
    case attachmentRollbackFailed(errorType: String)
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
    @ObservationIgnored private let trace: @MainActor (RecordsEvent) -> Void

    public init(repository: any RecordsRepository, trace: @escaping @MainActor (RecordsEvent) -> Void = { _ in }) {
        self.repository = repository
        self.trace = trace
    }

    public func load() async {
        switch phase { case .loading, .saving: return; default: break }
        phase = .loading
        do {
            try Task.checkCancellation()
            let loaded = try await repository.load().validatedAfterLoading()
            try Task.checkCancellation()
            records = loaded
            phase = .ready
        } catch {
            phase = .failed(error)
            trace(.loadFailed(errorType: String(reflecting: type(of: error))))
        }
    }

    public func save(_ transform: (Records) throws -> Records) async throws {
        try beginSaving()
        defer { phase = .ready }
        let operationID = UUID()
        trace(.saving(operationID: operationID))
        do {
            let proposed = try transform(records).validated()
            try Task.checkCancellation()
            try await repository.save(proposed)
            records = proposed
            trace(.saved(operationID: operationID))
        } catch {
            trace(.saveFailed(operationID: operationID, errorType: String(reflecting: type(of: error))))
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
                trace(.attachmentRollbackFailed(errorType: String(reflecting: type(of: cleanup))))
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
