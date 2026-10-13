import Foundation

/// The collection API is consistent about types for most records, but older records sometimes
/// send `null`, leave a key out, or send a number where a string is expected (and the other way
/// round). These helpers read such a field without failing the whole object.
extension KeyedDecodingContainer {
    /// A string, a number written as a string, or `""` when the key is missing or `null`.
    func lossyString(_ key: Key) -> String {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        return ""
    }

    /// An integer, a string holding an integer, or `nil`.
    func lossyInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let text = try? decodeIfPresent(String.self, forKey: key) {
            return Int(text.trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// A boolean, `"true"`/`"false"`, `1`/`0`, or `false` when missing.
    func lossyBool(_ key: Key) -> Bool {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let text = try? decodeIfPresent(String.self, forKey: key) {
            return text.lowercased() == "true" || text == "1"
        }
        return false
    }

    /// An array whose `null` or missing value is read as empty, and whose elements that fail to
    /// decode are skipped.
    func lossyArray<Element: Decodable>(_ type: Element.Type, _ key: Key) -> [Element] {
        guard let items = try? decodeIfPresent([LossyElement<Element>].self, forKey: key) else {
            return []
        }
        return items.compactMap(\.value)
    }
}

/// One element of an array that is `nil` instead of failing when it does not decode.
struct LossyElement<Element: Decodable>: Decodable {
    let value: Element?

    init(from decoder: any Decoder) throws {
        value = try? Element(from: decoder)
    }
}

extension String {
    /// `nil` for an empty or whitespace-only string.
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// An absolute http(s) URL, or `nil` for an empty string.
    var httpURL: URL? {
        guard let text = nonEmpty, let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", url.host != nil
        else { return nil }
        return url
    }
}
