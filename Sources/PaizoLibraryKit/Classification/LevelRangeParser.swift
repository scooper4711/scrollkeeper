import Foundation

/// Reads the character levels an adventure is written for from its summary.
enum LevelRangeParser {
    static func parse(_ text: String) -> ClosedRange<Int>? {
        let plain = TitleNormalizer.plainPunctuation(text)
        for pattern in rangePatterns {
            let captures = pattern.captures(in: plain)
            if captures.count == 3, let low = Int(captures[1]), let high = Int(captures[2]), isPlausible(low, high) {
                return low...high
            }
        }
        let single = singlePattern.captures(in: plain)
        if single.count == 2, let level = Int(single[1]), isPlausible(level, level) {
            return level...level
        }
        return nil
    }

    private static let ordinal = #"(\d{1,2})(?:st|nd|rd|th)?"#
    private static let rangePatterns = [
        TextPattern(ordinal + #"[\s-]*(?:-|through|to)[\s-]*"# + ordinal + #"[\s-]+level"#),
        TextPattern(#"\b(?:levels?|tiers?)\s+(\d{1,2})\s*(?:-|to|through)\s*(\d{1,2})\b"#)
    ]
    private static let singlePattern = TextPattern(
        #"\bfor\s+(?:\w+\s+)?"# + ordinal + #"[\s-]+level\s+(?:characters|pcs|heroes)"#
    )

    private static func isPlausible(_ low: Int, _ high: Int) -> Bool {
        (1...25).contains(low) && (low...25).contains(high)
    }
}
