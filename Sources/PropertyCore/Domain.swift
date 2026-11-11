import Foundation

public enum ManagementMode: String, Codable, CaseIterable, Sendable {
    case selfManaged, agency
}

public enum WorkKind: String, Codable, CaseIterable, Sendable {
    case repair, renewal, inspection
}

public enum WorkStatus: String, Codable, CaseIterable, Sendable {
    case notStarted, inProgress, waiting, completed
}

public enum CommunicationMethod: String, Codable, CaseIterable, Sendable {
    case phone, email, visit, other
}

public enum AttachmentKind: String, Codable, Sendable {
    case document, photo
}

public enum Field: String, Sendable {
    case buildingName, roomNumber, workTitle, contactName, historyText, equipmentName
}

public enum DomainError: Error, Equatable, Sendable {
    case required(Field)
    case duplicateRoom, invalidReference, invalidDates, invalidAmount, unsupportedFormat
    case duplicateIdentifier, invalidAttachment, missingRenewal
}

public struct Building: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var address: String
    public var management: ManagementMode
    public var agencyContactID: UUID?
    public var notes: String

    public init(id: UUID = UUID(), name: String, address: String = "",
                management: ManagementMode = .selfManaged, agencyContactID: UUID? = nil, notes: String = "") {
        self.id = id
        self.name = name
        self.address = address
        self.management = management
        self.agencyContactID = agencyContactID
        self.notes = notes
    }
}

public struct Contract: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var monthlyRent: Int?

    public init(start: Date, end: Date, monthlyRent: Int? = nil) {
        self.start = start
        self.end = end
        self.monthlyRent = monthlyRent
    }
}

public struct Equipment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var model: String
    public var installedOn: Date?
    public var notes: String

    public init(id: UUID = UUID(), name: String, model: String = "", installedOn: Date? = nil, notes: String = "") {
        self.id = id
        self.name = name
        self.model = model
        self.installedOn = installedOn
        self.notes = notes
    }
}

public struct Room: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var buildingID: UUID
    public var number: String
    public var residentID: UUID?
    public var contract: Contract?
    public var equipment: [Equipment]
    public var notes: String

    public init(id: UUID = UUID(), buildingID: UUID, number: String, residentID: UUID? = nil,
                contract: Contract? = nil, equipment: [Equipment] = [], notes: String = "") {
        self.id = id
        self.buildingID = buildingID
        self.number = number
        self.residentID = residentID
        self.contract = contract
        self.equipment = equipment
        self.notes = notes
    }
}

public struct Contact: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var company: String
    public var phone: String
    public var email: String
    public var notes: String

    public init(id: UUID = UUID(), name: String, company: String = "", phone: String = "",
                email: String = "", notes: String = "") {
        self.id = id
        self.name = name
        self.company = company
        self.phone = phone
        self.email = email
        self.notes = notes
    }
}

public struct WorkItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var buildingID: UUID
    public var roomID: UUID?
    public var kind: WorkKind
    public var title: String
    public var status: WorkStatus
    public var receivedAt: Date
    public var dueDate: Date?
    public var notes: String
    public var contractorID: UUID?
    public var estimate: Int?
    public var nextVisit: Date?
    public var reminderEnabled: Bool
    public var visitReminderEnabled: Bool
    public var renewalDraft: Contract?

    public init(id: UUID = UUID(), buildingID: UUID, roomID: UUID? = nil, kind: WorkKind = .repair,
                title: String, status: WorkStatus = .notStarted, receivedAt: Date = Date(),
                dueDate: Date? = nil, notes: String = "", contractorID: UUID? = nil,
                estimate: Int? = nil, nextVisit: Date? = nil, reminderEnabled: Bool = false,
                renewalDraft: Contract? = nil, visitReminderEnabled: Bool = false) {
        self.id = id
        self.buildingID = buildingID
        self.roomID = roomID
        self.kind = kind
        self.title = title
        self.status = status
        self.receivedAt = receivedAt
        self.dueDate = dueDate
        self.notes = notes
        self.contractorID = contractorID
        self.estimate = estimate
        self.nextVisit = nextVisit
        self.reminderEnabled = reminderEnabled
        self.visitReminderEnabled = visitReminderEnabled
        self.renewalDraft = renewalDraft
    }
}

public struct HistoryEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var workID: UUID
    public var date: Date
    public var method: CommunicationMethod
    public var contactID: UUID?
    public var text: String

    public init(id: UUID = UUID(), workID: UUID, date: Date = Date(),
                method: CommunicationMethod = .phone, contactID: UUID? = nil, text: String) {
        self.id = id
        self.workID = workID
        self.date = date
        self.method = method
        self.contactID = contactID
        self.text = text
    }
}

public struct Attachment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var buildingID: UUID
    public var roomID: UUID?
    public var workID: UUID?
    public var kind: AttachmentKind
    public var name: String
    public var storedName: String
    public var createdAt: Date

    public init(id: UUID = UUID(), buildingID: UUID, roomID: UUID? = nil, workID: UUID? = nil,
                kind: AttachmentKind, name: String, storedName: String, createdAt: Date = Date()) {
        self.id = id
        self.buildingID = buildingID
        self.roomID = roomID
        self.workID = workID
        self.kind = kind
        self.name = name
        self.storedName = storedName
        self.createdAt = createdAt
    }
}

public struct RegistrationDraft: Equatable, Sendable {
    public var name: String
    public var roomNumber: String
    public var address: String
    public var management: ManagementMode

    public init(name: String = "", roomNumber: String = "", address: String = "",
                management: ManagementMode = .selfManaged) {
        self.name = name
        self.roomNumber = roomNumber
        self.address = address
        self.management = management
    }
}
