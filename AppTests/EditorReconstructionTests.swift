import PropertyCore
import Observation
import SwiftUI
import Testing
import UIKit
import UserNotifications
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

@MainActor @Observable private final class HostedEditorPresentation {
    var destination: EditorDestination?
}

extension NativePresentationTests {
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
        let scene = try #require(await waitForWindowScene())
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 600, height: 900)
        let controller = UIHostingController(rootView: content(0))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let input = try #require(await waitForFirstInput(in: controller.view))
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
        #expect(text(in: try #require(await waitForFirstInput(in: controller.view))) == edited)
        controller.rootView = content(1)
        controller.view.layoutIfNeeded()
        let recreated = try #require(await waitForFirstInput(in: controller.view))
        #expect(text(in: recreated) == edited)
        #expect(store.records == records)
        #expect(try await repository.load() == records)
    }

    @Test func notificationNavigationWaitsThroughEditorReconstruction() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = FileRecordsRepository(directory: directory)
        let records = try SampleRecords.make()
        try await repository.save(records)
        let store = RecordsStore(repository: repository)
        await store.load()
        let notices = AppNotices()
        let destination = EditorDestination.work(records.work[0].buildingID, records.work[0].roomID, records.work[0].id, .repair)
        let presentation = HostedEditorPresentation()
        presentation.destination = destination
        func content(_ generation: Int) -> AnyView {
            AnyView(Text("Host \(generation)")
                .modifier(EditorPresentation(destination: Binding(get: { presentation.destination }, set: { presentation.destination = $0 })) {
                    EditorDestinationView(destination: $0).id(generation)
                })
                .environment(store).environment(notices))
        }
        let scene = try #require(await waitForWindowScene())
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: content(0))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        _ = try #require(await waitForPresentedInput(in: controller))
        notices.receiveReminder(identifier: records.rooms[0].id.uuidString + ".contractDeadline",
                               action: UNNotificationDefaultActionIdentifier)
        #expect(notices.openedReminder == nil)
        controller.rootView = content(1)
        _ = try #require(await waitForPresentedInput(in: controller))
        #expect(notices.openedReminder == nil)
        presentation.destination = nil
        #expect(await waitForOpenedReminder(in: notices)?.target == .contract(records.rooms[0].id))
    }

    private func waitForWindowScene() async -> UIWindowScene? {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first { return scene }
            try? await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        return nil
    }

    private func waitForPresentedInput(in controller: UIViewController) async -> UIView? {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            if let view = controller.presentedViewController?.view, let input = nativeInput(in: view) { return input }
            try? await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        return nil
    }

    private func waitForOpenedReminder(in notices: AppNotices) async -> OpenedReminder? {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            if let reminder = notices.openedReminder { return reminder }
            try? await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
        return nil
    }

    private func waitForFirstInput(in view: UIView) async -> UIView? {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        repeat {
            view.layoutIfNeeded()
            if let input = nativeInput(in: view) { return input }
            try? await Task.sleep(for: .milliseconds(10))
        } while ContinuousClock.now < deadline
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
