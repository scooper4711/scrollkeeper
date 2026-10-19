import Foundation
import UniformTypeIdentifiers

/// A Tableside Toolkit app that may ask Scrollkeeper to open a title. Only these are accepted, so
/// a link cannot make Scrollkeeper start an arbitrary application.
public enum HandoffApp: String, CaseIterable, Sendable {
    case mapsmith
    case pluck

    public var name: String {
        switch self {
        case .mapsmith: "Mapsmith"
        case .pluck: "Pluck"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .mapsmith: "com.github.scooper4711.Mapsmith"
        case .pluck: "io.github.scooper4711.pluck"
        }
    }

    /// The scheme of the links that tell the app how its request is going (`HandoffStatus`).
    public var statusScheme: String {
        switch self {
        case .mapsmith: "mapsmith"
        case .pluck: "pluck"
        }
    }

    /// Whether the app's list of titles (`TitleIndex`) includes the title: Mapsmith lists maps only, so
    /// it doesn't offer rulebooks whose PDFs it could open but has no use for.
    public func lists(_ item: LibraryTitle) -> Bool {
        switch self {
        case .mapsmith: item.classification.productLine == .maps
        case .pluck: true
        }
    }

    /// The kinds of file the app opens; other files of a download are not sent to it.
    public var acceptedTypes: [UTType] {
        switch self {
        case .mapsmith: [.pdf, .image]
        case .pluck: [.pdf]
        }
    }

    public func accepts(_ file: URL) -> Bool {
        accepts(fileExtension: file.pathExtension)
    }

    /// True when the edition's download is a file the app opens, or a zip of documents that may hold some.
    public func canOpen(_ edition: Edition) -> Bool {
        edition.isUnpackedArchive || accepts(fileExtension: edition.entitlement.fileExtension)
    }

    private func accepts(fileExtension: String) -> Bool {
        guard let type = UTType(filenameExtension: fileExtension) else { return false }
        return acceptedTypes.contains { type.conforms(to: $0) }
    }

    /// The files of a download to send to the app. When a download holds PDFs only those are sent:
    /// map packs repeat the PDF's pages as images at a lower resolution (150 against 300 ppi).
    public func filesToSend(from files: [URL]) -> [URL] {
        let accepted = files.filter(accepts)
        let pdfs = accepted.filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .pdf) == true }
        return pdfs.isEmpty ? accepted : pdfs
    }
}

/// What the requesting app wants done with the title.
public enum HandoffAction: String, Sendable {
    /// Download when needed, then open the files in the requesting app.
    case open
    /// Only download, so the title is ready for later; nothing is opened.
    case download
    /// Send the app the list of titles it can open (`TitleIndex`), as a file it is given access to.
    case index
}

/// A request from another app: `scrollkeeper://<open|download>?sku=<SKU>&app=<app key>`, or
/// `scrollkeeper://index?app=<app key>`, which names no title.
public struct HandoffRequest: Equatable, Sendable {
    public static let scheme = "scrollkeeper"

    public var sku: String
    public var app: HandoffApp
    public var action: HandoffAction

    public init(sku: String, app: HandoffApp, action: HandoffAction = .open) {
        self.sku = sku
        self.app = app
        self.action = action
    }

    public init(url: URL) throws(HandoffError) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let components, components.scheme == Self.scheme,
              let action = components.host.flatMap(HandoffAction.init(rawValue:)) else {
            throw .unrecognizedLink
        }
        let value = { (name: String) in components.queryItems?.first { $0.name == name }?.value ?? "" }
        let sku = value("sku")
        guard action == .index || !sku.isEmpty else { throw .unrecognizedLink }
        guard let app = HandoffApp(rawValue: value("app")) else { throw .unknownApp(value("app")) }
        self.init(sku: sku, app: app, action: action)
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
    case noCatalog
    case indexNotWritten(app: String, reason: String)

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
        case .noCatalog:
            "Sending your library failed: Scrollkeeper hasn't loaded it yet. Sign in from Settings."
        case let .indexNotWritten(app, reason):
            "Sending your library to \(app) failed: \(reason)"
        }
    }
}
