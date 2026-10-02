import Foundation

extension LibraryStore {
    /// Every tag in use, for suggestions.
    public var allTags: [String] { facets.sortedTags }

    public func addTag(_ tag: String, to itemID: LibraryTitle.ID) {
        let name = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let item = item(id: itemID), !item.tags.contains(name) else { return }
        setTags(item.tags + [name], for: item)
    }

    public func removeTag(_ tag: String, from itemID: LibraryTitle.ID) {
        guard let item = item(id: itemID), item.tags.contains(tag) else { return }
        setTags(item.tags.filter { $0 != tag }, for: item)
    }

    /// Stores the tags and writes them to the title's downloaded files as Finder tags.
    private func setTags(_ tags: [String], for item: LibraryTitle) {
        snapshot.tags[item.id] = tags.isEmpty ? nil : tags
        for file in locator.localFiles(for: item) {
            try? tagger.setTags(tags, on: file)
        }
        rebuildItems()
        saveTags()
    }

    /// Picks up Finder tags that were added to downloaded files outside the app.
    func importFinderTags() {
        var changed = false
        for item in items where downloadedItemIDs.contains(item.id) {
            let onFiles = locator.localFiles(for: item).flatMap(tagger.tags)
            let added = Set(onFiles).subtracting(item.tags).sorted()
            if !added.isEmpty {
                snapshot.tags[item.id] = item.tags + added
                changed = true
            }
        }
        if changed {
            rebuildItems()
            saveTags()
        }
    }

    private func saveTags() {
        let tags = snapshot.tags
        persist { try await $0.save(tags: tags) }
    }
}
