import SwiftUI
import UIKit

struct EditorSheet<Fields: View>: View {
    @Environment(\.dismiss) private var dismiss
    @State private var discard = false
    @State private var saving = false
    @State private var message: String?
    let title: String
    let dirty: Bool
    let save: @MainActor () async throws -> Void
    @ViewBuilder let fields: () -> Fields

    var body: some View {
        NavigationStack {
            Form {
                if let message {
                    Section {
                        Label(message, systemImage: "exclamationmark.circle")
                            .foregroundStyle(Color(uiColor: .systemRed))
                            .accessibilityIdentifier("editor.error")
                    }
                }
                fields()
            }
            .disabled(saving)
            .modifier(AdaptivePickerStyle())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", systemImage: "xmark", role: .cancel) {
                        if dirty { discard = true } else { dismiss() }
                    }
                    .disabled(saving)
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", systemImage: "checkmark") { attemptSave() }
                        .disabled(saving)
                        .accessibilityIdentifier("editor.save")
                }
            }
            .overlay { if saving { ProgressView("保存中") } }
        }
        .interactiveDismissDisabled(dirty || saving)
        .background(DismissAttemptObserver(blocked: dirty || saving) { if !saving { discard = true } })
        .alert("変更を破棄しますか？", isPresented: $discard) {
            Button("変更を破棄", role: .destructive) { dismiss() }
            Button("編集を続ける", role: .cancel) {}
        } message: { Text("入力内容は保存されません。") }
    }

    private func attemptSave() {
        saving = true
        message = nil
        Task { @MainActor in
            do { try await save(); dismiss() }
            catch {
                let feedback = errorMessage(error)
                message = feedback
                UIAccessibility.post(notification: .announcement, argument: feedback)
            }
            saving = false
        }
    }
}

private struct DismissAttemptObserver: UIViewControllerRepresentable {
    let blocked: Bool
    let onAttempt: @MainActor () -> Void

    func makeUIViewController(context: Context) -> AttemptController { AttemptController() }
    func updateUIViewController(_ controller: AttemptController, context: Context) {
        controller.blocked = blocked
        controller.onAttempt = onAttempt
        controller.installDelegate()
    }

    final class AttemptController: UIViewController, UIAdaptivePresentationControllerDelegate {
        var blocked = false
        var onAttempt: (@MainActor () -> Void)?
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installDelegate()
        }
        func installDelegate() {
            var owner: UIViewController = self
            while let parent = owner.parent { owner = parent }
            owner.presentationController?.delegate = self
        }
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool { !blocked }
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { onAttempt?() }
    }
}
