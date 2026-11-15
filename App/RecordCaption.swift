import SwiftUI

struct RecordCaption: View {
    let role: RecordCaptionRole
    let text: String
    var symbol: String?
    var selected = false

    var body: some View {
        content
            .recordForeground(color, selected: selected)
            .symbolRenderingMode(.monochrome)
            .accessibilityIdentifier(role.rawValue)
    }

    @ViewBuilder private var content: some View {
        if let symbol {
            Label { Text(verbatim: text) } icon: { Image(systemName: symbol) }
        } else {
            Text(verbatim: text)
        }
    }

    private var color: Color {
        switch role {
        case .workTitle, .contactName: .primary
        case .workStatus: .accentColor
        case .workLocation, .workDeadline, .contactCategory: .secondary
        }
    }
}
