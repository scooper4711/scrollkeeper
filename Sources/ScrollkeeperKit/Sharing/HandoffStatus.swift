import Foundation

/// How a request to open a title is going, for an app that shows it itself instead of leaving the user to look
/// at Scrollkeeper. It is sent to the app as a link in its own scheme:
/// `<scheme>://handoff?sku=<SKU>&state=<downloading|failed|done>[&fraction=<0…1>][&reason=<text>]`.
public enum HandoffStatus: Equatable, Sendable {
    case downloading(Double)
    case failed(String)
    /// The files are about to be opened in the app.
    case done

    /// The link that tells `app` about the title; nil for an app that doesn't take them.
    public func url(for app: HandoffApp, sku: String) -> URL? {
        guard let scheme = app.statusScheme else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "handoff"
        components.queryItems = [URLQueryItem(name: "sku", value: sku)] + queryItems
        return components.url
    }

    private var queryItems: [URLQueryItem] {
        switch self {
        case let .downloading(fraction):
            [URLQueryItem(name: "state", value: "downloading"),
             URLQueryItem(name: "fraction", value: String(format: "%.2f", fraction))]
        case let .failed(reason):
            [URLQueryItem(name: "state", value: "failed"), URLQueryItem(name: "reason", value: reason)]
        case .done:
            [URLQueryItem(name: "state", value: "done")]
        }
    }
}

/// Lets through only the statuses worth a link: a different state, or progress moved by a whole percent.
public struct HandoffStatusThrottle: Sendable {
    private var lastSent: HandoffStatus?

    public init() {}

    public mutating func shouldSend(_ status: HandoffStatus) -> Bool {
        defer { lastSent = status }
        if case let .downloading(new) = status, case let .downloading(old)? = lastSent {
            return Int(new * 100) != Int(old * 100)
        }
        return status != lastSent
    }
}

extension LibraryStore {
    /// How the download a request waits for is going; nil when nothing is downloading for it.
    public func handoffStatus(for request: HandoffRequest) -> HandoffStatus? {
        guard let item = item(id: request.sku), let target = handoffTarget(for: item) else { return nil }
        switch downloads[target.id] {
        case .waiting: return .downloading(0)
        case let .inProgress(fraction): return .downloading(fraction)
        case .interrupted, .failed, nil: return nil
        }
    }
}
