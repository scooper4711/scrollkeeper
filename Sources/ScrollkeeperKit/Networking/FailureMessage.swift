import Foundation

/// What to tell the user when talking to Paizo fails: one message for each kind of failure, so none of them
/// ends as an empty library or a spinner that never stops.
public enum FailureMessage {
    /// The message for `error`, as Settings and the library show it.
    public static func text(for error: Error) -> String {
        if isSiteChange(error) {
            return siteChanged
        }
        if let urlError = error as? URLError {
            return text(for: urlError)
        }
        if case let PaizoError.http(operation, status) = error, status >= 500 {
            return "\(operation) failed: Paizo's website is not working right now (status \(status)). Try again later."
        }
        return error.localizedDescription
    }

    /// True when Paizo's pages or answers no longer look the way Scrollkeeper reads them.
    public static func isSiteChange(_ error: Error) -> Bool {
        switch error {
        case is PayloadError, PaizoError.unexpectedResponse:
            true
        case let PaizoError.http(_, status):
            status == 404 || status == 410
        default:
            false
        }
    }

    /// Says what happened and where to find a version that follows the change.
    public static let siteChanged = "Paizo's website has changed, and this version of Scrollkeeper can't read it. "
        + remedy

    #if APP_STORE || os(iOS)
    private static let remedy = "Check the App Store for an update of Scrollkeeper."
    #else
    private static let remedy = "Choose Check for Updates in the Scrollkeeper menu to look for a newer version."
    #endif

    private static func text(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            "You are not connected to the internet. Connect and try again."
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            "Paizo's website did not answer. Check your connection, or try again later."
        default:
            error.localizedDescription
        }
    }
}
