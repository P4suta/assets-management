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
        case .contactName: "氏名"
        case .historyText: "連絡内容"
        case .equipmentName: "設備名"
        }
        return name + "を入力してください。"
    case DomainError.duplicateRoom: return "部屋番号が重複しています。別の部屋番号を入力してください。"
    case DomainError.invalidDates: return "契約終了日は開始日以降の日付にしてください。"
    case DomainError.invalidAmount: return "金額は0以上の整数で入力してください。"
    case DomainError.missingRenewal: return "更新する部屋と契約内容を入力してください。"
    case StorageError.attachmentTooLarge: return "25 MB以下のファイルを選択してください。"
    case StorageError.missingAttachment: return "ファイルが見つかりません。書類一覧から追加し直してください。"
    case StorageError.unreadable, StorageError.corrupted, DomainError.unsupportedFormat:
        return "記録を読み込めませんでした。保存済みのファイルは変更していません。"
    case StoreError.busy: return "保存中です。保存が終わってから再試行してください。"
    default: return "保存できませんでした。入力内容は保持されています。再試行してください。"
    }
}

func amountValue(_ text: String) throws -> Int? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    guard value.allSatisfy(\.isNumber), let integer = Int(value), integer >= 0 else {
        throw DomainError.invalidAmount
    }
    return integer
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

struct StatusLabel: View {
    let status: WorkStatus
    var body: some View {
        Label(status.title, systemImage: status.symbol)
            .foregroundStyle(Color.accentColor)
    }
}

struct WorkRow: View {
    @Environment(RecordsStore.self) private var store
    let item: WorkItem
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title).foregroundStyle(Color.primary)
            Text(store.records.locationText(item)).font(.subheadline).foregroundStyle(Color.secondary)
            ViewThatFits(in: .horizontal) {
                HStack { status; deadline }
                VStack(alignment: .leading, spacing: 8) { status; deadline }
            }
            .font(.footnote)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
    private var status: some View { StatusLabel(status: item.status) }
    @ViewBuilder private var deadline: some View {
        if let dueDate = item.dueDate {
            Text("期限 " + dueDate.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(Color.secondary)
        }
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
            Text(title).font(.subheadline).foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: $text, axis: multiline || textSize.isAccessibilitySize ? .vertical : .horizontal)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 4)
    }
}

struct AdaptivePickerStyle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var textSize

    @ViewBuilder func body(content: Content) -> some View {
        if textSize.isAccessibilitySize { content.pickerStyle(.inline) }
        else { content.pickerStyle(.automatic) }
    }
}
