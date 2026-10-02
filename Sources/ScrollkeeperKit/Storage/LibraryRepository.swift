import Foundation

/// Reads and writes the catalog as JSON files in the app's data directory.
public actor LibraryRepository {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// The stored catalog. Files that are missing or unreadable give empty parts.
    public func load() -> CatalogSnapshot {
        CatalogSnapshot(
            entitlements: read("catalog.json") ?? [],
            metadata: read("metadata.json") ?? [:],
            tags: read("userdata.json") ?? [:]
        )
    }

    public func save(entitlements: [Entitlement]) throws {
        try write(entitlements, to: "catalog.json")
    }

    public func save(metadata: [String: ProductMetadata]) throws {
        try write(metadata, to: "metadata.json")
    }

    public func save(tags: [String: [String]]) throws {
        try write(tags, to: "userdata.json")
    }

    private func read<Value: Decodable>(_ name: String) -> Value? {
        guard let data = try? Data(contentsOf: directory.appending(path: name)) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    private func write(_ value: some Encodable, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: directory.appending(path: name), options: .atomic)
    }
}
