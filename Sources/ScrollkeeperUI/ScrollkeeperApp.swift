import ScrollkeeperKit
import SwiftUI

/// The app, shared by the Mac and the iPad.
public struct ScrollkeeperApp: App {
    @State private var store = LibraryStore(environment: .forLaunch())
    #if os(macOS)
    @State private var updater = AppUpdater.live()
    #endif

    public init() {}

    public var body: some Scene {
        WindowGroup("Scrollkeeper") {
            LibraryWindow()
                .environment(store)
                .task { await store.start() }
            #if os(macOS)
                .frame(minWidth: 900, minHeight: 520)
                .modifier(UpdatePrompt())
                .environment(updater)
                .task {
                    if SettingsStore(suiteName: "").checksForUpdatesAtLaunch {
                        await updater.checkForUpdateQuietly()
                    }
                }
            #endif
        }
        .commands {
            LibraryCommands(store: store)
            #if os(macOS)
            AboutCommands(updater: updater)
            #endif
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(store)
        }
        #endif
    }
}

#if os(macOS)
/// The About panel with Paizo's required notice, and Help menu links.
struct AboutCommands: Commands {
    @Environment(\.openURL) private var openURL
    let updater: AppUpdater

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AboutInfo.appName)") { AboutInfo.showAboutPanel() }
            Button("Check for Updates…") {
                Task { await updater.checkForUpdate() }
            }
            .disabled(updater.state.isBusy)
        }
        CommandGroup(replacing: .help) {
            if let policy = AboutInfo.policyURL {
                Button("Paizo's Community Use Policy") { openURL(policy) }
            }
            if let donation = AboutInfo.donationURL {
                Button("Support Development on Ko-fi") { openURL(donation) }
            }
        }
    }
}
#endif

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
