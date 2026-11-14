import Foundation

extension Contact {
    public var telephoneURL: URL? {
        normalizedPhoneNumber(phone).flatMap { URL(string: "tel:" + $0) }
    }

    public var emailURL: URL? {
        let address = email.trimmingCharacters(in: .whitespaces)
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }),
              !address.contains(where: { $0.isWhitespace || $0 == "," || $0 == ";" }),
              address.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              let encoded = address.addingPercentEncoding(withAllowedCharacters:
                CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~@")) else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.percentEncodedPath = encoded
        return components.url
    }
}

func normalizedPhoneNumber(_ value: String) -> String? {
    var number = ""
    var hasDigit = false
    for scalar in value.unicodeScalars {
        switch scalar.value {
        case 48...57, 0xFF10...0xFF19:
            guard let digit = Character(String(scalar)).wholeNumberValue else { return nil }
            number.append(String(digit))
            hasDigit = true
        case 43, 0xFF0B:
            guard number.isEmpty else { return nil }
            number.append("+")
        case 32, 0xA0, 0x3000, 40, 41, 0xFF08, 0xFF09, 45, 0x2212, 0xFF0D, 0x30FC, 46: continue
        default: return nil
        }
    }
    return hasDigit ? number : nil
}
