import SwiftUI

#if os(macOS)
import AppKit
#endif

/// The notice Paizo's Community Use Policy requires, and where to find out more.
enum AboutInfo {
    static let appName = "Paizo Library Manager"

    /// The wording is prescribed by the policy; only the product name is ours.
    static let notice = """
    \(appName) uses trademarks and/or copyrights owned by Paizo Inc., used under Paizo's Community Use \
    Policy (paizo.com/licenses/communityuse). We are expressly prohibited from charging you to use or \
    access this content. \(appName) is not published, endorsed, or specifically approved by Paizo. For \
    more information about Paizo Inc. and Paizo products, visit paizo.com.
    """

    static let policyURL = URL(string: "https://paizo.com/licenses/communityuse")
    static let paizoURL = URL(string: "https://paizo.com")
    /// Donations are optional; nothing in the app depends on them.
    static let donationURL = URL(string: "https://ko-fi.com/coop207627")

    #if os(macOS)
    /// Shows the standard About panel with the notice as its credits.
    @MainActor
    static func showAboutPanel() {
        let credits = NSAttributedString(
            string: notice,
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                         .foregroundColor: NSColor.labelColor]
        )
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    #endif
}

/// The notice with links to Paizo's policy and, on the Mac, to the donation page.
struct AboutView: View {
    var body: some View {
        Section {
            Text(AboutInfo.notice)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let policy = AboutInfo.policyURL {
                Link("Paizo's Community Use Policy", destination: policy)
            }
            if let paizo = AboutInfo.paizoURL {
                Link("paizo.com", destination: paizo)
            }
        } header: {
            Text("About")
        }
        // The donation link is left out of the iPad app: Apple restricts links to outside
        // payment pages in apps distributed through the App Store or TestFlight.
        #if os(macOS)
        Section {
            if let donation = AboutInfo.donationURL {
                Link("Support Development on Ko-fi", destination: donation)
            }
        } footer: {
            Text("This app is free. A donation is entirely optional and unlocks nothing.")
                .foregroundStyle(.secondary)
        }
        #endif
    }
}
