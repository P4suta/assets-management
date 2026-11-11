import Foundation
import Testing
@testable import PropertyCore

@Test func registrationCreatesLinkedBuildingAndRoom() throws {
    let draft = RegistrationDraft(name: "桜通りレジデンス", roomNumber: "203")
    let result = try Records().registering(draft)
    #expect(result.buildings.count == 1)
    #expect(result.rooms.count == 1)
    #expect(result.rooms[0].buildingID == result.buildings[0].id)
}

@Test func validationRejectsBlankRequiredFields() {
    #expect(throws: DomainError.required(.buildingName)) {
        try Records().registering(RegistrationDraft(name: "  ", roomNumber: "203"))
    }
    #expect(throws: DomainError.required(.roomNumber)) {
        try Records().registering(RegistrationDraft(name: "桜通り", roomNumber: ""))
    }
}
