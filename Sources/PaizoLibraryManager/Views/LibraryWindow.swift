import PaizoLibraryKit
import SwiftUI

enum ViewMode: String, CaseIterable, Identifiable {
    case covers
    case list
    case columns

    var id: String { rawValue }

    var label: String {
        switch self {
        case .covers: "Covers"
        case .list: "List"
        case .columns: "Columns"
        }
    }

    var symbolName: String {
        switch self {
        case .covers: "square.grid.2x2"
        case .list: "list.bullet"
        case .columns: "tablecells"
        }
    }
}

/// The main window: sidebar of scopes, the catalog in the chosen view, and a detail inspector.
struct LibraryWindow: View {
    @Environment(LibraryStore.self) private var store
    @AppStorage("viewMode") private var viewMode = ViewMode.covers
    @AppStorage("showInspector") private var showInspector = true
    @State private var selection: LibraryTitle.ID?

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            catalog
                .safeAreaInset(edge: .bottom, spacing: 0) { SyncStatusBar() }
                .navigationTitle(title)
                .navigationSubtitle(subtitle)
        }
        .searchable(text: $store.query.searchText, prompt: "Title, SKU, series, summary or tag")
        .inspector(isPresented: $showInspector) {
            TitleDetailView(item: store.item(id: selection))
                .inspectorColumnWidth(min: 300, ideal: 360, max: 520)
        }
        .toolbar { toolbar }
    }

    @ViewBuilder private var catalog: some View {
        if store.items.isEmpty {
            EmptyLibraryView()
        } else if store.visibleItems.isEmpty {
            ContentUnavailableView.search(text: store.query.searchText)
        } else {
            switch viewMode {
            case .covers: CoverGridView(selection: $selection)
            case .list: TitleListView(selection: $selection)
            case .columns: TitleTableView(selection: $selection)
            }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("Show the library as covers, a list or columns")
        }
        ToolbarItem { FilterMenu() }
        ToolbarItem {
            Button {
                store.startRefresh()
            } label: {
                Label("Check for New Titles", systemImage: "arrow.clockwise")
            }
            .disabled(store.account == .signedOut || store.sync.isRunning)
            .help("Check Paizo for titles added since the last sync")
        }
        ToolbarItem {
            Button {
                showInspector.toggle()
            } label: {
                Label("Details", systemImage: "sidebar.trailing")
            }
            .help("Show or hide the details of the selected title")
        }
    }

    private var title: String {
        switch store.query.scope {
        case .all: "All Titles"
        case .downloaded: "Downloaded"
        case let .productLine(line): line.label
        case let .gameSystem(system): system.label
        case let .tag(tag): tag
        }
    }

    private var subtitle: String {
        let shown = store.visibleItems.count
        return shown == store.items.count ? "\(shown) titles" : "\(shown) of \(store.items.count) titles"
    }
}

/// Shown while there is no catalog: either no account yet, or the first sync is running.
struct EmptyLibraryView: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        if store.account == .signedOut {
            ContentUnavailableView {
                Label("No Paizo Account", systemImage: "person.crop.circle.badge.questionmark")
            } description: {
                Text("Add your Paizo account in Settings to load your library.")
            } actions: {
                SettingsLink { Text("Open Settings…") }
            }
        } else if store.sync.isRunning {
            ContentUnavailableView {
                Label("Loading Your Library", systemImage: "books.vertical")
            } description: {
                Text("Paizo takes a while to list everything you own. Titles appear here as they arrive.")
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
