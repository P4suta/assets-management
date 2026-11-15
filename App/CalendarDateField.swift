import SwiftUI

struct CalendarDateField: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @State private var presented = false
    private let title: LocalizedStringKey
    @Binding private var selection: Date

    init(_ title: LocalizedStringKey, selection: Binding<Date>) {
        self.title = title
        _selection = selection
    }

    private var format: Date.FormatStyle {
        var format = Date.FormatStyle().year().month(.twoDigits).day(.twoDigits)
        format.calendar = calendar
        format.locale = locale
        format.timeZone = timeZone
        return format
    }

    var body: some View {
        Button { presented = true } label: {
            LabeledContent {
                Text(selection, format: format).font(.body).foregroundStyle(Color.primary)
            } label: { Text(title).font(.body) }
        }
        .accessibilityLabel(Text(title))
        .accessibilityValue(selection.formatted(format))
        .popover(isPresented: $presented) {
            NavigationStack {
                ScrollView {
                    DatePicker(title, selection: $selection, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了", systemImage: "checkmark") { presented = false }
                            .labelStyle(.iconOnly)
                            .accessibilityIdentifier("date.done")
                    }
                }
            }
            .frame(idealWidth: 360, idealHeight: 520)
        }
    }
}
