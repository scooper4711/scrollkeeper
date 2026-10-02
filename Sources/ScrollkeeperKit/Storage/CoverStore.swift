import Foundation

/// Cover artwork cached on disk, one image per SKU.
public struct CoverStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func url(sku: String) -> URL {
        directory.appending(path: FileNameSanitizer.sanitize(sku) + ".jpg")
    }

    public func hasCover(sku: String) -> Bool {
        FileManager.default.fileExists(atPath: url(sku: sku).path)
    }

    /// Saves the image. A cover that cannot be written is simply fetched again next time.
    public func store(_ data: Data, sku: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(sku: sku), options: .atomic)
    }
}
