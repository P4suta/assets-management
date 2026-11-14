import SwiftUI

enum AppInformation {
    static let privacyURL = URL(string: "https://assets-management.yasunobu.dev/privacy/")
    static let supportURL = URL(string: "https://assets-management.yasunobu.dev/support/")
}

struct AppInformationView: View {
    @Environment(\.dismiss) private var dismiss
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("物件管理くん").font(.title2).bold()
                    LabeledContent("バージョン", value: version)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("バージョン")
                        .accessibilityValue(version)
                    Text("修繕・契約更新・点検と、建物や部屋の記録を管理できます。")
                }
                Section("記録とプライバシー") {
                    Text("記録と添付ファイルは端末内に保存します。開発者への自動送信、広告、利用状況の解析はありません。")
                        .accessibilityIdentifier("app-info.records")
                    Text("端末のバックアップに記録が含まれる場合があります。バックアップは端末の設定で管理してください。")
                    if let url = AppInformation.privacyURL {
                        Link(destination: url) { Label("プライバシーポリシー", systemImage: "hand.raised") }
                            .accessibilityIdentifier("app-info.privacy")
                    }
                }
                Section {
                    if let url = AppInformation.supportURL {
                        Link(destination: url) { Label("使い方とお問い合わせ", systemImage: "questionmark.circle") }
                            .accessibilityIdentifier("app-info.support")
                    }
                } footer: { Text("案内はWebサイトで表示します。記録や写真が自動で送信されることはありません。") }
                Section { Text("© 2026 Yasunobu Sakashita").accessibilityIdentifier("app-info.copyright") }
            }
            .accessibilityIdentifier("app-info.list")
            .navigationTitle("アプリについて")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", systemImage: "xmark", role: .cancel) { dismiss() }
                        .labelStyle(.iconOnly).accessibilityIdentifier("app-info.close")
                }
            }
        }
        .confirmExternalNavigation()
    }
}
