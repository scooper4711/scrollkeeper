import Foundation

/// Parses the date formats found in library data.
enum PaizoDateParser {
    /// Parses `Wed Sep 02 2026 20:52:57 GMT+0000 (Coordinated Universal Time)`, `2024-11-08 09:45:21`
    /// and `8/25/2022 15:22`. Dates without a zone are read as UTC.
    static func parse(_ text: String) -> Date? {
        let withoutZoneName = text.components(separatedBy: " (").first ?? text
        return formats.lazy.compactMap { makeFormatter($0).date(from: withoutZoneName) }.first
    }

    /// Parses the storefront's "Release Date" field, `6/26/2024 7:00:00 AM` or `8/4/2011`, to the
    /// calendar day of release, returned as noon UTC of that day.
    ///
    /// Values with a time are midnight at Paizo's offices given in UTC, so the day is read in
    /// Pacific time. Storing noon UTC lets the day be shown the same in every time zone.
    static func parseReleaseDay(_ text: String) -> Date? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var calendar = Calendar(identifier: .gregorian)
        if let moment = makeFormatter("M/d/yyyy h:mm:ss a").date(from: value) {
            calendar.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
            let day = calendar.dateComponents([.year, .month, .day], from: moment)
            return noonUTC(day)
        }
        guard let midnight = makeFormatter("M/d/yyyy").date(from: value) else { return nil }
        calendar.timeZone = .gmt
        return noonUTC(calendar.dateComponents([.year, .month, .day], from: midnight))
    }

    private static func noonUTC(_ day: DateComponents) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = day
        components.hour = 12
        return calendar.date(from: components)
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
