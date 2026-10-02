import Foundation

/// Failures talking to Paizo. Each case names the operation that failed and why.
public enum PaizoError: Error, Equatable, LocalizedError {
    case credentialsMissing
    case signInRejected
    case http(operation: String, status: Int)
    case unexpectedResponse(operation: String)
    case tokenExpired
    case downloadRefused(reason: String)
    case fileUnavailable(name: String)

    public var errorDescription: String? {
        switch self {
        case .credentialsMissing:
            "Signing in failed: no Paizo account is set up. Add your account in Settings."
        case .signInRejected:
            "Signing in failed: Paizo did not accept the email and password."
        case let .http(operation, status):
            "\(operation) failed: Paizo answered with status \(status)."
        case let .unexpectedResponse(operation):
            "\(operation) failed: Paizo's answer was not in the expected form."
        case .tokenExpired:
            "Loading the library failed: the Paizo session expired and could not be renewed."
        case let .downloadRefused(reason):
            "Requesting the download failed: \(reason)"
        case let .fileUnavailable(name):
            "Downloading failed: Paizo has no file attached to \(name)."
        }
    }
}
