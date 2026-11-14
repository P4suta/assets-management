import Foundation
import PropertyCore

enum RepositoryFactory {
    @MainActor static func make() -> any RecordsRepository {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let identifier = ProcessInfo.processInfo.environment["UITEST_STORAGE_ID"] ?? UUID().uuidString
            let directory = URL.temporaryDirectory.appendingPathComponent("PropertyRecordsTests", isDirectory: true)
                .appendingPathComponent(identifier, isDirectory: true)
            return TestRepository(directory: directory,
                                  seeded: ProcessInfo.processInfo.arguments.contains("--seeded"),
                                  pastVisit: ProcessInfo.processInfo.environment["UITEST_PAST_VISIT"] == "1",
                                  failFirstSave: ProcessInfo.processInfo.arguments.contains("--fail-first-save"))
        }
        #endif
        return FileRecordsRepository(directory: URL.applicationSupportDirectory.appendingPathComponent("PropertyRecords", isDirectory: true))
    }
}

#if DEBUG
private actor TestRepository: RecordsRepository {
    let backing: FileRecordsRepository
    let seeded: Bool
    let pastVisit: Bool
    var failFirstSave: Bool
    init(directory: URL, seeded: Bool, pastVisit: Bool, failFirstSave: Bool) {
        backing = FileRecordsRepository(directory: directory)
        self.seeded = seeded
        self.pastVisit = pastVisit
        self.failFirstSave = failFirstSave
    }
    func load() async throws -> Records {
        let records = try await backing.load()
        guard records.buildings.isEmpty, seeded else { return records }
        var fixture = try SampleRecords.make(pastVisit: pastVisit)
        if let item = fixture.work.first {
            guard let data = await SamplePDF.photoData() else { throw StorageError.missingAttachment }
            let name = try await backing.writeAttachment(data, extension: "png")
            fixture.attachments.append(Attachment(buildingID: item.buildingID, roomID: item.roomID,
                                                 workID: item.id, kind: .photo, name: "給湯器の配管接続部.png", storedName: name))
        }
        if let item = fixture.work.first {
            let quote = await SamplePDF.data(title: "見積書", lines: ["未来ヶ丘団地 · 203号室", "給湯器の配管修繕", "見積額 ¥38,500", "みどり設備", "架空の見積書です。"],
                                             link: AppInformation.supportURL)
            let name = try await backing.writeAttachment(quote, extension: "pdf")
            fixture.attachments.append(Attachment(buildingID: item.buildingID, roomID: item.roomID, workID: item.id,
                                                 kind: .document, name: "見積書.pdf", storedName: name))
            let request = await SamplePDF.data(title: "修繕依頼書", lines: ["未来ヶ丘団地 · 203号室", "給湯器の配管接続部から水漏れ", "2026年11月12日 現地確認", "架空の依頼書です。"])
            try FileManager.default.createDirectory(at: URL.documentsDirectory, withIntermediateDirectories: true)
            try request.write(to: URL.documentsDirectory.appendingPathComponent("修繕依頼書.pdf"), options: .atomic)
        }
        try await backing.save(fixture)
        return fixture
    }
    func save(_ records: Records) async throws {
        if failFirstSave { failFirstSave = false; throw StorageError.unwritable }
        try await backing.save(records)
    }
    func writeAttachment(_ data: Data, extension fileExtension: String) async throws -> String {
        try await backing.writeAttachment(data, extension: fileExtension)
    }
    func attachmentURL(named name: String) async throws -> URL { try await backing.attachmentURL(named: name) }
    func removeAttachment(named name: String) async throws { try await backing.removeAttachment(named: name) }
}

enum SampleRecords {
    static func make(now: Date = Date(), pastVisit: Bool = false) throws -> Records {
        var records = Records()
        let contractor = Contact(name: "高橋", company: "みどり設備", notes: "架空の連絡先です。", category: .maintenance, isEmergency: true)
        let resident = Contact(name: "佐藤 花子", notes: "架空の連絡先です。", category: .resident)
        let resident2 = Contact(name: "鈴木 一郎", notes: "架空の連絡先です。", category: .resident)
        let agency = Contact(name: "青葉管理", notes: "架空の管理会社です。", category: .management)
        let building = Building(name: "未来ヶ丘団地", address: "朝焼1-2-3")
        let managed = Building(name: "青葉コート", address: "横浜市青葉区青葉台1-3",
                               management: .agency, agencyContactID: agency.id)
        let insurance = Contact(name: "建物保険の相談窓口", company: "朝焼保険", notes: "保険証券を手元に用意して相談。架空の連絡先です。",
                                category: .insurance, isEmergency: true, buildingIDs: [building.id])
        let fireSafety = Contact(name: "消防設備の点検窓口", company: "朝焼防災", notes: "年2回の点検日を調整。架空の連絡先です。",
                                 category: .fireSafety, buildingIDs: [building.id, managed.id])
        let room = Room(buildingID: building.id, number: "203", residentID: resident.id,
                        contract: Contract(start: date(2025, 4, 1), end: date(2027, 3, 31), monthlyRent: 82_000),
                        equipment: [Equipment(name: "給湯器", model: "WH-203"), Equipment(name: "エアコン")])
        let renewalRoom = Room(buildingID: building.id, number: "101", residentID: resident2.id,
                               contract: Contract(start: date(2025, 1, 1), end: date(2026, 12, 31), monthlyRent: 78_000))
        let repair = WorkItem(buildingID: building.id, roomID: room.id, title: "給湯器から水漏れ",
                              receivedAt: date(2026, 11, 11), dueDate: now.addingTimeInterval(pastVisit ? -86_400 : 86_400),
                              notes: "給湯器の配管接続部から水が漏れる。", contractorID: contractor.id,
                              estimate: 38_500, nextVisit: now.addingTimeInterval(pastVisit ? -86_400 : 86_400))
        records.buildings = [building, managed]
        records.rooms = [room, renewalRoom, Room(buildingID: managed.id, number: "201"),
                         Room(buildingID: managed.id, number: "202")]
        records.contacts = [contractor, resident, resident2, agency, insurance, fireSafety]
        records.work = [
            repair,
            WorkItem(buildingID: building.id, roomID: renewalRoom.id, kind: .renewal, title: "契約更新の確認",
                     status: .waiting, dueDate: date(2026, 11, 30)),
            WorkItem(buildingID: managed.id, title: "共用灯の交換", status: .inProgress, dueDate: date(2026, 11, 20)),
            WorkItem(buildingID: managed.id, kind: .inspection, title: "消防設備点検", dueDate: date(2026, 12, 5))
        ]
        records.history = [HistoryEntry(workID: repair.id, date: date(2026, 11, 11, hour: 9), contactID: resident.id,
                                        text: "給湯器の水漏れを受付")]
        return try records.validated()
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }
}
#endif
