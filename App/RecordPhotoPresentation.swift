import AVFoundation
import PhotosUI
import PropertyCore
import SwiftUI

enum RecordPhotoFailure {
    case importing(String), opening(String)

    var title: String {
        switch self {
        case .importing: "写真を追加できませんでした"
        case .opening: "ファイルを開けませんでした"
        }
    }

    var message: String {
        switch self {
        case .importing(let message), .opening(let message): message
        }
    }
}

@MainActor @Observable final class RecordPhotoActions {
    var photo: PhotosPickerItem?
    var library = false
    var camera = false
    var cameraDenied = false
    var cameraUnavailable = false
    var importing = false
    var failure: RecordPhotoFailure?
    var preview: DocumentPreviewItem?

    func requestCamera() {
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

private struct RecordPhotoPresentation: ViewModifier {
    @Environment(RecordsStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var actions = RecordPhotoActions()
    let location: RecordLocation?

    func body(content: Content) -> some View {
        @Bindable var actions = actions
        content
            .environment(actions)
            .photosPicker(isPresented: $actions.library, selection: $actions.photo, matching: .images)
            .onChange(of: actions.photo) { _, item in
                guard let item else { return }
                Task { await importPhoto(item) }
            }
            .fullScreenCover(isPresented: $actions.camera) {
                CameraCapture { data in
                    actions.camera = false
                    guard let data else { return }
                    Task { await saveCamera(data) }
                }.ignoresSafeArea()
            }
            .sheet(item: $actions.preview) { DocumentPreviewScreen(item: $0) }
            .alert("カメラへのアクセスを許可してください", isPresented: $actions.cameraDenied) {
                Button("設定を開く") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("写真を選択") { actions.library = true }
                Button("キャンセル", role: .cancel) {}
            } message: { Text("撮影する場合は、設定からカメラへのアクセスを許可してください。") }
            .alert("カメラを使用できません", isPresented: $actions.cameraUnavailable) {
                Button("写真を選択") { actions.library = true }
                Button("閉じる", role: .cancel) {}
            } message: { Text("写真ライブラリから追加できます。") }
            .alert(actions.failure?.title ?? "処理できませんでした", isPresented: Binding(get: { actions.failure != nil }, set: { if !$0 { actions.failure = nil } }), presenting: actions.failure) { failure in
                if case .importing = failure { Button("写真を選び直す") { actions.library = true } }
                Button("閉じる", role: .cancel) {}
            } message: { Text($0.message) }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        actions.importing = true
        defer { actions.importing = false; actions.photo = nil }
        do {
            guard let location else { throw DomainError.invalidReference }
            guard let value = try await item.loadTransferable(type: ImportedPhoto.self) else { throw PhotoProcessingError.invalidImage }
            try await save(value.data, at: location)
        } catch { actions.failure = .importing(photoError(error)) }
    }

    private func saveCamera(_ data: Data) async {
        actions.importing = true
        defer { actions.importing = false }
        do {
            guard let location else { throw DomainError.invalidReference }
            let prepared = try await Task.detached(priority: .userInitiated) { try PhotoProcessor.prepare(data: data) }.value
            try await save(prepared, at: location)
        } catch { actions.failure = .importing(photoError(error)) }
    }

    private func save(_ data: Data, at location: RecordLocation) async throws {
        try await store.importAttachment(data, name: "写真", extension: "jpg", kind: .photo, location: location)
    }

    private func photoError(_ error: any Error) -> String {
        error is PhotoProcessingError ? "写真を読み込めませんでした。別の写真を選択してください。"
            : "写真を保存できませんでした。もう一度写真を選択して再試行してください。"
    }
}

extension View {
    func recordPhotosPresentation(at location: RecordLocation?) -> some View { modifier(RecordPhotoPresentation(location: location)) }
}
