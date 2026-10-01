import Foundation

/// Reads the author from a product summary: `Written by Kate Baker.` or a line `by Tim Hitchcock`.
enum AuthorParser {
    static func parse(_ summary: String) -> String {
        let text = TitleNormalizer.plainPunctuation(summary)
        for pattern in patterns {
            let captures = pattern.captures(in: text)
            if captures.count == 2 {
                let names = leadingNames(in: captures[1])
                if !names.isEmpty {
                    return names
                }
            }
        }
        return ""
    }

    // "by" only counts at the start of a line or straight after a quoted chapter title, so that
    // phrases such as "used by experienced GMs" are not taken for a credit.
    private static let patterns = [
        TextPattern(#"\bwritten by\s+([^\r\n]+)"#),
        TextPattern(#"(?:^|[\r\n]|["”]\s*,?\s*)by\s+([^\r\n]+)"#)
    ]
    private static let runTogether = TextPattern(#"^([^.]{3,})\.[A-Za-z]"#)
    private static let connectors: Set<String> = ["and", "&", "de", "del", "la", "van", "von"]

    /// The words of `text` up to where the list of names ends.
    private static func leadingNames(in text: String) -> String {
        var names: [String] = []
        for word in text.split(separator: " ").map(String.init) {
            guard isNameWord(word) else { break }
            let unjoined = runTogether.captures(in: word)
            if unjoined.count == 2 {
                // "Helt.Cover": the next sentence follows without a space.
                names.append(unjoined[1])
                break
            }
            names.append(word)
            if endsSentence(word) {
                break
            }
        }
        while let last = names.last, connectors.contains(last.lowercased()) {
            names.removeLast()
        }
        return names.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: ".,;: "))
    }

    private static func isNameWord(_ word: String) -> Bool {
        connectors.contains(word.lowercased()) || word.first?.isUppercase == true
    }

    /// A full stop ends the names unless it follows an initial or a short abbreviation: `A.`, `St.`.
    private static func endsSentence(_ word: String) -> Bool {
        word.hasSuffix(".") && word.count > 3
    }
}
