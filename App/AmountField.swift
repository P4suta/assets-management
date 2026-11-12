import PropertyCore
import SwiftUI
import UIKit

struct AmountField: View {
    let title: String
    @Binding var input: AmountInput
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "yensign").accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.subheadline).foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    NativeAmountField(input: $input, title: title, identifier: identifier)
                        .frame(minHeight: 44)
                }
                if !input.text.isEmpty || !input.isValid {
                    Button { input.clear() } label: {
                        Label("入力を消去", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(title + "を消去")
                        .accessibilityIdentifier(identifier + ".clear")
                }
            }
            if let issue = input.issue {
                Label(issue == .tooLong ? "入力が長すぎます。0円から1兆円までの金額を入力してください。"
                      : errorMessage(DomainError.invalidAmount), systemImage: "exclamationmark.circle")
                    .foregroundStyle(Color(uiColor: .systemRed))
                    .accessibilityIdentifier(identifier + ".error")
                    .fixedSize(horizontal: false, vertical: true)
            } else if let amount = try? input.value() {
                Text(yen(amount)).foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("0円〜1兆円。空欄は未登録です。")
                .font(.footnote).foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: input.issue) { _, issue in
            if issue != nil { UIAccessibility.post(notification: .announcement, argument: errorMessage(DomainError.invalidAmount)) }
        }
    }
}

struct NativeAmountField: UIViewRepresentable {
    @Binding var input: AmountInput
    let title: String
    let identifier: String

    func makeCoordinator() -> Coordinator { Coordinator(input: $input) }
    func makeUIView(context: Context) -> UITextField { context.coordinator.makeField(title: title, identifier: identifier) }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.input = $input
        context.coordinator.update(field, title: title, identifier: identifier)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        return CGSize(width: width, height: max(44, uiView.intrinsicContentSize.height))
    }

    @MainActor final class Coordinator: NSObject, UITextFieldDelegate {
        var input: Binding<AmountInput>

        init(input: Binding<AmountInput>) { self.input = input }

        func makeField(title: String, identifier: String) -> UITextField {
            let field = UITextField()
            field.delegate = self
            field.keyboardType = .numberPad
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.adjustsFontForContentSizeCategory = true
            field.setContentHuggingPriority(.defaultLow, for: .horizontal)
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            field.addTarget(self, action: #selector(changed), for: .editingChanged)
            update(field, title: title, identifier: identifier)
            return field
        }

        func update(_ field: UITextField, title: String, identifier: String) {
            if field.text != input.wrappedValue.text { field.text = input.wrappedValue.text }
            field.font = .preferredFont(forTextStyle: .body, compatibleWith: field.traitCollection)
            field.textColor = .label
            field.accessibilityLabel = title
            field.accessibilityIdentifier = identifier
        }

        func textField(_ textField: UITextField, shouldChangeCharactersInRanges ranges: [NSValue], replacementString string: String) -> Bool {
            var candidate = textField.text ?? ""
            var boundary = candidate.utf16.count
            var previous: NSRange?
            let edits = ranges.map(\.rangeValue).sorted { $0.location > $1.location }
            guard !edits.isEmpty else { return false }
            for (index, edit) in edits.enumerated() {
                guard edit.location >= 0, edit.length >= 0, edit.location <= boundary,
                      edit.length <= boundary - edit.location, edit != previous,
                      let range = Range(edit, in: candidate) else { return false }
                candidate.replaceSubrange(range, with: index == 0 ? string : "")
                boundary = edit.location
                previous = edit
            }
            var proposed = input.wrappedValue
            proposed.replace(with: candidate)
            guard proposed.text == candidate else {
                input.wrappedValue = proposed
                return false
            }
            return true
        }

        @objc private func changed(_ field: UITextField) {
            input.wrappedValue.replace(with: field.text ?? "")
            if field.text != input.wrappedValue.text { field.text = input.wrappedValue.text }
        }
    }
}
