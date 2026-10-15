import Foundation
import UniformTypeIdentifiers

/// A Tableside Toolkit app that may ask Scrollkeeper to open a title. Only these are accepted, so
/// a link cannot make Scrollkeeper start an arbitrary application.
public enum HandoffApp: String, CaseIterable, Sendable {
    case mapsmith

    public var name: String {
        switch self {
        case .mapsmith: "Mapsmith"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .mapsmith: "com.github.scooper4711.Mapsmith"
        }
    }

    /// The kinds of file the app opens; other files of a download are not sent to it.
    public var acceptedTypes: [UTType] {
        switch self {
        case .mapsmith: [.pdf, .image]
        }
    }

    public func accepts(_ file: URL) -> Bool {
        guard let type = UTType(filenameExtension: file.pathExtension) else { return false }
        return acceptedTypes.contains { type.conforms(to: $0) }
    }
}

/// A request to open a title in another app: `scrollkeeper://open?sku=<SKU>&app=<app key>`.
public struct HandoffRequest: Equatable, Sendable {
    public static let scheme = "scrollkeeper"

    public var sku: String
    public var app: HandoffApp

    public init(sku: String, app: HandoffApp) {
        self.sku = sku
        self.app = app
    }

    public init(url: URL) throws(HandoffError) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let components, components.scheme == Self.scheme, components.host == "open" else {
            throw .unrecognizedLink
        }
        let value = { (name: String) in components.queryItems?.first { $0.name == name }?.value ?? "" }
        let sku = value("sku")
        guard !sku.isEmpty else { throw .unrecognizedLink }
        guard let app = HandoffApp(rawValue: value("app")) else { throw .unknownApp(value("app")) }
        self.init(sku: sku, app: app)
    }
}

/// Why a request to open a title in another app could not be met.
public enum HandoffError: Error, Equatable, LocalizedError {
    case unrecognizedLink
    case unknownApp(String)
    case signedOut
    case titleNotFound(sku: String)
    case noEdition(title: String)
    case downloadFailed(title: String, reason: String)
    case cancelled(title: String)
    case noAcceptedFiles(title: String, app: String)
    case appNotInstalled(app: String)

    public var errorDescription: String? {
        switch self {
        case .unrecognizedLink:
            "Opening the link failed: Scrollkeeper does not recognize it."
        case let .unknownApp(key):
            "Opening the link failed: \"\(key)\" is not an app Scrollkeeper opens files in."
        case .signedOut:
            "Opening the title failed: no Paizo account is signed in. Sign in from Settings."
        case let .titleNotFound(sku):
            "Opening the title failed: \(sku) is not in your library. Check for new titles and try again."
        case let .noEdition(title):
            "Opening \(title) failed: it has no edition that can be downloaded here."
        case let .downloadFailed(title, reason):
            "Downloading \(title) failed: \(reason)"
        case let .cancelled(title):
            "Opening \(title) stopped: its download was cancelled."
        case let .noAcceptedFiles(title, app):
            "Opening \(title) failed: its download holds no file \(app) can open."
        case let .appNotInstalled(app):
            "Opening the title failed: \(app) is not installed."
        }
    }
}
