import OSLog
import PropertyCore

enum StorageDiagnostics {
    static func record(_ event: RecordsEvent) {
        let logger = Logger(subsystem: "com.p4suta.PropertyRecords", category: "Storage")
        switch event {
        case .loadFailed(let errorType):
            logger.error("records.load failed errorType=\(errorType, privacy: .public)")
        case .saving(let operationID):
            logger.debug("records.save started operation=\(operationID.uuidString, privacy: .public)")
        case .saved(let operationID):
            logger.debug("records.save committed operation=\(operationID.uuidString, privacy: .public)")
        case .saveFailed(let operationID, let errorType):
            logger.error("records.save failed operation=\(operationID.uuidString, privacy: .public) errorType=\(errorType, privacy: .public)")
        case .attachmentRollbackFailed(let errorType):
            logger.error("attachment.rollback failed errorType=\(errorType, privacy: .public)")
        }
    }
}
