import Foundation

/// Reduces entitlement names to the product title they belong to.
enum TitleNormalizer {
    /// Strips SKU prefixes and format or edition suffixes: `PZO12007E NPC Core PDF - Single File` → `NPC Core`.
    static func baseTitle(_ name: String) -> String {
        var title = leadingSKU.removingMatches(in: plainPunctuation(name))
        var previous = ""
        while title != previous {
            previous = title
            title = trailingSuffixes.reduce(title) { $1.removingMatches(in: $0) }
        }
        return title.trimmingCharacters(in: .whitespaces)
    }

    /// Replaces typographic apostrophes and dashes so that patterns only deal with ASCII ones.
    static func plainPunctuation(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
    }

    /// Detects the edition kind from the entitlement name, tolerating the misspellings found in the data.
    static func editionKind(displayName: String, fileExtension: String) -> EditionKind {
        let isLite = litePattern.matches(displayName)
        if perChapterPattern.matches(displayName) {
            return isLite ? .liteFilePerChapter : .filePerChapter
        }
        if singleFilePattern.matches(displayName) {
            return isLite ? .liteSingleFile : .singleFile
        }
        return fileExtension == "epub" ? .epub : .other
    }

    /// Lowercased letters and digits only, for comparing names that differ in punctuation.
    static func comparisonKey(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    private static let leadingSKU = TextPattern(#"^\s*PZO[A-Z0-9-]+E?\s+(-\s+)?"#)
    private static let litePattern = TextPattern(#"\blite\b"#)
    private static let perChapterPattern = TextPattern(#"file[\s-]*per[\s-]*cha\w+"#)
    private static let singleFilePattern = TextPattern(#"sing[el]{2}[\s-]*file"#)
    private static let trailingSuffixes = [
        TextPattern(#"\s*-?\s*\(?(lite\s+)?(sing[el]{2}[\s-]*file|file[\s-]*per[\s-]*cha\w+)\)?\s*$"#),
        TextPattern(#"\s*-?\s*\(?download\)?\s*$"#),
        TextPattern(#"\s*-?\s*\(?pdfs?\)?\s*$"#),
        TextPattern(#"\s*-?\s*\(?epub\)?/?\s*$"#)
    ]
}
