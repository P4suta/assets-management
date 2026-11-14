import SwiftUI

struct EditorPresentation<Editor: View>: ViewModifier {
    @Environment(AppNotices.self) private var notices
    @Binding var destination: EditorDestination?
    @State private var activeID: UUID?
    @ViewBuilder let editor: (EditorDestination) -> Editor

    func body(content: Content) -> some View {
        content
            .sheet(item: $destination, onDismiss: dismissed, content: editor)
            .onAppear { trackPresentation() }
            .onChange(of: destination?.id) { _, _ in trackPresentation() }
    }

    private func trackPresentation() {
        guard let destination, activeID != destination.id else { return }
        notices.beginEditing(destination.id)
        if let activeID { notices.endEditing(activeID) }
        activeID = destination.id
    }

    private func dismissed() {
        guard destination == nil, let activeID else { return }
        self.activeID = nil
        notices.endEditing(activeID)
    }
}

extension View {
    func editorPresentation(_ destination: Binding<EditorDestination?>) -> some View {
        modifier(EditorPresentation(destination: destination) { EditorDestinationView(destination: $0) })
    }
}
