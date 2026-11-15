import SwiftUI
import UniformTypeIdentifiers

struct CameraCapture: UIViewControllerRepresentable {
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
        private enum State { case picking, encoding, completed }
        private var state = State.picking
        private(set) var encodingTask: Task<Void, Never>?
        let completion: @MainActor (Data?) -> Void
        let encode: @Sendable (UIImage) -> Data?

        init(completion: @escaping @MainActor (Data?) -> Void,
             encode: @escaping @Sendable (UIImage) -> Data? = { $0.jpegData(compressionQuality: 0.85) }) {
            self.completion = completion
            self.encode = encode
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard state != .completed else { return }
            state = .completed
            encodingTask?.cancel()
            completion(nil)
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard state == .picking else { return }
            guard let image = info[.originalImage] as? UIImage else {
                imagePickerControllerDidCancel(picker)
                return
            }
            state = .encoding
            encodingTask = Task { [encode] in
                defer { encodingTask = nil }
                guard state == .encoding, !Task.isCancelled else { return }
                let data = await Task.detached(priority: .userInitiated) { encode(image) }.value
                guard state == .encoding, !Task.isCancelled else { return }
                state = .completed
                completion(data)
            }
        }
    }
}
