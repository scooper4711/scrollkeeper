import PaizoLibraryKit
import SwiftUI

/// The app, shared by the Mac and the iPad.
public struct PaizoLibraryApp: App {
    @State private var store = LibraryStore(environment: .live())

    public init() {}

    public var body: some Scene {
        WindowGroup("Paizo Library") {
            LibraryWindow()
                .environment(store)
                .task { await store.start() }
            #if os(macOS)
                .frame(minWidth: 900, minHeight: 520)
            #endif
        }
        .commands {
            LibraryCommands(store: store)
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(store)
        }
        #endif
    }
}

/// The Library menu: refresh and full reload.
struct LibraryCommands: Commands {
    let store: LibraryStore

    var body: some Commands {
        CommandMenu("Library") {
            Button("Check for New Titles") { store.startRefresh() }
                .keyboardShortcut("r")
                .disabled(!canSync)
            Button("Reload Entire Library") { store.startFullSync() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!canSync)
            Divider()
            Button("Stop Loading") { store.cancelSync() }
                .keyboardShortcut(".")
                .disabled(!store.sync.isRunning)
        }
    }

    private var canSync: Bool {
        store.account != .signedOut && !store.sync.isRunning
    }
}
