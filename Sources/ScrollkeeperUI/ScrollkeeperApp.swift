import ScrollkeeperKit
import SwiftUI

/// The app, shared by the Mac and the iPad.
public struct ScrollkeeperApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var updater = AppUpdater.live()
    private var session: LibrarySession { appDelegate.session }
    #else
    @State private var session = LibrarySession()
    #endif
    private var store: LibraryStore { session.store }

    public init() {}

    public var body: some Scene {
        WindowGroup("Scrollkeeper") {
            libraryWindow
        }
        // Request links go to the app delegate, so the window group opens no window for them: a link that
        // launches the app would otherwise get a window of its own besides the one opened at launch.
        .handlesExternalEvents(matching: [])
        .commands {
            LibraryCommands(session: session)
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
            .environment(session)
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
            .task { await session.start() }
        #endif
    }
}

#if os(macOS)
/// Owns the library on the Mac and takes the request links from other apps, so the library loads and a
/// request is answered even while no library window is open.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let session = LibrarySession()
    lazy var handoff = HandoffCoordinator(session: session)

    func applicationDidFinishLaunching(_: Notification) {
        Task { await session.start() }
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
    let session: LibrarySession
    private var store: LibraryStore { session.store }

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
