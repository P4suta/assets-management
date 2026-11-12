import PropertyCore
import SwiftUI
import Testing
import UIKit
@testable import PropertyRecords

@Suite @MainActor struct NativeAmountFieldTests {
    @MainActor private final class InputBox {
        var input: AmountInput
        init(_ text: String) { input = AmountInput(text) }
        var binding: Binding<AmountInput> { Binding(get: { self.input }, set: { self.input = $0 }) }
    }

    @Test(arguments: ["1000000000000000000000000000", String(repeating: "８", count: 10_000)])
    func pastesAreRejectedBeforeChangingTheNativeField(text: String) throws {
        let box = InputBox("85000")
        let coordinator = NativeAmountField.Coordinator(input: box.binding)
        let field = coordinator.makeField(title: "金額", identifier: "amount")
        #expect(!coordinator.textField(field, shouldChangeCharactersInRanges: [NSValue(range: NSRange(location: 0, length: 5))], replacementString: text))
        #expect(field.text == "85000")
        #expect(box.input.text == "85000")
        #expect(box.input.issue == .tooLong)
        #expect(throws: DomainError.invalidAmount) { try box.input.value() }
        coordinator.update(field, title: "金額", identifier: "amount")
        #expect(box.input.issue == .tooLong)
        #expect(throws: DomainError.invalidAmount) { try box.input.value() }
        box.input.clear()
        coordinator.update(field, title: "金額", identifier: "amount")
        #expect(field.text == "")
        #expect(box.input.isValid)
    }

    @Test func nativeEditsUpdateTheSameValidatedInput() throws {
        let box = InputBox("")
        let coordinator = NativeAmountField.Coordinator(input: box.binding)
        let field = coordinator.makeField(title: "金額", identifier: "amount")
        for text in ["８５，０００", "1,000,000,000,001", "0", ""] {
            #expect(coordinator.textField(field, shouldChangeCharactersInRanges: [NSValue(range: NSRange(location: 0, length: (field.text ?? "").utf16.count))],
                                          replacementString: text))
            field.text = text
            field.sendActions(for: .editingChanged)
            #expect(box.input.text == text)
            #expect(box.input.isValid == (text != "1,000,000,000,001"))
        }
        #expect(try box.input.value() == nil)
        #expect(field.keyboardType == .numberPad)
        #expect(field.adjustsFontForContentSizeCategory)
        #expect(field.accessibilityIdentifier == "amount")
        #expect(field.accessibilityLabel == "金額")
    }

    @Test func nativeDeletionUsesUTF16RangesAndPreservesOtherDigits() throws {
        let box = InputBox("８５０００")
        let coordinator = NativeAmountField.Coordinator(input: box.binding)
        let field = coordinator.makeField(title: "金額", identifier: "amount")
        #expect(coordinator.textField(field, shouldChangeCharactersInRanges: [NSValue(range: NSRange(location: 1, length: 1))], replacementString: ""))
        field.text = "８０００"
        field.sendActions(for: .editingChanged)
        #expect(try box.input.value() == 8_000)
        #expect(!coordinator.textField(field, shouldChangeCharactersInRanges: [NSValue(range: NSRange(location: 99, length: 1))], replacementString: "0"))
        #expect(try box.input.value() == 8_000)
    }

    @Test func noncontiguousEditsInsertTheReplacementOnlyOnce() throws {
        let box = InputBox("123456")
        let coordinator = NativeAmountField.Coordinator(input: box.binding)
        let field = coordinator.makeField(title: "金額", identifier: "amount")
        let ranges = [NSRange(location: 0, length: 2), NSRange(location: 4, length: 2)].map(NSValue.init(range:))
        #expect(coordinator.textField(field, shouldChangeCharactersInRanges: ranges, replacementString: "1234567890"))
        for actualText in ["123456789034", "341234567890"] {
            field.text = actualText
            field.sendActions(for: .editingChanged)
            #expect(try box.input.value() == Int(actualText))
        }
    }

    @Test func invalidNativeRangesCannotChangeTheFieldOrInput() {
        let box = InputBox("123456")
        let coordinator = NativeAmountField.Coordinator(input: box.binding)
        let field = coordinator.makeField(title: "金額", identifier: "amount")
        let invalid: [[NSRange]] = [[], [NSRange(location: NSNotFound, length: 1)],
                                   [NSRange(location: 0, length: Int.max)],
                                   [NSRange(location: 0, length: 3), NSRange(location: 2, length: 2)],
                                   [NSRange(location: 1, length: 0), NSRange(location: 1, length: 0)]]
        for ranges in invalid {
            #expect(!coordinator.textField(field, shouldChangeCharactersInRanges: ranges.map(NSValue.init(range:)), replacementString: "0"))
            #expect(field.text == "123456")
            #expect(box.input == AmountInput("123456"))
        }
    }

    @Test func nativeChangesCannotBypassTheBoundedInput() {
        let box = InputBox("85000")
        let coordinator = NativeAmountField.Coordinator(input: box.binding)
        let field = coordinator.makeField(title: "金額", identifier: "amount")
        for _ in 0..<2 {
            field.text = String(repeating: "9", count: 1000)
            field.sendActions(for: .editingChanged)
            #expect(field.text == "85000")
            #expect(box.input.issue == .tooLong)
            #expect(throws: DomainError.invalidAmount) { try box.input.value() }
        }
    }
}
