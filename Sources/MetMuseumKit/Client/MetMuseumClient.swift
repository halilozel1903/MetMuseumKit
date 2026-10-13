import Foundation

/// A client for The Metropolitan Museum of Art's
/// [collection API](https://metmuseum.github.io/): objects, departments and search, with the
/// object lookups that search results need done concurrently, throttled and in order.
///
/// ```swift
/// let met = MetMuseumClient()
///
/// let departments = try await met.departments()                // 19 departments
/// let painting = try await met.object(id: 436535)               // Wheat Field with Cypresses
/// painting.imageURL(.small)                                     // images.metmuseum.org/…/web-large/…
///
/// // Highlighted European paintings that are in the public domain, with images.
/// let gallery = try await met.highlights(departmentID: 11, limit: 24)
///
/// let page = try await met.search(MetSearchQuery("sunflowers", hasImages: true))
/// let works = try await met.objects(ids: page.objectIDs)       // in order, 6 at a time
/// ```
///
/// One client can be shared by the whole app; it is `Sendable`, and its throttle keeps every
/// request it sends under ``MetMuseumConfiguration/requestsPerSecond``.
public final class MetMuseumClient: Sendable {
    /// A client with the default configuration.
    public static let shared = MetMuseumClient()

    /// The search API serves only the first 10,000 results of a query (`offset + limit`).
    public static let maxSearchResults = 10_000
    /// The largest page `/v1.1/search` returns.
    public static let maxSearchPageSize = 500

    public let configuration: MetMuseumConfiguration
    /// The throttle every request of this client goes through.
    public let throttle: MetRequestThrottle

    public init(configuration: MetMuseumConfiguration = MetMuseumConfiguration()) {
        self.configuration = configuration
        throttle = MetRequestThrottle(requestsPerSecond: configuration.requestsPerSecond)
    }

    /// A client using `session`, with the default settings otherwise.
    public convenience init(session: URLSession) {
        self.init(configuration: MetMuseumConfiguration(session: session))
    }

    // MARK: - Departments

    /// Every curatorial department (`/departments`), such as European Paintings (11).
    public func departments() async throws -> [MetDepartment] {
        let response: DepartmentsResponse = try await get("departments")
        return response.departments
    }

    // MARK: - Objects

    /// The IDs of every object (`/objects`), optionally only in some departments or only those
    /// whose record changed after a date. Without filters this is the whole collection, about
    /// half a million IDs in one response.
    public func objectIDs(departmentIDs: [Int] = [], metadataDate: Date? = nil) async throws -> MetObjectIDList {
        var query: [URLQueryItem] = []
        if let metadataDate {
            query.append(URLQueryItem(name: "metadataDate", value: MetDate.day(metadataDate)))
        }
        if !departmentIDs.isEmpty {
            query.append(URLQueryItem(name: "departmentIds", value: departmentIDs.map(String.init).joined(separator: "|")))
        }
        return try await get("objects", query: query)
    }

    /// One object (`/objects/{objectID}`). Throws ``MetMuseumError/notFound(message:url:)`` for
    /// an ID that is not in the collection.
    public func object(id: Int) async throws -> MetObject {
        try await get("objects/" + String(id))
    }

    /// Several objects, in the order of `ids`, fetched with at most `maxConcurrentRequests`
    /// requests in flight (the configuration's value by default) and every request throttled.
    ///
    /// Search results and ID lists sometimes name objects the API no longer serves; those 404s
    /// are skipped, so the result can be shorter than `ids`. Duplicates are fetched once. Any
    /// other error stops the fetch and is thrown.
    public func objects(ids: [Int], maxConcurrentRequests: Int? = nil) async throws -> [MetObject] {
        var seen = Set<Int>()
        let unique = ids.filter { seen.insert($0).inserted }
        let width = maxConcurrentRequests ?? configuration.maxConcurrentRequests
        let found = try await boundedMap(unique, maxConcurrent: width) { [self] id -> MetObject? in
            do {
                return try await self.object(id: id)
            } catch let error as MetMuseumError where error.isNotFound {
                return nil
            }
        }
        return found.compactMap { $0 }
    }

