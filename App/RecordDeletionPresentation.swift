import Observation
import PropertyCore
import SwiftUI

private enum DeletionRecordKind: CaseIterable {
    case building, room, contract, equipment, work, memo, photo, document, contact

    init(_ target: RecordDeletionTarget, attachments: [UUID: AttachmentKind]) {
        self = switch target {
        case .building: .building
        case .room: .room
        case .contract: .contract
        case .equipment: .equipment
        case .work: .work
        case .memo: .memo
        case .attachment(let id): attachments[id] == .photo ? .photo : .document
        case .contact: .contact
        }
    }

    var name: String {
        switch self {
        case .building: "建物"
        case .room: "部屋"
        case .contract: "契約"
        case .equipment: "設備"
        case .work: "対応"
        case .memo: "メモ"
        case .photo: "写真"
        case .document: "書類"
        case .contact: "連絡先"
        }
    }
}

private struct DeletionRequest {
    let plan: RecordDeletionPlan
    let discardsDraft: Bool

    var kind: DeletionRecordKind { DeletionRecordKind(plan.target, attachments: plan.attachmentKinds) }
    var title: String { kind.name + "を削除" }
    var subject: String {
        if kind == .room || kind == .contract { return plan.name + "号室" }
        if let attachment = plan.attachment, attachment.kind == .photo {
            return attachment.createdAt.formatted(date: .abbreviated, time: .shortened)
        }
        return plan.name
    }

    var message: String {
        var message = "「" + subject + "」を削除します。"
        if kind == .contact { message += "\n連絡先への割り当ても解除します。" }
        if discardsDraft { message += "\n編集中の変更も破棄します。" }
        return message
    }

    var counts: [DeletionRecordKind: Int] {
        plan.affected.subtracting([plan.target]).reduce(into: [:]) { counts, target in
            counts[DeletionRecordKind(target, attachments: plan.attachmentKinds), default: 0] += 1
        }
    }
}

@MainActor @Observable private final class RecordDeletionActions {
    var review: DeletionRequest?
    var confirmation: DeletionRequest?
    var failure: String?
    var reviewFailure: String?
    var deleting = false

    func present(_ request: DeletionRequest) {
        switch request.plan.target {
        case .building, .room, .work: review = request
        default: confirmation = request
        }
    }
}

struct RecordDeletionButton: View {
    @Environment(RecordsStore.self) private var store
    @Environment(RecordDeletionActions.self) private var actions
    let target: RecordDeletionTarget
    let title: String
    let identifier: String
    var discardsDraft = false

    var body: some View {
        Button(title, systemImage: "trash", role: .destructive) {
            do {
                let plan = try store.records.deletionPlan(for: target)
                actions.reviewFailure = nil
                actions.present(DeletionRequest(plan: plan, discardsDraft: discardsDraft))
            } catch { actions.failure = errorMessage(error) }
        }
        .disabled(store.isSaving || actions.deleting)
        .accessibilityIdentifier(identifier)
    }
}

private struct RecordDeletionPresentation: ViewModifier {
    @Environment(RecordsStore.self) private var store
    @Environment(AppNotices.self) private var notices
    @State private var actions = RecordDeletionActions()
    let onDeleted: (RecordDeletionTarget) -> Void

    func body(content: Content) -> some View {
        content
            .environment(actions)
            .sheet(isPresented: Binding(get: { actions.review != nil }, set: { if !$0 { actions.review = nil } })) {
                if let request = actions.review { review(request) }
            }
            .alert(actions.confirmation?.title ?? "", isPresented: Binding(
                get: { actions.confirmation != nil }, set: { if !$0 { actions.confirmation = nil } }
            ), presenting: actions.confirmation) { request in
                Button("削除", role: .destructive) { delete(request) }
                Button("キャンセル", role: .cancel) {}
            } message: { request in
                Text(request.message)
            }
            .alert("削除できませんでした", isPresented: Binding(
                get: { actions.failure != nil }, set: { if !$0 { actions.failure = nil } }
            )) {
                Button("閉じる", role: .cancel) {}
            } message: { Text(actions.failure ?? "") }
    }

    private func review(_ request: DeletionRequest) -> some View {
        let counts = request.counts
        return NavigationStack {
            List {
                Section("削除する記録") { Text(request.subject) }
                if !counts.isEmpty {
                    Section("一緒に削除する記録") {
                        ForEach(DeletionRecordKind.allCases, id: \.self) { kind in
                            if let count = counts[kind] { LabeledContent(kind.name, value: count.formatted()) }
                        }
                    }
                }
                if let failure = actions.reviewFailure {
                    Section { Label(failure, systemImage: "exclamationmark.circle").accessibilityIdentifier("deletion.error") }
                }
            }
            .navigationTitle(request.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark", role: .cancel) { actions.review = nil }
                        .accessibilityIdentifier("deletion.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("削除", role: .destructive) { delete(request) }
                        .accessibilityIdentifier("deletion.confirm")
                }
            }
            .disabled(actions.deleting)
            .overlay { if actions.deleting { ProgressView("削除中") } }
        }
        .presentationSizing(.page)
        .interactiveDismissDisabled(actions.deleting)
    }

    private func delete(_ request: DeletionRequest) {
        guard !actions.deleting else { return }
        actions.deleting = true
        actions.reviewFailure = nil
        Task {
            defer { actions.deleting = false }
            do {
                try await notices.delete(request.plan, store: store)
                actions.review = nil
                onDeleted(request.plan.target)
            } catch RecordDeletionError.changed(let current) {
                actions.present(DeletionRequest(plan: current, discardsDraft: request.discardsDraft))
            } catch DomainError.invalidReference {
                actions.review = nil
                onDeleted(request.plan.target)
            } catch {
                let message = deletionMessage(error)
                if actions.review != nil { actions.reviewFailure = message }
                else { actions.failure = message }
            }
        }
    }

    private func deletionMessage(_ error: any Error) -> String {
        if error as? StorageError == .unwritable {
            return "記録を削除できませんでした。もう一度お試しください。"
        }
        return errorMessage(error)
    }
}

extension View {
    func recordDeletion(onDeleted: @escaping (RecordDeletionTarget) -> Void = { _ in }) -> some View {
        modifier(RecordDeletionPresentation(onDeleted: onDeleted))
    }
}
