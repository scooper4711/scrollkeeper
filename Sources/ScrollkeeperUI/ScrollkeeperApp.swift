import ScrollkeeperKit
import SwiftUI

/// The app, shared by the Mac and the iPad.
public struct ScrollkeeperApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var updater = AppUpdater.live()
    private var store: LibraryStore { appDelegate.store }
    #else
    @State private var store = LibraryStore(environment: .forLaunch())
    #endif

    public init() {}

    public var body: some Scene {
        WindowGroup("Scrollkeeper") {
            libraryWindow
        }
        // Request links go to the app delegate, so the window group opens no window for them: a link that
        // launches the app would otherwise get a window of its own besides the one opened at launch.
        .handlesExternalEvents(matching: [])
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

    private var libraryWindow: some View {
        LibraryWindow()
            .environment(store)
        #if os(macOS)
            .environment(appDelegate.handoff)
            .frame(minWidth: 900, minHeight: 520)
            .modifier(UpdatePrompt())
            .environment(updater)
            .task {
                if SettingsStore(suiteName: "").checksForUpdatesAtLaunch {
                    await updater.checkForUpdateQuietly()
                }
            }
        #else
            .task { await store.start() }
        #endif
    }
}

#if os(macOS)
/// Owns the library on the Mac and takes the request links from other apps, so the library loads and a
/// request is answered even while no library window is open.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = LibraryStore(environment: .forLaunch())
    lazy var handoff = HandoffCoordinator(store: store)

    func applicationDidFinishLaunching(_: Notification) {
        Task { await store.start() }
    }

    func application(_: NSApplication, open urls: [URL]) {
        urls.filter { $0.scheme == HandoffRequest.scheme }.forEach(handoff.handle)
    }
}
#endif

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
