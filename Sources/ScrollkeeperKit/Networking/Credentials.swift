import Foundation
import Security

public struct Credentials: Sendable, Equatable {
    public var email: String
    public var password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }

    public var isComplete: Bool { !email.isEmpty && !password.isEmpty }
}

/// Where the Paizo account is kept between launches.
public protocol CredentialStore: Sendable {
    func load() -> Credentials?
    func save(_ credentials: Credentials) throws
    func delete() throws
}

/// Keeps the account in memory only. Used by demo mode and by tests.
/// `@unchecked Sendable`: the account is guarded by `lock`.
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Credentials?

    public init(_ credentials: Credentials? = nil) {
        stored = credentials
    }

    public func load() -> Credentials? { lock.withLock { stored } }

    public func save(_ credentials: Credentials) throws { lock.withLock { stored = credentials } }

    public func delete() throws { lock.withLock { stored = nil } }
}

public struct KeychainError: Error, Equatable, LocalizedError {
    public let operation: String
    public let status: OSStatus

    public var errorDescription: String? {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
        return "\(operation) failed: \(detail)"
    }
}

/// Keeps the account as one internet-password item in the user's Keychain.
public struct KeychainCredentialStore: CredentialStore {
    private let server: String

    public init(server: String = "store.paizo.com") {
        self.server = server
    }

    public func load() -> Credentials? {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let item = result as? [String: Any],
              let email = item[kSecAttrAccount as String] as? String,
              let data = item[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8)
        else { return nil }
        return Credentials(email: email, password: password)
    }

    public func save(_ credentials: Credentials) throws {
        try delete()
        var attributes = baseQuery
        attributes[kSecAttrAccount as String] = credentials.email
        attributes[kSecValueData as String] = Data(credentials.password.utf8)
        attributes[kSecAttrLabel as String] = "Scrollkeeper (\(server))"
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError(operation: "Saving the Paizo password to the Keychain", status: status)
        }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(operation: "Removing the Paizo password from the Keychain", status: status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrProtocol as String: kSecAttrProtocolHTTPS
        ]
    }
}
