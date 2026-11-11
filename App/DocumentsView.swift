import AVFoundation
import PhotosUI
import PropertyCore
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    @Environment(RecordsStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var filePicker = false
    @State private var photo: PhotosPickerItem?
    @State private var camera = false
    @State private var cameraDenied = false
    @State private var cameraUnavailable = false
    @State private var preview: DocumentPreviewItem?
    @State private var failure: String?
    @State private var importing = false
    let location: RecordLocation

    private var attachments: [Attachment] {
        store.records.attachments.filter {
            $0.buildingID == location.buildingID &&
                (location.roomID == nil || $0.roomID == location.roomID) &&
                (location.workID == nil || $0.workID == location.workID)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if attachments.isEmpty {
                ContentUnavailableView("写真・書類はありません", systemImage: "doc.text",
                                       description: Text("写真やPDFを追加して、物件や対応に関連付けて保存できます。"))
            }
            Section {
                ForEach(attachments) { attachment in
                    Button { open(attachment) } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(attachment.name).foregroundStyle(Color.primary)
                                Text(attachment.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline).foregroundStyle(Color.secondary)
                            }.padding(.vertical, 4)
                        } icon: {
                            Image(systemName: attachment.kind == .photo ? "photo" : "doc.text").foregroundStyle(Color.primary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(attachment.kind == .photo ? "写真" : "書類")
                    .accessibilityValue(attachment.name + "、" + attachment.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityHint("内容を表示します")
                    .accessibilityIdentifier("document." + attachment.id.uuidString)
                }
            }
            Section {
                PhotosPicker(selection: $photo, matching: .images) { Label("写真を選択", systemImage: "photo") }
                Button("ファイルを選択", systemImage: "doc.text") { filePicker = true }
                    .accessibilityIdentifier("documents.import")
                Button("カメラで撮影", systemImage: "camera") { requestCamera() }
                    .accessibilityIdentifier("documents.camera")
            } footer: { Text("写真・書類は端末内に保存します。ファイルの上限は25 MBです。") }
            if importing { ProgressView("ファイルを保存中") }
        }
        .navigationTitle("写真・書類")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(importing)
        .fileImporter(isPresented: $filePicker, allowedContentTypes: [.pdf, .jpeg, .png, .heic, .plainText]) { result in
            switch result {
            case .success(let url): Task { await importURL(url) }
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled { failure = errorMessage(error) }
            }
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraCapture { data in
                camera = false
                guard let data else { return }
                Task { await saveData(data, name: "現地写真.jpg", extension: "jpg", kind: .photo) }
            }.ignoresSafeArea()
        }
        .sheet(item: $preview) { DocumentPreviewScreen(item: $0) }
        .alert("カメラへのアクセスを許可してください", isPresented: $cameraDenied) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("ファイルを選択") { filePicker = true }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("撮影する場合は、設定からカメラへのアクセスを許可してください。") }
        .alert("カメラを使用できません", isPresented: $cameraUnavailable) {
            Button("ファイルを選択") { filePicker = true }
            Button("閉じる", role: .cancel) {}
        } message: { Text("写真やファイルを選択して追加できます。") }
        .alert("ファイルを開けませんでした", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("別のファイルを選択") { filePicker = true }
            Button("閉じる", role: .cancel) {}
        } message: { Text(failure ?? "") }
    }

    private func open(_ attachment: Attachment) {
        Task {
            do { preview = DocumentPreviewItem(url: try await store.attachmentURL(attachment), title: attachment.name) }
            catch { failure = errorMessage(error) }
        }
    }

    private func importURL(_ url: URL) async {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let handle = try FileHandle(forReadingFrom: url)
            let data: Data
            do {
                data = try handle.read(upToCount: FileRecordsRepository.maximumAttachmentBytes + 1) ?? Data()
                try handle.close()
            } catch {
                try? handle.close()
                throw error
            }
            let type = UTType(filenameExtension: url.pathExtension)
            await saveData(data, name: url.lastPathComponent, extension: url.pathExtension,
                           kind: type?.conforms(to: .image) == true ? .photo : .document)
        } catch { failure = errorMessage(error) }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        importing = true
        defer { importing = false; photo = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  data.count <= FileRecordsRepository.maximumAttachmentBytes,
                  let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.85) else {
                throw StorageError.attachmentTooLarge
            }
            try await store.importAttachment(jpeg, name: "現地写真.jpg", extension: "jpg", kind: .photo, location: location)
        } catch { failure = errorMessage(error) }
    }

    private func saveData(_ data: Data, name: String, extension fileExtension: String, kind: AttachmentKind) async {
        importing = true
        defer { importing = false }
        do { try await store.importAttachment(data, name: name, extension: fileExtension, kind: kind, location: location) }
        catch { failure = errorMessage(error) }
    }

    private func requestCamera() {
        Task {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if status == .denied || status == .restricted { cameraDenied = true; return }
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { cameraUnavailable = true; return }
            var allowed = status == .authorized
            if status == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
            if allowed { camera = true } else { cameraDenied = true }
        }
    }
}

private struct CameraCapture: UIViewControllerRepresentable {
    let completion: @MainActor (Data?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.mediaTypes = [UTType.image.identifier]
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: @MainActor (Data?) -> Void
        init(completion: @escaping @MainActor (Data?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.85))
        }
    }
}
