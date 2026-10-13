import Foundation
@testable import MetMuseumKit

/// Recorded JSON responses in `Fixtures/`, hand-written in the API's exact shapes.
enum Fixture {
    struct Missing: Error {
        let name: String
    }

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw Missing(name: name)
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(T.self, from: data(name))
    }
}

/// A canned HTTP response.
struct StubResponse: Sendable {
    var status: Int
    var headers: [String: String]
    var body: Data

    static func json(_ fixture: String, status: Int = 200) throws -> StubResponse {
        try StubResponse(status: status, headers: ["Content-Type": "application/json"], body: Fixture.data(fixture))
    }

    static func raw(_ text: String, status: Int = 200) -> StubResponse {
        StubResponse(status: status, headers: ["Content-Type": "application/json"], body: Data(text.utf8))
    }

    static func status(_ status: Int) -> StubResponse {
        StubResponse(status: status, headers: [:], body: Data())
    }
}

typealias StubHandler = @Sendable (URLRequest) throws -> StubResponse

/// Answers requests from a handler registered for the request's host, so every test can run in
/// parallel with its own host. Nothing ever reaches the network.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host, let handler = StubRegistry.shared.handler(for: host) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        // URLSession moves a POST body into a stream before it reaches a protocol; keep it readable.
        var recorded = request
        if recorded.httpBody == nil, let stream = request.httpBodyStream {
            recorded.httpBody = Self.read(stream)
        }
        StubRegistry.shared.record(recorded, for: host)
        do {
            let stub = try handler(recorded)
            guard let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

final class StubRegistry: @unchecked Sendable {
    static let shared = StubRegistry()

    private let lock = NSLock()
    private var handlers: [String: StubHandler] = [:]
    private var requests: [String: [URLRequest]] = [:]

    func register(_ handler: @escaping StubHandler, for host: String) {
        lock.withLock { handlers[host] = handler }
    }

    func handler(for host: String) -> StubHandler? {
        lock.withLock { handlers[host] }
    }

    func record(_ request: URLRequest, for host: String) {
        lock.withLock { requests[host, default: []].append(request) }
    }

    func requests(for host: String) -> [URLRequest] {
        lock.withLock { requests[host] ?? [] }
    }
}

/// A client wired to the stub, on a host of its own, with throttling off unless asked for.
struct StubbedClient {
    let host: String
    let client: MetMuseumClient

    init(requestsPerSecond: Double = 0, maxConcurrentRequests: Int = 6, maxRetries: Int = 2, handler: @escaping StubHandler) {
        host = "stub-" + UUID().uuidString.lowercased() + ".metmuseum.test"
        StubRegistry.shared.register(handler, for: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = MetMuseumClient(configuration: MetMuseumConfiguration(
            baseURL: URL(string: "https://" + host + "/public/collection/v1")!,
            session: URLSession(configuration: configuration),
            requestsPerSecond: requestsPerSecond,
            maxConcurrentRequests: maxConcurrentRequests,
            maxRetries: maxRetries
        ))
    }

    /// Every request the client sent, in order.
    var requests: [URLRequest] {
        StubRegistry.shared.requests(for: host)
    }

    /// Every request's path, in order.
    var paths: [String] {
        requests.compactMap { $0.url?.path }
    }

    /// The last request's path.
    var lastPath: String? {
        requests.last?.url?.path
    }

    /// The last request's query items, decoded.
    var lastQuery: [URLQueryItem] {
        guard let url = requests.last?.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return [] }
        return components.queryItems ?? []
    }

    /// The value of a query item of the last request.
    func lastQueryValue(_ name: String) -> String? {
        lastQuery.first(where: { $0.name == name })?.value
    }
}

extension URLRequest {
    /// The value of a query item.
    func queryValue(_ name: String) -> String? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == name })?.value
    }

    /// The last path component, such as `"436535"` for `/public/collection/v1/objects/436535`.
    var lastPathComponent: String? {
        url?.lastPathComponent
    }

    /// The object ID of an `/objects/{id}` request.
    var objectID: Int? {
        guard let url, url.pathComponents.dropLast().last == "objects" else { return nil }
        return Int(url.lastPathComponent)
    }
}
