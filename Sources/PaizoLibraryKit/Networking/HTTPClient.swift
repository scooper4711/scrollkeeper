import Foundation

public struct HTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int
    public let finalURL: URL?

    public init(data: Data, statusCode: Int = 200, finalURL: URL? = nil) {
        self.data = data
        self.statusCode = statusCode
        self.finalURL = finalURL
    }

    public var text: String { String(bytes: data, encoding: .utf8) ?? "" }

    public var isSuccess: Bool { (200..<300).contains(statusCode) }

    /// Returns the response, or throws when the status is not a success.
    public func validated(operation: String) throws -> HTTPResponse {
        guard isSuccess else { throw PaizoError.http(operation: operation, status: statusCode) }
        return self
    }
}

public typealias ProgressHandler = @Sendable (Double) -> Void

/// The network access the library needs. Tests replace it with a stub.
public protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
    /// Downloads the response body to `destination`, replacing any file there.
    func download(_ request: URLRequest, to destination: URL, progress: @escaping ProgressHandler) async throws
}

extension URLRequest {
    static func get(_ url: URL) -> URLRequest {
        URLRequest(url: url)
    }

    /// A JSON object whose members appear in the given order. Paizo's download API reads the
    /// members by position, so a dictionary, which has no order, cannot be used.
    static func postJSON(_ url: URL, orderedFields fields: [(name: String, value: String)]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let members = fields.map { "\(jsonString($0.name)):\(jsonString($0.value))" }
        request.httpBody = Data("{\(members.joined(separator: ","))}".utf8)
        return request
    }

    static func postForm(_ url: URL, fields: [(name: String, value: String)]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let pairs = fields.map { "\(formEncode($0.name))=\(formEncode($0.value))" }
        request.httpBody = Data(pairs.joined(separator: "&").utf8)
        return request
    }

    private static func jsonString(_ text: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return (try? encoder.encode(text)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "\"\""
    }

    private static func formEncode(_ text: String) -> String {
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}