    // MARK: - Search

    /// One page of search results (`/v1.1/search`): up to `limit` object IDs starting at
    /// `offset`, and the total number of matches.
    ///
    /// `limit` is capped at 500 by the API. Only the first 10,000 results of a query can be
    /// reached; a page past them throws ``MetMuseumError/invalidRequest(_:)``. A search that
    /// matches nothing returns an empty page.
    public func search(_ query: MetSearchQuery, offset: Int = 0, limit: Int = 100) async throws -> MetSearchPage {
        let offset = max(0, offset)
        guard offset < Self.maxSearchResults else {
            throw MetMuseumError.invalidRequest("The search API serves only the first \(Self.maxSearchResults) results of a query.")
        }
        let limit = min(max(1, limit), Self.maxSearchPageSize, Self.maxSearchResults - offset)
        var items = query.queryItems
        items.append(URLQueryItem(name: "offset", value: String(offset)))
        items.append(URLQueryItem(name: "limit", value: String(limit)))
        let request = try makeRequest(url: configuration.searchURL, query: items)
        let list = try await decode(MetObjectIDList.self, from: data(for: request))
        return MetSearchPage(total: list.total, objectIDs: list.objectIDs, offset: offset, limit: limit)
    }

    /// Every page of a search, loaded as you iterate, `pageSize` IDs at a time.
    public func searchPages(_ query: MetSearchQuery, pageSize: Int = 100) -> MetSearchPages {
        MetSearchPages(client: self, query: query, pageSize: pageSize)
    }

    /// The objects matching a search, fetched until `limit` of them pass the filter.
    ///
    /// Search returns only IDs, so this walks the result pages, fetches the objects concurrently
    /// (throttled, in order) and keeps those that pass. By default it keeps Open Access works that
    /// have an image, because the API's `hasImages` also matches works whose images it does not
    /// serve. It stops as soon as it has `limit` objects or the results run out.
    ///
    /// - Parameters:
    ///   - publicDomainOnly: Keep only works with ``MetObject/isPublicDomain``.
    ///   - requireImage: Keep only works with a primary image.
    public func searchObjects(
        _ query: MetSearchQuery,
        limit: Int = 24,
        publicDomainOnly: Bool = true,
        requireImage: Bool = true
    ) async throws -> [MetObject] {
        guard limit > 0 else { return [] }
        var kept: [MetObject] = []
        let pageSize = min(Self.maxSearchPageSize, max(40, limit * 2))
        let batchSize = max(configuration.maxConcurrentRequests * 2, 8)
        for try await page in searchPages(query, pageSize: pageSize) {
            var start = 0
            while start < page.objectIDs.count {
                let needed = limit - kept.count
                let end = min(page.objectIDs.count, start + max(needed, batchSize))
                let batch = Array(page.objectIDs[start..<end])
                start = end
                for object in try await objects(ids: batch) {
                    if publicDomainOnly && !object.isPublicDomain { continue }
                    if requireImage && !object.hasImage { continue }
                    kept.append(object)
                    if kept.count == limit { return kept }
                }
            }
        }
        return kept
    }

    /// The highlights of a department (or of the whole museum) that are in the public domain and
    /// have an image: `isHighlight=true&hasImages=true&departmentId=…`, fetched until `limit`.
    public func highlights(departmentID: Int? = nil, limit: Int = 24) async throws -> [MetObject] {
        try await searchObjects(.highlights(departmentID: departmentID), limit: limit)
    }

    // MARK: - Requests

    /// Builds the request for a path below the base URL. Exposed for tests and debugging.
    public func request(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        try makeRequest(url: configuration.baseURL.appendingPathComponent(path), query: query)
    }

