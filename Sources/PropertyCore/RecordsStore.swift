import Foundation
import Observation
import OSLog

public enum StoreError: Error, Equatable, Sendable {
    case busy
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
    public private(set) var isLoading = true
    public private(set) var isSaving = false
    public private(set) var loadError: (any Error)?
    @ObservationIgnored private let repository: any RecordsRepository
    @ObservationIgnored private let logger = Logger(subsystem: "com.p4suta.PropertyRecords", category: "Storage")

    public init(repository: any RecordsRepository) { self.repository = repository }

    public func load() async {
        guard !isSaving else { return }
        isLoading = true
        do {
            records = try await repository.load().validated()
            loadError = nil
        } catch {
            loadError = error
            logger.error("records.load failed errorType=\(String(reflecting: type(of: error)), privacy: .public)")
        }
        isLoading = false
    }

    public func save(_ transform: (Records) throws -> Records) async throws {
        guard !isSaving else { throw StoreError.busy }
        isSaving = true
        defer { isSaving = false }
        let operationID = UUID().uuidString
        logger.debug("records.save started operation=\(operationID, privacy: .public)")
        do {
            let proposed = try transform(records).validated()
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
        guard !isSaving else { throw StoreError.busy }
        isSaving = true
        defer { isSaving = false }
        let storedName = try await repository.writeAttachment(data, extension: fileExtension)
        do {
            var proposed = records
            proposed.attachments.append(Attachment(buildingID: location.buildingID, roomID: location.roomID,
                                                   workID: location.workID, kind: kind, name: name,
                                                   storedName: storedName))
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
}
