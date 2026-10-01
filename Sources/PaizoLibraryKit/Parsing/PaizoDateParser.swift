import Foundation

/// Parses the date formats found in library data.
enum PaizoDateParser {
    /// Parses `Wed Sep 02 2026 20:52:57 GMT+0000 (Coordinated Universal Time)`, `2024-11-08 09:45:21`
    /// and `8/25/2022 15:22`. Dates without a zone are read as UTC.
    static func parse(_ text: String) -> Date? {
        let withoutZoneName = text.components(separatedBy: " (").first ?? text
        return formats.lazy.compactMap { makeFormatter($0).date(from: withoutZoneName) }.first
    }

    private static let formats = ["EEE MMM dd yyyy HH:mm:ss 'GMT'Z", "yyyy-MM-dd HH:mm:ss", "M/d/yyyy HH:mm"]

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = format
        return formatter
    }
}
