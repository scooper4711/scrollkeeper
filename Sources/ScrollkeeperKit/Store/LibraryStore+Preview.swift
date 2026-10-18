import Foundation

extension LibraryStore {
    /// What Space previews for a title: the files of the copy Open would open, the book before its maps
    /// and posters, or else its cover; empty when there is neither.
    public func previewFiles(for item: LibraryTitle) -> [URL] {
        if let target = quickActions(for: item).open {
            let files = locator.files(in: target)
            if !files.isEmpty { return files }
        }
        return covers.hasCover(sku: item.sku) ? [covers.url(sku: item.sku)] : []
    }
}
