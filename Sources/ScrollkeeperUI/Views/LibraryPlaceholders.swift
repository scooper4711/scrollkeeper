import ScrollkeeperKit
import SwiftUI

/// Shown when the search and filters match nothing. With filters set, it offers to clear them.
struct NoResultsView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        if store.query.hasFilters {
            ContentUnavailableView {
                Label("No Results", systemImage: "magnifyingglass")
            } description: {
                Text(filteredDescription)
            } actions: {
                Button("Clear the Current Filters") { store.query.clearFilters() }
            }
        } else {
            ContentUnavailableView.search(text: store.query.searchText)
        }
    }

    private var filteredDescription: String {
        let search = store.query.searchText.trimmingCharacters(in: .whitespaces)
        return search.isEmpty
            ? "No titles match the current filters."
            : "Check the spelling or try a new search, or clear the current filters."
    }
}

/// Shown while there is no catalog: either no account yet, or the first sync is running.
struct EmptyLibraryView: View {
    @Environment(LibraryStore.self) private var store
    /// Opens the settings on the iPad, where they are a sheet of the window.
    let openSettings: () -> Void

    var body: some View {
        if store.account == .signedOut {
            ContentUnavailableView {
                Label("No Paizo Account", systemImage: "person.crop.circle.badge.questionmark")
            } description: {
                Text("Add your Paizo account in Settings to load your library.")
            } actions: {
                #if os(macOS)
                SettingsLink { Text("Open Settings…") }
                #else
                Button("Open Settings…", action: openSettings)
                #endif
            }
        } else if store.sync.isRunning {
            ContentUnavailableView {
                Label("Loading Your Library", systemImage: "books.vertical")
            } description: {
                Text("Listing everything you own takes a few minutes. Titles appear here as they arrive.")
            }
        } else {
            ContentUnavailableView {
                Label("No Titles", systemImage: "books.vertical")
            } description: {
                Text(store.sync.failure.isEmpty ? "Your library is empty." : store.sync.failure)
            } actions: {
                Button("Load Library") { store.startFullSync() }
            }
        }
    }
}
