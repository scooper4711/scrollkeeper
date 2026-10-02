import Foundation

/// A case-insensitive regular expression with string-based helpers.
struct TextPattern: Sendable {
    private let regex: NSRegularExpression

    init(_ pattern: String) {
        // Patterns are constants in this module; an invalid one matches nothing.
        regex = (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])) ?? NSRegularExpression()
    }

    func matches(_ text: String) -> Bool {
        regex.firstMatch(in: text, range: fullRange(of: text)) != nil
    }

    /// The whole match followed by its capture groups, or an empty array when there is no match.
    func captures(in text: String) -> [String] {
        guard let match = regex.firstMatch(in: text, range: fullRange(of: text)) else { return [] }
        return (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }

    /// The first capture group of every match.
    func allFirstCaptures(in text: String) -> [String] {
        regex.matches(in: text, range: fullRange(of: text)).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    func removingMatches(in text: String) -> String {
        regex.stringByReplacingMatches(in: text, range: fullRange(of: text), withTemplate: "")
    }

    private func fullRange(of text: String) -> NSRange {
        NSRange(text.startIndex..., in: text)
    }
}
