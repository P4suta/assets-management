import Observation
import SwiftUI

enum ExternalNavigationHandling: Equatable {
    case confirmation, system, ignored
}

@MainActor @Observable final class ExternalNavigation {
    private(set) var destination: URL?
    var isPresented = false
    var failure: URL?

    func request(_ url: URL) -> ExternalNavigationHandling {
        guard destination == nil else { return .ignored }
        if url.scheme?.lowercased() == "tel" { return .system }
        failure = nil
        destination = url
        isPresented = true
        return .confirmation
    }

    func cancel() {
        destination = nil
        isPresented = false
    }

    func confirm() -> URL? {
        let value = destination
        cancel()
        return value
    }

    func openConfirmed(using open: OpenURLAction) {
        guard let url = confirm() else { return }
        open(url) { accepted in
            if !accepted { self.failure = url }
        }
    }

    static func description(for url: URL) -> String {
        url.scheme?.lowercased() == "app-settings" ? "設定App" : url.absoluteString
    }
}

private struct SystemOpenURLKey: EnvironmentKey {
    static let defaultValue: OpenURLAction? = nil
}

private extension EnvironmentValues {
    var systemOpenURL: OpenURLAction? {
        get { self[SystemOpenURLKey.self] }
        set { self[SystemOpenURLKey.self] = newValue }
    }
}

private struct ExternalNavigationConfirmation: ViewModifier {
    @Environment(\.openURL) private var systemOpenURL
    @Environment(\.systemOpenURL) private var inheritedSystemOpenURL
    @State private var navigation = ExternalNavigation()

    func body(content: Content) -> some View {
        @Bindable var navigation = navigation
        let open = inheritedSystemOpenURL ?? systemOpenURL
        content
            .environment(\.systemOpenURL, open)
            .environment(\.openURL, OpenURLAction { url in
                switch navigation.request(url) {
                case .confirmation: .handled
                case .system: .systemAction(url)
                case .ignored: .discarded
                }
            })
            .alert("外部リンクを開く", isPresented: $navigation.isPresented, presenting: navigation.destination) { _ in
                Button("開く") { navigation.openConfirmed(using: open) }
                Button("キャンセル", role: .cancel) { navigation.cancel() }
            } message: { url in
                Text(ExternalNavigation.description(for: url))
            }
            .alert("リンクを開けませんでした", isPresented: Binding(get: { navigation.failure != nil }, set: { if !$0 { navigation.failure = nil } })) {
                Button("閉じる", role: .cancel) { navigation.failure = nil }
            } message: { Text("リンク先や対応するAppを確認してください。") }
    }
}

extension View {
    func confirmExternalNavigation() -> some View { modifier(ExternalNavigationConfirmation()) }
}
