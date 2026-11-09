import Foundation
import Observation
import ScrollkeeperKit

/// The library the app shows: the user's own, or the demo library, which anyone can try from the sign-in screen
/// without an account and leave again (#44). Views take `store` from here, so switching shows the other library.
@MainActor
@Observable
public final class LibrarySession {
    public private(set) var store: LibraryStore

    public init(environment: LibraryEnvironment = .forLaunch()) {
        store = LibraryStore(environment: environment)
    }

    public var isDemo: Bool { store.isDemo }

    public func start() async {
        await store.start()
    }

    /// Shows the demo library in place of the signed-out one.
    public func startDemo() {
        guard !isDemo else { return }
        show(.demo())
    }

    /// Leaves the demo library, removing its data, and shows the user's own library to sign in to.
    public func leaveDemo() {
        guard isDemo else { return }
        store.endDemo()
        show(.live())
    }

    private func show(_ environment: LibraryEnvironment) {
        store = LibraryStore(environment: environment)
        Task { await store.start() }
    }
}
