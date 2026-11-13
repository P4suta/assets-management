import PropertyCore
import SwiftUI
import Testing
import UIKit
@testable import PropertyRecords

private enum TextEditorCase: CaseIterable, Sendable {
    case registration, building, room, work, contact, history, equipment, contract, renewal

    @MainActor func destination(in records: Records) -> EditorDestination {
        let building = records.buildings[0]
        let room = records.rooms[0]
        let work = records.work[0]
        switch self {
        case .registration: return .registration
        case .building: return .building(building.id)
        case .room: return .room(building.id, room.id)
        case .work: return .work(work.buildingID, work.roomID, work.id, work.kind)
        case .contact: return .contact(records.contacts[0].id, .none)
        case .history: return .history(work.id, nil)
        case .equipment: return .equipment(room.id, nil)
        case .contract: return .contract(room.id)
        case .renewal: return .renewal(records.work.first { $0.kind == .renewal }?.id ?? work.id)
        }
    }

    func initialText(in records: Records) -> String {
        switch self {
        case .registration, .history, .equipment: ""
        case .building: records.buildings[0].name
        case .room: records.rooms[0].number
        case .work: records.work[0].title
        case .contact: records.contacts[0].name
        case .contract: records.rooms[0].contract?.monthlyRent.map(String.init) ?? ""
        case .renewal:
            if let work = records.work.first(where: { $0.kind == .renewal }),
               let contract = work.renewalDraft ?? records.rooms.first(where: { $0.id == work.roomID })?.contract {
                contract.monthlyRent.map(String.init) ?? ""
            } else { "" }
        }
    }

    var editedText: String { self == .contract || self == .renewal ? "88000" : "Unsaved editor reconstruction check" }
}

@Suite(.serialized) @MainActor struct EditorReconstructionTests {
    @Test(arguments: TextEditorCase.allCases)
    fileprivate func destinationRetainsUnsavedTextWhenEditorViewIsReplaced(scenario: TextEditorCase) async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let records = try SampleRecords.make(now: Date(timeIntervalSince1970: 1_794_445_200))
        try await repository.save(records)
        let store = RecordsStore(repository: repository)
        await store.load()
        let destination = scenario.destination(in: records)
        let notices = AppNotices()
        func content(_ generation: Int) -> AnyView {
            AnyView(EditorDestinationView(destination: destination).id(generation)
                .environment(store).environment(notices).environment(\.locale, Locale(identifier: "ja_JP")))
        }
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 600, height: 900)
        let controller = UIHostingController(rootView: content(0))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let input = try #require(waitForFirstInput(in: controller.view))
        #expect(text(in: input) == scenario.initialText(in: records))
        let edited = scenario.editedText
        if let text = input as? UITextView {
            text.text = edited
            text.delegate?.textViewDidChange?(text)
        } else if let text = input as? UITextField {
            text.text = edited
            text.sendActions(for: .editingChanged)
        } else {
            Issue.record("The native input must be a text field or text view.")
            return
        }
        controller.rootView = content(0)
        controller.view.layoutIfNeeded()
        #expect(text(in: try #require(waitForFirstInput(in: controller.view))) == edited)
        controller.rootView = content(1)
        controller.view.layoutIfNeeded()
        let recreated = try #require(waitForFirstInput(in: controller.view))
        #expect(text(in: recreated) == edited)
        #expect(store.records == records)
        #expect(try await repository.load() == records)
    }

    private func waitForFirstInput(in view: UIView) -> UIView? {
        let deadline = Date().addingTimeInterval(3)
        repeat {
            view.layoutIfNeeded()
            if let input = nativeInput(in: view) { return input }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        } while Date() < deadline
        return nil
    }

    private func nativeInput(in view: UIView) -> UIView? {
        if view is UITextView || view is UITextField { return view }
        for child in view.subviews {
            if let found = nativeInput(in: child) { return found }
        }
        return nil
    }

    private func text(in view: UIView) -> String? {
        if let field = view as? UITextField { return field.text }
        return (view as? UITextView)?.text
    }
}
