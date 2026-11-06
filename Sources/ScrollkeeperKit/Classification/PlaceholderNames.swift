import Foundation

/// Gives sensible names to editions whose name in Paizo's library is a placeholder, such as "Test" or
/// "Accidental duplicate package - disregard", while the files behind them are the real thing.
///
/// A placeholder edition takes the name of a properly named edition of the same product with the same kind of
/// file (same file type and number of files), with its own update date added so the two can be told apart: the
/// placeholder edition is sometimes the newer one. Without such an edition, the name is built from the product
/// name the way Paizo names editions: "<product> - Single File" for a PDF, the product name otherwise.
enum PlaceholderNames {
    private static let placeholder = TextPattern(
        #"^\s*(test|tbd|placeholder)\s*$|\bdisregard\b|\bdo not (use|download)\b|\baccidental(ly)? (duplicate|upload)"#
    )

    static func isPlaceholder(_ displayName: String) -> Bool {
        placeholder.matches(displayName)
    }

    /// `entitlements` (one product's) with placeholder names replaced.
    static func repairing(_ entitlements: [Entitlement]) -> [Entitlement] {
        let named = entitlements.filter { !isPlaceholder($0.displayName) }
        return entitlements.map { entitlement in
            guard isPlaceholder(entitlement.displayName), !entitlement.productName.isEmpty else { return entitlement }
            var repaired = entitlement
            if let twin = named.first(where: { isSameKind($0, entitlement) }) {
                let twinName = twin.displayName.trimmingCharacters(in: .whitespaces)
                repaired.displayName = "\(twinName) (\(updated(entitlement)))"
            } else {
                repaired.displayName = entitlement.fileExtension == "pdf"
                    ? "\(entitlement.productName) - Single File" : entitlement.productName
            }
            return repaired
        }
    }

    private static func isSameKind(_ first: Entitlement, _ second: Entitlement) -> Bool {
        first.fileExtension == second.fileExtension && first.assetCount == second.assetCount
    }

    /// "updated 2026-09-21", or the package ID when Paizo gives no date.
    private static func updated(_ entitlement: Entitlement) -> String {
        guard let date = entitlement.dateUpdated ?? entitlement.dateGranted else {
            return "package \(entitlement.packageID)"
        }
        return "updated " + dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
