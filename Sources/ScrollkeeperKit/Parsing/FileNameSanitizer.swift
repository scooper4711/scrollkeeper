import Foundation

/// Turns titles into names that are safe to use as file or folder names.
enum FileNameSanitizer {
    static let maximumLength = 120

    static func sanitize(_ name: String) -> String {
        let cleaned = String(name.unicodeScalars.map { forbidden.contains($0) ? "-" : Character($0) })
        let collapsed = cleaned.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(maximumLength))
    }

    private static let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.controlCharacters)
}
