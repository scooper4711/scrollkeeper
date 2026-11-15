import ScrollkeeperKit
import SwiftUI

/// The scopes of the library with their title counts.
struct SidebarView: View {
    /// Whether the window shows one column at a time, as on an iPhone, where the sidebar is a page of its own.
    let showsOneColumn: Bool
    @Environment(LibraryStore.self) private var store
    /// Set when Back leaves the library for the sidebar on an iPhone. The scope is kept, so the library still
    /// shows it, but the list shows no selection: a selection there would open the library again.
    @State private var isShowingSidebarAlone = false

    var body: some View {
        List(selection: scopeSelection) {
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
        // The layout can widen, as when an iPad leaves Slide Over, and then the list shows the scope again.
        .onChange(of: showsOneColumn) { isShowingSidebarAlone = false }
    }

    private func row(_ scope: LibraryScope, _ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .badge(store.facets.count(for: scope))
            .tag(scope)
    }

    /// The list needs an optional selection. An emptied selection means Back on an iPhone, which shows the sidebar;
    /// elsewhere it falls back to all titles.
    private var scopeSelection: Binding<LibraryScope?> {
        Binding(get: { isShowingSidebarAlone ? nil : store.query.scope }, set: choose)
    }

    private func choose(_ scope: LibraryScope?) {
        if let scope {
            isShowingSidebarAlone = false
            store.query.scope = scope
        } else if showsOneColumn {
            isShowingSidebarAlone = true
        } else {
            store.query.scope = .all
        }
    }
}
