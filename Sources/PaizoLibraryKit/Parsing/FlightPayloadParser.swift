import Foundation

public enum PayloadError: Error, Equatable, LocalizedError {
    case entitlementsMissing

    public var errorDescription: String? {
        "Reading the library page failed: Paizo's page did not contain a list of titles."
    }
}

/// Extracts the library listing from the HTML of Paizo's library page.
///
/// The page embeds its data as React Server Component chunks: `self.__next_f.push([1,"…"])`.
/// Joined together they form newline-separated rows, one of which carries the listing.
public struct FlightPayloadParser: Sendable {
    public init() {}

    public func parsePage(html: String) throws -> LibraryPage {
        for row in payload(in: html).split(separator: "\n") {
            if let page = decodePage(row: row) {
                return page
            }
        }
        throw PayloadError.entitlementsMissing
    }

    private struct PageProperties: Decodable {
        let entitlements: [Lossy<EntitlementRecord>]
        let count: Int?
        let tokenExpired: Bool?
    }

    /// What every chunk starts with, up to and including the opening quote of its string literal.
    private static let chunkMarker = "self.__next_f.push([1,\""
    private static let quote = UInt8(ascii: "\"")
    private static let backslash = UInt8(ascii: "\\")

    /// The chunks joined into one text. The string literals are joined before they are decoded,
    /// so an escape sequence that Paizo's server split across two chunks is whole again.
    ///
    /// The literals are found by scanning, not with a regular expression: one chunk can hold
    /// hundreds of kilobytes, which is more than the regular expression engine will backtrack over.
    private func payload(in html: String) -> String {
        var contents = ""
        var searchStart = html.startIndex
        while let marker = html.range(of: Self.chunkMarker, range: searchStart..<html.endIndex),
              let end = endOfStringLiteral(in: html, from: marker.upperBound) {
            contents += html[marker.upperBound..<end]
            searchStart = end
        }
        let literal = "\"" + contents + "\""
        return (try? JSONDecoder().decode(String.self, from: Data(literal.utf8))) ?? ""
    }

    /// The index of the unescaped quote that closes the string literal starting at `start`.
    private func endOfStringLiteral(in html: String, from start: String.Index) -> String.Index? {
        var isEscaped = false
        var index = start
        let bytes = html.utf8
        while index < bytes.endIndex {
            let byte = bytes[index]
            if isEscaped {
                isEscaped = false
            } else if byte == Self.backslash {
                isEscaped = true
            } else if byte == Self.quote {
                return index
            }
            index = bytes.index(after: index)
        }
        return nil
    }

    private func decodePage(row: Substring) -> LibraryPage? {
        guard let separator = row.firstIndex(of: ":"), row.contains("\"entitlements\"") else { return nil }
        let value = Data(row[row.index(after: separator)...].utf8)
        guard let element = try? JSONSerialization.jsonObject(with: value) as? [Any],
              let properties = element.last as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: properties),
              let decoded = try? JSONDecoder().decode(PageProperties.self, from: data)
        else { return nil }
        let entitlements = decoded.entitlements.compactMap(\.wrapped?.entitlement)
        return LibraryPage(
            entitlements: entitlements,
            totalCount: decoded.count ?? entitlements.count,
            tokenExpired: decoded.tokenExpired ?? false
        )
    }
}
