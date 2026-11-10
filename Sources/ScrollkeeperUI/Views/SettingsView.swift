import ScrollkeeperKit
import SwiftUI
import TablesideShared

#if os(macOS)
import AppKit
#endif

/// Account and download folder settings: a tabbed window on the Mac, one form on the iPad.
struct SettingsView: View {
    var body: some View {
        #if os(macOS)
        TabView {
            Form { AccountSettings() }
                .formStyle(.grouped)
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
            Form { DownloadSettings() }
                .formStyle(.grouped)
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
            Form {
                AboutView()
                AcknowledgmentsView()
            }
                .formStyle(.grouped)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520)
        #else
        Form {
            AccountSettings()
            DownloadSettings()
            AboutView()
            AcknowledgmentsView()
        }
        #endif
    }
}

private struct AccountSettings: View {
    @Environment(LibraryStore.self) private var store
    @State private var email = ""
    @State private var password = ""
    @State private var isConfirmingRemoval = false

    var body: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.username)
            #if !os(macOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            #endif
            SecureField("Password", text: $password)
                .textContentType(.password)
                .onSubmit(signIn)
        } header: {
            Text("Paizo Account")
        } footer: {
            Text("""
            The fields accept Password AutoFill from the Passwords app. The password is stored in your \
            Keychain and is only sent to store.paizo.com.
            """)
            .foregroundStyle(.secondary)
        }
        .onAppear { email = store.storedEmail }
        Section {
            HStack {
                status
                Spacer()
                if store.account != .signedOut {
                    Button("Remove Account", role: .destructive) { isConfirmingRemoval = true }
                        .buttonStyle(.borderless)
                }
                Button("Sign In", action: signIn)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || store.account == .verifying)
            }
        }
        .confirmationDialog("Remove your Paizo account?", isPresented: $isConfirmingRemoval) {
            Button("Remove Account", role: .destructive, action: removeAccount)
        } message: {
            Text("""
            Your email address and password, your library list and covers are removed from this device. \
            Your tags, and the files you downloaded, stay.
            """)
        }
    }

    @ViewBuilder private var status: some View {
        switch store.account {
        case .signedOut:
            Label("Not signed in", systemImage: "person.crop.circle.badge.xmark")
                .foregroundStyle(.secondary)
        case .verifying:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Signing in…")
            }
        case let .signedIn(email):
            Label("Signed in as \(email)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func signIn() {
        Task { await store.signIn(email: email, password: password) }
    }

    private func removeAccount() {
        password = ""
        Task { await store.signOut() }
    }
}

private struct DownloadSettings: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        Section {
            #if os(macOS)
            LabeledContent("Folder") {
                // The shared folder reads as Scrollkeeper, not as a path into the App Group; the path is in the
                // help tag.
                let name = FolderName(url: store.downloadDirectory)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(name.title)
                    Text(name.location).font(.caption).foregroundStyle(.secondary)
                }
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .help(store.downloadDirectory.path(percentEncoded: false))
            }
            HStack {
                Spacer()
                Button(PlatformText.showInFileBrowser) { showFolder() }
                Button("Use Default") { store.resetDownloadDirectory() }
                Button("Choose…") { chooseFolder() }
            }
            #else
            // Files names the device's own storage after its kind: On My iPad, On My iPhone.
            LabeledContent("Folder", value: "Files › On My \(UIDevice.current.model) › Scrollkeeper")
            Button(PlatformText.showInFileBrowser) { showFolder() }
            #endif
        } header: {
            Text("Downloaded Files")
        } footer: {
            Text(footer)
                .foregroundStyle(.secondary)
        }
        Section {
            LabeledContent("Last checked", value: lastUpdateCheck)
        } header: {
            Text("Updated Files")
        } footer: {
            Text("""
            Scrollkeeper asks Paizo whether a downloaded file has been updated when you open its title, \
            and for a few others each day. An updated file is marked so you can download it again.
            """)
            .foregroundStyle(.secondary)
        }
    }

    private var lastUpdateCheck: String {
        store.lastUpdateCheck?.formatted(date: .abbreviated, time: .shortened) ?? "Never"
    }

    private var footer: String {
        #if os(macOS)
        "Files already downloaded stay where they are; move them yourself if you change the folder."
        #else
        "Downloads are kept on this \(UIDevice.current.model) and also appear in the Files app."
        #endif
    }

    private func showFolder() {
        try? FileManager.default.createDirectory(at: store.downloadDirectory, withIntermediateDirectories: true)
        #if os(macOS)
        NSWorkspace.shared.open(store.downloadDirectory)
        #else
        FileOpener.reveal(store.downloadDirectory)
        #endif
    }

    #if os(macOS)
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = store.downloadDirectory
        if panel.runModal() == .OK, let url = panel.url {
            store.setDownloadDirectory(url)
        }
    }
    #endif
}
