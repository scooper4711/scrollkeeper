import Foundation

/// Reads and writes Finder tags on files.
public struct FinderTagger: Sendable {
    public init() {}

    public func tags(of url: URL) -> [String] {
        var fresh = url
        fresh.removeAllCachedResourceValues()
        return (try? fresh.resourceValues(forKeys: [.tagNamesKey]).tagNames) ?? []
    }

    public func setTags(_ tags: [String], on url: URL) throws {
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }
}
