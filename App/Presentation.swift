import Foundation
import PropertyCore
import SwiftUI

extension WorkStatus {
    var title: String {
        switch self {
        case .notStarted: "未着手"
        case .inProgress: "対応中"
        case .waiting: "返答待ち"
        case .completed: "完了"
        }
    }
    var symbol: String {
        switch self {
        case .notStarted: "circle"
        case .inProgress: "clock"
        case .waiting: "bubble.left"
        case .completed: "checkmark"
        }
    }
}

extension WorkKind {
    var title: String {
        switch self {
        case .repair: "修繕"
        case .renewal: "契約更新"
        case .inspection: "点検"
        }
    }
}

extension ManagementMode {
    var title: String { self == .selfManaged ? "自主管理" : "委託管理" }
}

extension ContactCategory {
    var title: String {
        switch self {
        case .resident: "入居者"
        case .maintenance: "メンテナンス"
        case .management: "管理会社"
        case .insurance: "保険"
        case .fireSafety: "消防・防災"
        case .other: "その他"
        }
    }
}

extension CommunicationMethod {
    var title: String {
        switch self {
        case .phone: "電話"
        case .email: "メール"
        case .visit: "訪問"
        case .other: "その他"
        }
    }
}

func errorMessage(_ error: any Error) -> String {
    switch error {
    case DomainError.required(let field):
        let name: String = switch field {
        case .buildingName: "建物名"
        case .roomNumber: "部屋番号"
        case .workTitle: "対応内容"
        case .contactName: "名称"
        case .historyText: "メモ"
        case .equipmentName: "設備名"
        }
        return name + "を入力してください。"
    case DomainError.duplicateRoom: return "部屋番号が重複しています。別の部屋番号を入力してください。"
    case DomainError.invalidDates: return "契約終了日は開始日以降の日付にしてください。"
    case DomainError.invalidNotice: return "予告期限と事前通知の日数を確認してください。"
    case DomainError.invalidAmount: return "金額は0円から1兆円までの整数で入力してください。"
    case DomainError.missingRenewal: return "更新する部屋と契約内容を入力してください。"
    case StorageError.attachmentTooLarge: return "25 MiB以下のファイルを選択してください。"
    case StorageError.missingAttachment: return "ファイルが見つかりません。保存元の写真やバックアップを確認してください。"
    case StorageError.unreadable, StorageError.corrupted, DomainError.unsupportedFormat:
        return "記録を読み込めませんでした。保存済みのファイルは変更していません。"
    case StoreError.busy: return "保存中です。保存が終わってから再試行してください。"
    case StoreError.notLoaded: return "記録を読み込んでから再試行してください。"
    case is CancellationError: return "処理を中止しました。再試行してください。"
    default: return "保存できませんでした。入力内容は保持されています。再試行してください。"
    }
}

func yen(_ value: Int?) -> String {
    guard let value else { return "未登録" }
    return value.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
}

extension Records {
    func locationText(_ item: WorkItem) -> String {
        let name = buildings.first { $0.id == item.buildingID }?.name ?? ""
        let room = rooms.first { $0.id == item.roomID }
        return name + " · " + (room.map { $0.number + "号室" } ?? "共用部分")
    }
}

extension View {
    func contentAlignedRowSeparator() -> some View {
        alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
    }

    func recordForeground(_ color: Color, selected: Bool) -> some View {
        foregroundStyle(RecordForegroundStyle(color: color, selected: selected))
    }
}

private struct RecordForegroundStyle: ShapeStyle {
    let color: Color
    let selected: Bool

    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        guard selected else {
            return AnyShapeStyle(environment.colorSchemeContrast == .increased ? Color.primary : color)
        }
        guard environment.backgroundProminence == .increased else { return AnyShapeStyle(Color.primary) }
        var contrasted = environment
        contrasted.colorScheme = environment.colorScheme == .dark ? .light : .dark
        return AnyShapeStyle(Color.primary.resolve(in: contrasted))
    }
}

struct StatusLabel: View {
    let status: WorkStatus
    var selected = false
    var body: some View {
        Label(status.title, systemImage: status.symbol)
            .recordForeground(Color.accentColor, selected: selected)
            .symbolRenderingMode(.monochrome)
            .accessibilityIdentifier("work.caption.status")
    }
}

struct WorkRow: View {
    @Environment(RecordsStore.self) private var store
    let item: WorkItem
    var selected = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title).recordForeground(Color.primary, selected: selected)
            Text(store.records.locationText(item)).font(.subheadline).recordForeground(Color.secondary, selected: selected)
                .accessibilityIdentifier("work.caption.location")
            ViewThatFits(in: .horizontal) {
                HStack { status; deadline }
                VStack(alignment: .leading, spacing: 8) { status; deadline }
            }
            .font(.footnote)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(selected ? "work.row.selected" : "work.row")
    }
    private var status: some View { StatusLabel(status: item.status, selected: selected) }
    @ViewBuilder private var deadline: some View {
        if let dueDate = item.dueDate {
            Text("期限 " + dueDate.formatted(date: .abbreviated, time: .omitted))
                .fixedSize(horizontal: false, vertical: true)
                .recordForeground(Color.secondary, selected: selected)
                .accessibilityIdentifier("work.caption.deadline")
        }
    }
}

struct SelectionField<Value: Hashable, Options: View>: View {
    let title: LocalizedStringKey
    let value: String
    @Binding var selection: Value
    @ViewBuilder let options: () -> Options

    var body: some View {
        Menu {
            Picker(title, selection: $selection, content: options)
                .pickerStyle(.inline)
        } label: {
            LabeledContent {
                Text(value).fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Color.accentColor)
            } label: {
                Text(title).foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .menuIndicator(.visible)
        .accessibilityLabel(Text(title))
        .accessibilityValue(value)
    }
}

struct InputField: View {
    @Environment(\.dynamicTypeSize) private var textSize
    let title: String
    @Binding var text: String
    var identifier: String = ""
    var multiline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title)).font(.subheadline).foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            TextField("", text: $text, axis: multiline || textSize.isAccessibilitySize ? .vertical : .horizontal)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 4)
    }
}
