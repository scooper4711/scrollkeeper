import AppKit
import PaizoLibraryKit
import SwiftUI

/// Account and download folder settings.
struct SettingsView: View {
    var body: some View {
        TabView {
            AccountSettings()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
            DownloadSettings()
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
        }
        .frame(width: 520)
    }
}

private struct AccountSettings: View {
    @Environment(LibraryStore.self) private var store
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.username)
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
            Section {
                HStack {
                    status
                    Spacer()
                    if store.account != .signedOut {
                        Button("Remove Account", role: .destructive) {
                            store.signOut()
                            password = ""
                        }
                    }
                    Button("Sign In", action: signIn)
                        .keyboardShortcut(.defaultAction)
                        .disabled(email.isEmpty || password.isEmpty || store.account == .verifying)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { email = store.storedEmail }
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
        Form {
            Section {
                LabeledContent("Folder") {
                    Text(store.downloadDirectory.path(percentEncoded: false))
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Spacer()
                    Button("Show in Finder") { showInFinder() }
                    Button("Use Default") { store.resetDownloadDirectory() }
                    Button("Choose…") { chooseFolder() }
                }
            } header: {
                Text("Downloaded Files")
            } footer: {
                Text("Files already downloaded stay where they are; move them yourself if you change the folder.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

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

    private func showInFinder() {
        try? FileManager.default.createDirectory(at: store.downloadDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(store.downloadDirectory)
    }
}