    /// Fetches and decodes a path below the base URL, for anything this client has no method for.
    public func get<Value: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: Value.Type = Value.self) async throws -> Value {
        try await decode(Value.self, from: data(for: request(path: path, query: query)))
    }

    func makeRequest(url: URL, query: [URLQueryItem]) throws -> URLRequest {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw MetMuseumError.transport(URLError(.badURL))
        }
        if !query.isEmpty {
            components.queryItems = query
            // URLComponents leaves "+" as is, but servers read it as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let finalURL = components.url else {
            throw MetMuseumError.transport(URLError(.badURL))
        }
        var request = URLRequest(url: finalURL, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }

    func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw MetMuseumError.decoding(type: String(describing: Value.self), description: String(describing: error))
        }
    }

    /// Waits for a throttle slot, sends the request and maps transport failures; any HTTP status
    /// is returned.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            try await throttle.acquire()
        } catch {
            throw MetMuseumError.transport(URLError(.cancelled))
        }
        let result: (Data, URLResponse)
        do {
            result = try await configuration.session.data(for: request)
        } catch let error as URLError {
            throw MetMuseumError.transport(error)
        } catch is CancellationError {
            throw MetMuseumError.transport(URLError(.cancelled))
        }
        guard let http = result.1 as? HTTPURLResponse else {
            throw MetMuseumError.invalidResponse
        }
        return (result.0, http)
    }

    /// Performs a request, retrying busy and failed attempts, and returns the body of a
    /// successful response; other statuses throw with the API's message.
    func data(for request: URLRequest) async throws -> Data {
        let url = request.url ?? configuration.baseURL
        var attempt = 0
        while true {
            let response: (Data, HTTPURLResponse)
            do {
                response = try await send(request)
            } catch MetMuseumError.transport(let error) where Self.isRetryable(error) && attempt < configuration.maxRetries {
                attempt += 1
                try await Self.pause(Self.backoff(attempt: attempt))
                continue
            }
            let (data, http) = response
            switch http.statusCode {
            case 200..<300:
                return data
            case 404:
                throw MetMuseumError.notFound(message: Self.errorMessage(in: data), url: url)
            case 429, 502, 503, 504:
                guard attempt < configuration.maxRetries else {
                    throw MetMuseumError.http(statusCode: http.statusCode, message: Self.errorMessage(in: data), url: url)
                }
                attempt += 1
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                try await Self.pause(min(retryAfter ?? Self.backoff(attempt: attempt), 30))
            default:
                throw MetMuseumError.http(statusCode: http.statusCode, message: Self.errorMessage(in: data), url: url)
            }
        }
    }

    static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    /// 0.5 s, 1 s, 2 s… for the first, second, third retry.
    static func backoff(attempt: Int) -> TimeInterval {
        0.5 * pow(2, Double(max(0, attempt - 1)))
    }

    static func pause(_ seconds: TimeInterval) async throws {
        do {
            try await Task.sleep(for: .seconds(seconds))
        } catch {
            throw MetMuseumError.transport(URLError(.cancelled))
        }
    }

    /// The `message` of an error body such as `{"message":"ObjectID not found"}`.
    static func errorMessage(in data: Data) -> String? {
        (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.text
    }
}

/// Every page of a search, as an `AsyncSequence`. Pages load one at a time as you iterate and
/// stop after the last match or the API's 10,000th result.
public struct MetSearchPages: AsyncSequence, Sendable {
    public typealias Element = MetSearchPage

    let client: MetMuseumClient
    let query: MetSearchQuery
    let pageSize: Int

    public func makeAsyncIterator() -> Iterator {
        Iterator(client: client, query: query, pageSize: pageSize)
    }

    public struct Iterator: AsyncIteratorProtocol {
        let client: MetMuseumClient
        let query: MetSearchQuery
        let pageSize: Int
        var nextOffset: Int? = 0

        public mutating func next() async throws -> MetSearchPage? {
            guard let offset = nextOffset else { return nil }
            let page = try await client.search(query, offset: offset, limit: pageSize)
            nextOffset = page.nextOffset
            return page.isEmpty ? nil : page
        }
    }

    /// Every object ID across the pages.
    public func collectIDs() async throws -> [Int] {
        var ids: [Int] = []
        for try await page in self {
            ids.append(contentsOf: page.objectIDs)
        }
        return ids
    }
}
