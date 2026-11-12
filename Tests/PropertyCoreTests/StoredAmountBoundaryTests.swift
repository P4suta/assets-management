import Foundation
import Testing
@testable import PropertyCore

@Suite struct StoredAmountBoundaryTests {
    private enum Slot: CaseIterable {
        case contract, estimate, renewal
        var original: String {
            switch self {
            case .contract: "\"monthlyRent\":82000"
            case .estimate: "\"estimate\":38500"
            case .renewal: "\"monthlyRent\":85000"
            }
        }
        var key: String { self == .estimate ? "estimate" : "monthlyRent" }
    }

    @Test(arguments: Slot.allCases, ["-1", "1000000000001", "9223372036854775808", "1.5", "1e9999", "true", "\"85000\"", "NaN"])
    private func malformedStoredAmountsFailClosedWithoutChangingBytes(slot: Slot, token: String) async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let original = try #require(String(data: encoder.encode(completeRecords()), encoding: .utf8))
        #expect(original.components(separatedBy: slot.original).count == 2)
        let bytes = Data(original.replacingOccurrences(of: slot.original, with: "\"\(slot.key)\":\(token)").utf8)
        let snapshot = directory.appendingPathComponent("records.json")
        try bytes.write(to: snapshot)
        let repository = FileRecordsRepository(directory: directory)
        await #expect(throws: StorageError.corrupted) { try await repository.load() }
        #expect(try Data(contentsOf: snapshot) == bytes)
    }

    @Test(arguments: Slot.allCases, ["null", "0", "1000000000000"])
    private func validStoredAmountEndpointsRemainReadable(slot: Slot, token: String) async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let original = try #require(String(data: encoder.encode(completeRecords()), encoding: .utf8))
        let bytes = Data(original.replacingOccurrences(of: slot.original, with: "\"\(slot.key)\":\(token)").utf8)
        try bytes.write(to: directory.appendingPathComponent("records.json"))
        let loaded = try await FileRecordsRepository(directory: directory).load()
        let amount: Int? = switch slot {
        case .contract: loaded.rooms[0].contract?.monthlyRent
        case .estimate: loaded.work[0].estimate
        case .renewal: loaded.work[0].renewalDraft?.monthlyRent
        }
        #expect(amount == Int(token))
    }
}
