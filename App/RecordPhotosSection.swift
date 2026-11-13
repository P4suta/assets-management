import PropertyCore
import SwiftUI

struct RecordPhotosSection: View {
    @Environment(RecordsStore.self) private var store
    @Environment(RecordPhotoActions.self) private var actions
    let location: RecordLocation

    private var attachments: [Attachment] {
        store.records.attachments.filter {
            $0.buildingID == location.buildingID && $0.roomID == location.roomID && $0.workID == location.workID
        }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Group {
            Section("写真") {
                ForEach(attachments.filter { $0.kind == .photo }) { attachment in
                    Button { open(attachment) } label: { InlinePhoto(attachment: attachment) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("写真")
                        .accessibilityValue(attachment.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .accessibilityIdentifier("photo." + attachment.id.uuidString)
                }
                if actions.importing { ProgressView("写真を保存中") }
                Menu {
                    Button("写真を選択", systemImage: "photo.on.rectangle") { actions.library = true }
                        .accessibilityIdentifier("photos.library")
                    Button("カメラで撮影", systemImage: "camera") { actions.requestCamera() }
                        .accessibilityIdentifier("photos.camera")
                } label: {
                    Label("写真を追加", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .disabled(actions.importing)
                .accessibilityIdentifier("photos.add")
            }
            if attachments.contains(where: { $0.kind == .document }) {
                Section("保存済みの書類") {
                    ForEach(attachments.filter { $0.kind == .document }) { attachment in
                        Button { open(attachment) } label: { Label(attachment.name, systemImage: "doc.text") }
                    }
                }
            }
        }
    }

    private func open(_ attachment: Attachment) {
        Task {
            do {
                let title = attachment.kind == .photo
                    ? "写真 · " + attachment.createdAt.formatted(date: .abbreviated, time: .shortened) : attachment.name
                actions.preview = DocumentPreviewItem(url: try await store.attachmentURL(attachment), title: title)
            } catch { actions.failure = .opening(errorMessage(error)) }
        }
    }
}

private struct InlinePhoto: View {
    @Environment(RecordsStore.self) private var store
    @State private var image: UIImage?
    @State private var failed = false
    let attachment: Attachment

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .accessibilityIdentifier("photo.image." + attachment.id.uuidString)
            } else if failed {
                Label("写真を読み込めませんでした", systemImage: "exclamationmark.circle")
            } else {
                ProgressView("写真を読み込み中")
            }
            Text("追加日 " + attachment.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline).foregroundStyle(Color.secondary)
        }
        .task(id: attachment.id) {
            guard image == nil else { return }
            do {
                let url = try await store.attachmentURL(attachment)
                let thumbnail = try await Task.detached(priority: .userInitiated) { try PhotoProcessor.thumbnail(file: url) }.value
                image = UIImage(cgImage: thumbnail)
            } catch { failed = true }
        }
    }
}
