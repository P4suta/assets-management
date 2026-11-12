import Foundation
import Testing
@testable import PropertyCore

@Suite struct AmountInputTests {
    @Test(arguments: [String(repeating: "0", count: 18), String(repeating: "０", count: 18), String(repeating: " ", count: 18)])
    func rawInputLengthIsBoundedBeforeNormalization(text: String) {
        #expect(throws: DomainError.invalidAmount) { try YenAmount.parse(text) }
    }

    @Test(arguments: ["1000000000001", "9223372036854775807", "1000000000000000000000000000"])
    func parsingRejectsEveryAmountAboveTheStoredLimit(text: String) {
        #expect(throws: DomainError.invalidAmount) { try YenAmount.parse(text) }
    }

    @Test(arguments: ["85000", "85,000", "８５０００", "８５，０００", " 85000\n", "０８５,０００"])
    func pastedWholeYenAmountsKeepTheirValue(text: String) throws {
        #expect(try YenAmount.parse(text) == 85_000)
    }

    @Test(arguments: ["-1", "+1", "1.5", "1e3", "1,00", "1,,000", ",100", "100,", "1234,000", "12 34", "Ⅻ", "①", "\u{0661}\u{0662}"])
    func malformedNumbersNeverBecomeAnotherAmount(text: String) {
        #expect(throws: DomainError.invalidAmount) { try YenAmount.parse(text) }
    }

    @Test(arguments: ["", " \n\t", "\u{3000}"])
    func emptyTextIsAnUnregisteredAmount(text: String) throws {
        #expect(try YenAmount.parse(text) == nil)
        #expect(AmountInput(text).isValid)
        #expect(try AmountInput(text).value() == nil)
    }

    @Test func displayedAndStoredBoundsAgree() throws {
        #expect(YenAmount.maximum == 1_000_000_000_000)
        #expect(YenAmount.maximumInputLength == 17)
        #expect(try YenAmount.checked(nil) == nil)
        for value in [0, 1, 999_999_999_999, 1_000_000_000_000] {
            #expect(try YenAmount.checked(value) == value)
            #expect(try YenAmount.parse(String(value)) == value)
            #expect(try YenAmount.parse(value.formatted(.number.locale(Locale(identifier: "en_US")))) == value)
        }
        for value in [-1, Int.min, 1_000_000_000_001, Int.max] {
            #expect(throws: DomainError.invalidAmount) { try YenAmount.checked(value) }
        }
    }

    @Test func rejectedPastesNeverSaveThePreviousOrTruncatedAmount() throws {
        for text in ["1000000000000000000000000000", String(repeating: "0", count: 100_000),
                     String(repeating: "８", count: 100_000)] {
            var input = AmountInput("85000")
            input.replace(with: text)
            #expect(input.text == "85000")
            #expect(input.issue == .tooLong)
            #expect(!input.isValid)
            #expect(throws: DomainError.invalidAmount) { try input.value() }
            input.clear()
            #expect(input == AmountInput())
            #expect(try input.value() == nil)
            input.replace(with: "８５，０００")
            #expect(input.text == "８５，０００")
            #expect(input.isValid)
            #expect(try input.value() == 85_000)
        }
    }

    @Test func exactInputLengthRemainsEditableAndCanRecover() throws {
        var input = AmountInput("1,000,000,000,000")
        #expect(input.issue == nil)
        #expect(try input.value() == 1_000_000_000_000)
        input.replace(with: "1,000,000,000,001")
        #expect(input.text == "1,000,000,000,001")
        #expect(input.issue == .invalidAmount)
        #expect(throws: DomainError.invalidAmount) { try input.value() }
        input.replace(with: "0")
        #expect(input.isValid)
        #expect(try input.value() == 0)
        input.replace(with: String(repeating: "0", count: 17))
        #expect(input.isValid)
        #expect(try input.value() == 0)
        input.replace(with: String(repeating: "0", count: 18))
        #expect(input.issue == .tooLong)
        #expect(input.text.count == 17)
        #expect(throws: DomainError.invalidAmount) { try input.value() }
    }

    @Test func boundedInputSequencesPreserveValidityAndRejectedEdits() throws {
        let alphabet = ["", "0", "9", "０", "９", ",", "，", ".", "-", "a", "\n"]
        for first in alphabet {
            for second in alphabet {
                for third in alphabet {
                    let candidate = first + second + third
                    var input = AmountInput("85000")
                    input.replace(with: candidate)
                    #expect(input.text == candidate)
                    if let expected = independentSmallAmount(candidate) {
                        #expect(input.isValid)
                        #expect(try input.value() == expected)
                    } else if candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        #expect(input.isValid)
                        #expect(try input.value() == nil)
                    } else {
                        #expect(!input.isValid)
                        #expect(throws: DomainError.invalidAmount) { try input.value() }
                    }
                    input.clear()
                    #expect(input.isValid)
                }
            }
        }
    }

    private func independentSmallAmount(_ text: String) -> Int? {
        let digits: [Character: Int] = ["0": 0, "9": 9, "０": 0, "９": 9]
        let candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return nil }
        var total = 0
        for character in candidate {
            guard let digit = digits[character] else { return nil }
            total = total * 10 + digit
        }
        return total
    }
}
