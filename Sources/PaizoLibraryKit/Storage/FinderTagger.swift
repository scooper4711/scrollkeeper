import Foundation

/// Reads and writes Finder tags on files.
///
/// iPadOS gives apps no way to read or set the Files app's tags, so there this does nothing
/// and tags live in the app only.
public struct FinderTagger: Sendable {
    public init() {}

    public func tags(of url: URL) -> [String] {
        #if os(macOS)
        var fresh = url
        fresh.removeAllCachedResourceValues()
        return (try? fresh.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
        #else
        return []
        #endif
    }

    public func setTags(_ tags: [String], on url: URL) throws {
        #if os(macOS)
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
        #endif
    }
}
