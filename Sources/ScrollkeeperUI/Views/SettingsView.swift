import ScrollkeeperKit
import SwiftUI

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
                AcknowledgementsView()
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
            AcknowledgementsView()
        }
        #endif
    }
}

private struct AccountSettings: View {
    @Environment(LibraryStore.self) private var store
    @State private var email = ""
    @State private var password = ""

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
                    Button("Remove Account", role: .destructive) {
                        store.signOut()
                        password = ""
                    }
                    .buttonStyle(.borderless)
                }
                Button("Sign In", action: signIn)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || store.account == .verifying)
            }
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
}

private struct DownloadSettings: View {
    @Environment(LibraryStore.self) private var store

    var body: some View {
        Section {
            #if os(macOS)
            LabeledContent("Folder") {
                Text(store.downloadDirectory.path(percentEncoded: false))
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Spacer()
                Button(PlatformText.showInFileBrowser) { showFolder() }
                Button("Use Default") { store.resetDownloadDirectory() }
                Button("Choose…") { chooseFolder() }
            }
            #else
            LabeledContent("Folder", value: "Files › On My iPad › Scrollkeeper")
            Button(PlatformText.showInFileBrowser) { showFolder() }
            #endif
        } header: {
            Text("Downloaded Files")
        } footer: {
            Text(footer)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: String {
        #if os(macOS)
        "Files already downloaded stay where they are; move them yourself if you change the folder."
        #else
        "Downloads are kept on this iPad and also appear in the Files app."
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
