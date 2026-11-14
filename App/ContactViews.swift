import PropertyCore
import SwiftUI

struct ContactListView: View {
    @Binding var selection: UUID?
    @Environment(RecordsStore.self) private var store
    @State private var query = ""
    @State private var category: ContactCategory?
    @State private var editor: EditorDestination?

    private var contacts: [Contact] {
        store.records.matchingContacts(query: query).filter { category == nil || $0.category == category }
    }

    var body: some View {
        let matching = contacts
        List(selection: $selection) {
            if matching.isEmpty {
                ContentUnavailableView {
                    Label(store.records.contacts.isEmpty ? "連絡先をまとめましょう" : "連絡先が見つかりません",
                          systemImage: "person.crop.rectangle.stack")
                } description: {
                    Text(store.records.contacts.isEmpty ? "管理会社、保険、設備の相談先を記録できます。" : "検索語や種類を変更してください。")
                } actions: {
                    if store.records.contacts.isEmpty { Button("連絡先を追加") { editor = .contact(nil, .none) } }
                }
            }
            contactSection("緊急連絡先", contacts: matching.filter(\.isEmergency))
            contactSection("連絡先", contacts: matching.filter { !$0.isEmergency })
        }
        .accessibilityIdentifier("contacts.list")
        .navigationTitle("連絡先")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "検索")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("種類", selection: $category) {
                        Text("すべて").tag(ContactCategory?.none)
                        ForEach(ContactCategory.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                    }
                } label: {
                    Label(category?.title ?? "種類", systemImage: category == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityIdentifier("contacts.category")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("連絡先を追加", systemImage: "plus") { editor = .contact(nil, .none) }
                    .accessibilityIdentifier("contacts.add")
            }
        }
        .editorPresentation($editor)
    }

    @ViewBuilder private func contactSection(_ title: String, contacts: [Contact]) -> some View {
        if !contacts.isEmpty {
            Section(title) {
                ForEach(contacts) { contact in
                    NavigationLink(value: contact.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(contact.name).recordForeground(Color.primary, selected: selection == contact.id)
                                .accessibilityIdentifier("contact.caption.name")
                            Text(contact.category.title + (contact.company.isEmpty ? "" : " · " + contact.company))
                                .font(.subheadline).recordForeground(Color.secondary, selected: selection == contact.id)
                                .accessibilityIdentifier("contact.caption.category")
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                    .accessibilityIdentifier(selection == contact.id ? "contact.row.selected" : "contact.row")
                }
            }
        }
    }
}
