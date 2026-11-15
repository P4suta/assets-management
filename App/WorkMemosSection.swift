import PropertyCore
import SwiftUI

struct WorkMemosSection: View {
    @Environment(RecordsStore.self) private var store
    let item: WorkItem
    let edit: (UUID?) -> Void

    private var entries: [HistoryEntry] {
        store.records.history.filter { $0.workID == item.id }.sorted { $0.date < $1.date }
    }

    var body: some View {
        Section("メモ") {
            if !item.notes.isEmpty { Text(item.notes) }
            ForEach(entries) { entry in
                Button { edit(entry.id) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.text).foregroundStyle(Color.primary)
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(Color.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("memo." + entry.id.uuidString)
            }
            Button("メモを追加", systemImage: "plus") { edit(nil) }
                .accessibilityIdentifier("memo.add")
        }
    }
}
