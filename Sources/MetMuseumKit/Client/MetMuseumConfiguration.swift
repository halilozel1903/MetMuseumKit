import Foundation

/// Settings of a ``MetMuseumClient``.
public struct MetMuseumConfiguration: Sendable {
    /// `https://collectionapi.metmuseum.org/public/collection/v1`.
    public static let defaultBaseURL = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1")!

    /// Where `objects`, `objects/{id}` and `departments` are requested. Change it to point at a
    /// proxy or a local stub server.
    public var baseURL: URL
    /// The search endpoint. By default `…/v1.1/search` next to ``baseURL``: the paginated search
    /// that replaced `/v1/search` (retired on October 1, 2026).
    public var searchURL: URL
    /// The session that performs requests. Give it a `URLProtocol` subclass to stub responses.
    public var session: URLSession
    /// The most requests per second (default 80, the limit the API asks for). `0` turns
    /// throttling off, for tests against a stub.
    public var requestsPerSecond: Double
    /// The most object requests in flight at once when fetching several objects (default 6).
    public var maxConcurrentRequests: Int
    /// How many times a request is retried after HTTP 429, 502, 503 or 504, a timeout or a lost
    /// connection (default 2). Retries wait 0.5 s, then 1 s, or what `Retry-After` asks.
    public var maxRetries: Int
    /// Sent as `User-Agent` when set. By default the system's own user agent is sent.
    public var userAgent: String?
    /// The request timeout in seconds.
    public var timeout: TimeInterval

    public init(
        baseURL: URL = MetMuseumConfiguration.defaultBaseURL,
        searchURL: URL? = nil,
        session: URLSession = .shared,
        requestsPerSecond: Double = 80,
        maxConcurrentRequests: Int = 6,
        maxRetries: Int = 2,
        userAgent: String? = nil,
        timeout: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.searchURL = searchURL ?? baseURL
            .deletingLastPathComponent()
            .appendingPathComponent("v1.1")
            .appendingPathComponent("search")
        self.session = session
        self.requestsPerSecond = requestsPerSecond
        self.maxConcurrentRequests = max(1, maxConcurrentRequests)
        self.maxRetries = max(0, maxRetries)
        self.userAgent = userAgent
        self.timeout = timeout
    }
}
