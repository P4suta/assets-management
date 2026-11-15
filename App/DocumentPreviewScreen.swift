import QuickLook
import SwiftUI

struct DocumentPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

struct DocumentPreviewScreen: View {
    let item: DocumentPreviewItem

    var body: some View {
        DocumentPreviewContent(item: item).confirmExternalNavigation()
    }
}

private struct DocumentPreviewContent: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let item: DocumentPreviewItem

    var body: some View {
        NavigationStack {
            NativeDocumentPreview(item: item) { openURL($0) }
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる", systemImage: "xmark") { dismiss() }
                            .accessibilityIdentifier("preview.close")
                    }
                }
        }
    }
}

struct NativeDocumentPreview: UIViewControllerRepresentable {
    let item: DocumentPreviewItem
    let openURL: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(item: item, openURL: openURL) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) { context.coordinator.openURL = openURL }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let item: PreviewItem
        var openURL: (URL) -> Void
        init(item: DocumentPreviewItem, openURL: @escaping (URL) -> Void) {
            self.item = PreviewItem(item)
            self.openURL = openURL
        }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { item }
        nonisolated func previewController(_ controller: QLPreviewController, shouldOpen url: URL, for item: any QLPreviewItem) -> Bool {
            Task { @MainActor [weak self] in self?.openURL(url) }
            return false
        }
    }

    final class PreviewItem: NSObject, QLPreviewItem {
        let previewItemURL: URL?
        let previewItemTitle: String?
        init(_ item: DocumentPreviewItem) {
            previewItemURL = item.url
            previewItemTitle = item.title
        }
    }
}
