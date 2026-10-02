import PaizoLibraryKit
import SwiftUI

/// The scopes of the library with their title counts.
struct SidebarView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List(selection: scopeSelection($store.query.scope)) {
            Section("Library") {
                row(.all, "All Titles", symbol: "books.vertical")
                row(.downloaded, "Downloaded", symbol: "arrow.down.circle")
            }
            Section("Type") {
                ForEach(ProductLine.allCases.filter { store.facets.count(for: .productLine($0)) > 0 }) { line in
                    row(.productLine(line), line.label, symbol: line.symbolName)
                }
            }
            Section("Game") {
                ForEach(GameSystem.allCases.filter { store.facets.count(for: .gameSystem($0)) > 0 }) { system in
                    row(.gameSystem(system), system.label, symbol: "dice")
                }
            }
            if !store.facets.sortedTags.isEmpty {
                Section("Tags") {
                    ForEach(store.facets.sortedTags, id: \.self) { tag in
                        row(.tag(tag), tag, symbol: "tag")
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(_ scope: LibraryScope, _ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .badge(store.facets.count(for: scope))
            .tag(scope)
    }

    /// The list needs an optional selection; an emptied selection falls back to all titles.
    private func scopeSelection(_ scope: Binding<LibraryScope>) -> Binding<LibraryScope?> {
        Binding(get: { scope.wrappedValue }, set: { scope.wrappedValue = $0 ?? .all })
    }
}
