import Foundation
import Testing
@testable import PropertyCore

@Suite struct ContactDestinationTests {
    @Test(arguments: [(" (０３) １２３４−５６７８ ", "tel:0312345678"),
                      ("＋８１（３）１２３４－５６７８", "tel:+81312345678"),
                      ("119", "tel:119"), ("+1 (408) 555.5555", "tel:+14085555555"),
                      ("090ー1234ー5678", "tel:09012345678")])
    func telephoneFormattingPreservesTheIntendedDigits(example: (String, String)) {
        let contact = Contact(name: "受付", phone: example.0)
        #expect(contact.telephoneURL?.absoluteString == example.1)
        #expect(contact.phone == example.0)
    }

    @Test(arguments: ["", "   ", "+", "++81312345678", "03-1234-5678 内線42", "03-1234-5678\n090-1234-5678",
                      "*123#", "①0312345678", "03;090", "03?123", "03/090"])
    func unrecognizedTelephoneTextNeverBecomesAnotherNumber(value: String) {
        let contact = Contact(name: "受付", phone: value)
        #expect(contact.telephoneURL == nil)
        #expect(contact.phone == value)
    }

    @Test(arguments: ["qa@example.invalid", "qa+tag@example.invalid", "what?now&next=ok@example.invalid",
                      "percent%value@example.invalid", "user@例え.jp"])
    func mailboxCharactersCannotBecomeMessageHeaders(value: String) throws {
        let contact = Contact(name: "受付", email: value)
        let destination = try #require(contact.emailURL)
        let components = try #require(URLComponents(url: destination, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "mailto")
        #expect(components.path == value)
        #expect(components.query == nil)
        #expect(components.fragment == nil)
        #expect(contact.email == value)
        if value.contains("?") { #expect(destination.absoluteString.contains("%3F")) }
        if value.contains("&") { #expect(destination.absoluteString.contains("%26")) }
        if value.contains("=") { #expect(destination.absoluteString.contains("%3D")) }
    }

    @Test(arguments: ["", " ", "qa", "@example.invalid", "qa@", "qa@example.invalid,other@example.invalid",
                      "qa@example.invalid;other@example.invalid", "qa\r\n@example.invalid", "qa @example.invalid",
                      "qa@@example.invalid", "qa;other@example.invalid"])
    func unrecognizedMailboxTextRemainsARecordWithoutAnExternalAction(value: String) {
        let contact = Contact(name: "受付", email: value)
        #expect(contact.emailURL == nil)
        #expect(contact.email == value)
    }
}
