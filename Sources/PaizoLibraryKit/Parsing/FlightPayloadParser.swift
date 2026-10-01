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
        let payload = chunkPattern.allFirstCaptures(in: html).map(decodeStringLiteral).joined()
        for row in payload.split(separator: "\n") {
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

    private let chunkPattern = TextPattern(#"self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)"#)

    private func decodeStringLiteral(_ literal: String) -> String {
        (try? JSONDecoder().decode(String.self, from: Data(literal.utf8))) ?? ""
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
