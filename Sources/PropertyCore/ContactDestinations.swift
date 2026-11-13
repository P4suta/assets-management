import Foundation

extension Contact {
    public var telephoneURL: URL? {
        var number = ""
        var hasDigit = false
        for scalar in phone.unicodeScalars {
            switch scalar.value {
            case 48...57:
                number.unicodeScalars.append(scalar)
                hasDigit = true
            case 0xFF10...0xFF19:
                guard let digit = Unicode.Scalar(scalar.value - 0xFF10 + 48) else { return nil }
                number.unicodeScalars.append(digit)
                hasDigit = true
            case 43, 0xFF0B:
                guard number.isEmpty else { return nil }
                number.append("+")
            case 32, 0xA0, 0x3000, 40, 41, 0xFF08, 0xFF09, 45, 0x2212, 0xFF0D, 46: continue
            default: return nil
            }
        }
        return hasDigit ? URL(string: "tel:" + number) : nil
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
