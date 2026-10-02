import Foundation

/// A thread-safe counter for handlers that answer differently on each call.
/// `@unchecked Sendable`: state is guarded by `lock`.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var current: Int { lock.withLock { value } }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}

/// A thread-safe one-way flag. `@unchecked Sendable`: state is guarded by `lock`.
final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool { lock.withLock { value } }

    func set() { lock.withLock { value = true } }
}

/// A clock tests can move forward. `@unchecked Sendable`: state is guarded by `lock`.
final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_800_000_000)

    var now: Date { lock.withLock { current } }

    func advance(by interval: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(interval) }
    }
}

/// A fresh temporary directory, removed when the value is released.
final class TemporaryDirectory: Sendable {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory.appending(path: "PaizoLibraryKitTests-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
