import Foundation

extension Records {
    public func matchingContacts(query: String) -> [Contact] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = Self.searchText(query)
        let digits = Self.phoneDigits(query)
        return contacts.filter { contact in
            let fields = [contact.name, contact.company, contact.phone, contact.email, contact.notes]
                + relatedBuildings(for: contact.id).map(\.name)
            return query.isEmpty || fields.contains { Self.searchText($0).contains(normalized) }
                || (!digits.isEmpty && digits.count == query.filter(\.isNumber).count
                    && query.allSatisfy { $0.isNumber || $0.isWhitespace || "+-−ー()（）".contains($0) }
                    && Self.phoneDigits(contact.phone).contains(digits))
        }.sorted { left, right in
            if left.isEmergency != right.isEmergency { return left.isEmergency }
            let order = left.name.compare(right.name, options: [.caseInsensitive, .widthInsensitive, .numeric],
                                          locale: Locale(identifier: "ja_JP"))
            if order != .orderedSame { return order == .orderedAscending }
            return left.id.uuidString < right.id.uuidString
        }
    }

    public func relatedBuildings(for contactID: UUID) -> [Building] {
        guard let contact = contacts.first(where: { $0.id == contactID }) else { return [] }
        var identifiers = Set(contact.buildingIDs)
        identifiers.formUnion(buildings.filter { $0.agencyContactID == contactID }.map(\.id))
        identifiers.formUnion(rooms.filter { $0.residentID == contactID }.map(\.buildingID))
        let historyWorkIDs = Set(history.filter { $0.contactID == contactID }.map(\.workID))
        identifiers.formUnion(work.filter { $0.contractorID == contactID || historyWorkIDs.contains($0.id) }.map(\.buildingID))
        return buildings.filter { identifiers.contains($0.id) }
    }

    public func removingContact(_ id: UUID) throws -> Records {
        guard contacts.contains(where: { $0.id == id }) else { throw DomainError.invalidReference }
        var result = self
        result.contacts.removeAll { $0.id == id }
        for index in result.buildings.indices where result.buildings[index].agencyContactID == id {
            result.buildings[index].agencyContactID = nil
        }
        for index in result.rooms.indices where result.rooms[index].residentID == id {
            result.rooms[index].residentID = nil
        }
        for index in result.work.indices where result.work[index].contractorID == id {
            result.work[index].contractorID = nil
        }
        for index in result.history.indices where result.history[index].contactID == id {
            result.history[index].contactID = nil
        }
        return try result.validated()
    }

    private static func phoneDigits(_ value: String) -> String {
        value.compactMap(\.wholeNumberValue).map(String.init).joined()
    }

    private static func searchText(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                      locale: Locale(identifier: "ja_JP"))
    }
}
