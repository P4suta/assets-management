import QuickLook
import SwiftUI

struct DocumentPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

struct DocumentPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    let item: DocumentPreviewItem

    var body: some View {
        NavigationStack {
            NativeDocumentPreview(item: item)
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

private struct NativeDocumentPreview: UIViewControllerRepresentable {
    let item: DocumentPreviewItem
    func makeCoordinator() -> Coordinator { Coordinator(item: item) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let item: PreviewItem
        init(item: DocumentPreviewItem) { self.item = PreviewItem(item) }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { item }
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
