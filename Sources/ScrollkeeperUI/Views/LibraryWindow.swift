import ScrollkeeperKit
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
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @AppStorage("viewMode") private var viewMode = ViewMode.covers
    @AppStorage("showInspector") private var showInspector = LibraryWindow.showsInspectorAtFirst
    @State private var selection: LibraryTitle.ID?
    /// An iPhone's details sheet, open while a title is chosen. Not kept between launches like `showInspector`,
    /// which would open an empty sheet at launch.
    @State private var showsPhoneDetails = false

    /// - Parameter selecting: the title to show in the details at first; used for previews.
    init(selecting title: LibraryTitle.ID? = nil) {
        _selection = State(initialValue: title)
    }
    /// Raised each time a search or filter change leaves nothing to show while filters are set.
    @State private var filterPulse = 0
    @State private var showSettings = false

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            catalog
                .modifier(SpacePreview(selection: selection))
                .safeAreaInset(edge: .bottom, spacing: 0) { SyncStatusBar() }
                .navigationTitle(title)
            #if os(macOS)
                .navigationSubtitle(subtitle)
            #else
                .navigationBarTitleDisplayMode(.inline)
            #endif
                // The toolbar and search field belong to the library, not to the split view:
                // iPadOS only shows toolbar items that are attached inside a navigation column.
                .toolbar { toolbar }
                .searchable(text: $store.query.searchText, prompt: "Title, author, SKU, series or tag")
                .inspector(isPresented: showsOneColumn ? $showsPhoneDetails : $showInspector) {
                    TitleDetailView(item: store.item(id: selection))
                        .inspectorColumnWidth(min: 300, ideal: 360, max: 520)
                }
        }
        #if !os(macOS)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .toolbar { Button("Done") { showSettings = false } }
            }
            .environment(store)
        }
        #endif
        #if os(macOS)
        .modifier(HandoffHandler(selection: $selection))
        #endif
        #if !os(macOS)
        // On the iPad the details cover part of the library, so they open when a title is chosen.
        .onChange(of: selection) { _, chosen in
            guard chosen != nil else { return }
            if showsOneColumn {
                showsPhoneDetails = true
            } else {
                showInspector = true
            }
        }
        // Choosing the same title again opens its details again.
        .onChange(of: showsPhoneDetails) { _, isShown in
            if !isShown { selection = nil }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            DownloadContinuity.sceneChanged(to: phase, store: store)
        }
        .onChange(of: store.pendingDownloadCount) { _, pending in
            DownloadContinuity.pendingChanged(to: pending)
        }
        .onChange(of: filtersLeaveNothing) { _, leavesNothing in
            if leavesNothing {
                filterPulse += 1
            }
        }
    }

    // On the iPad the middle of the bar holds the title, so the view picker sits with the buttons.
    #if os(macOS)
    private static let showsInspectorAtFirst = true
    private static let viewPickerPlacement = ToolbarItemPlacement.principal
    #else
    private static let showsInspectorAtFirst = false
    private static let viewPickerPlacement = ToolbarItemPlacement.topBarLeading
    private static let viewPickerWidth: CGFloat = 168
    #endif

    /// True when nothing is shown and a filter is set, so clearing the filters may bring titles back.
    private var filtersLeaveNothing: Bool {
        !store.items.isEmpty && store.visibleItems.isEmpty && store.query.hasFilters
    }

    @ViewBuilder private var catalog: some View {
        if store.items.isEmpty {
            EmptyLibraryView { showSettings = true }
        } else if store.visibleItems.isEmpty {
            NoResultsView()
        } else {
            switch viewMode {
            case .covers: CoverGridView(selection: $selection)
            case .list: TitleListView(selection: $selection)
            // A phone is too narrow for the columns, so it shows the list.
            case .columns where showsOneColumn: TitleListView(selection: $selection)
            case .columns: TitleTableView(selection: $selection)
            }
        }
    }

    /// Whether the window shows one column at a time, as on an iPhone. Read here, outside the split view, because
    /// the columns have a compact width on the iPad too.
    private var showsOneColumn: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if showsOneColumn {
            phoneToolbar
        } else {
            fullToolbar
        }
    }

    /// An iPhone's bar has room for the title and two buttons; the rest is in a menu. Choosing a title opens its
    /// details there, so it has no Details button.
    @ToolbarContentBuilder private var phoneToolbar: some ToolbarContent {
        ToolbarItem { FilterMenu(pulse: filterPulse) }
        ToolbarItem { DownloadsButton() }
        ToolbarItem {
            Menu {
                Picker("View", selection: $viewMode) {
                    ForEach([ViewMode.covers, .list]) { mode in
                        Label(mode.label, systemImage: mode.symbolName).tag(mode)
                    }
                }
                refreshButton
                settingsButton
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
    }

    @ToolbarContentBuilder private var fullToolbar: some ToolbarContent {
        ToolbarItem(placement: Self.viewPickerPlacement) {
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbolName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            #if !os(macOS)
            // iPadOS 26 squeezes a toolbar item to a circle unless it is given its width.
            .frame(width: Self.viewPickerWidth)
            #endif
            .help("Show the library as covers, a list or columns")
        }
        ToolbarItem { FilterMenu(pulse: filterPulse) }
        ToolbarItem { DownloadsButton() }
        ToolbarItem { refreshButton }
        #if !os(macOS)
        ToolbarItem { settingsButton }
        #endif
        ToolbarItem {
            Button {
                showInspector.toggle()
            } label: {
                Label("Details", systemImage: "sidebar.trailing")
            }
            .help("Show or hide the details of the selected title")
        }
    }

    private var refreshButton: some View {
        Button {
            store.startRefresh()
        } label: {
            Label("Check for New Titles", systemImage: "arrow.clockwise")
        }
        .disabled(store.account == .signedOut || store.sync.isRunning)
        .help("Check Paizo for titles added since the last sync")
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape")
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
