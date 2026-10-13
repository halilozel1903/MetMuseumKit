import Foundation
import Testing
@testable import MetMuseumKit

extension StubResponse {
    /// A small object record in the API's shape.
    static func object(_ id: Int, publicDomain: Bool = true, image: Bool = true) -> StubResponse {
        let small = image && publicDomain ? "https://images.metmuseum.org/CRDImages/ep/web-large/DT\(id).jpg" : ""
        let original = image && publicDomain ? "https://images.metmuseum.org/CRDImages/ep/original/DT\(id).jpg" : ""
        let json: [String: Any] = [
            "objectID": id,
            "isHighlight": true,
            "isPublicDomain": publicDomain,
            "primaryImage": original,
            "primaryImageSmall": small,
            "additionalImages": [String](),
            "title": "Object \(id)",
            "department": "European Paintings",
        ]
        let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        return StubResponse(status: 200, headers: ["Content-Type": "application/json"], body: body)
    }

    /// A search or object list response.
    static func ids(_ ids: [Int], total: Int? = nil) -> StubResponse {
        let json: [String: Any] = ["total": total ?? ids.count, "objectIDs": ids]
        let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        return StubResponse(status: 200, headers: ["Content-Type": "application/json"], body: body)
    }
}

@Suite("MetMuseumClient requests")
struct ClientTests {
    @Test func singleObject() async throws {
        let stub = StubbedClient { _ in try .json("object-436535") }
        let object = try await stub.client.object(id: 436535)

        #expect(object.title == "Wheat Field with Cypresses")
        #expect(stub.lastPath == "/public/collection/v1/objects/436535")
        #expect(stub.lastQuery.isEmpty)
        let request = try #require(stub.requests.last)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func userAgentWhenSet() async throws {
        let host = "stub-agent.metmuseum.test"
        StubRegistry.shared.register({ _ in try .json("departments") }, for: host)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let client = MetMuseumClient(configuration: MetMuseumConfiguration(
            baseURL: URL(string: "https://" + host + "/public/collection/v1")!,
            session: URLSession(configuration: configuration),
            requestsPerSecond: 0,
            userAgent: "MyGallery/2.0"
        ))
        _ = try await client.departments()
        let request = try #require(StubRegistry.shared.requests(for: host).last)
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "MyGallery/2.0")
    }

    @Test func missingObject() async throws {
        let stub = StubbedClient { _ in try .json("error-not-found", status: 404) }
        do {
            _ = try await stub.client.object(id: 999_999_999)
            Issue.record("Expected a not-found error")
        } catch let error as MetMuseumError {
            #expect(error.isNotFound)
            #expect(error.errorDescription == "ObjectID not found")
        }
    }

    @Test func departments() async throws {
        let stub = StubbedClient { _ in try .json("departments") }
        let departments = try await stub.client.departments()

        #expect(departments.count == 19)
        #expect(departments.first(where: { $0.id == 11 })?.displayName == "European Paintings")
        #expect(stub.lastPath == "/public/collection/v1/departments")
    }

    @Test func objectIDsWithFilters() async throws {
        let stub = StubbedClient { _ in try .json("objects-departments") }
        let day = try #require(ISO8601DateFormatter().date(from: "2026-09-04T12:00:00Z"))
        let list = try await stub.client.objectIDs(departmentIDs: [3, 9, 12], metadataDate: day)

        #expect(list.objectIDs == [1, 2, 3, 4])
        #expect(stub.lastPath == "/public/collection/v1/objects")
        #expect(stub.lastQueryValue("departmentIds") == "3|9|12")
        #expect(stub.lastQueryValue("metadataDate") == "2026-09-04")
    }

    @Test func searchUsesTheV11Endpoint() async throws {
        let stub = StubbedClient { _ in try .json("search-highlights") }
        let page = try await stub.client.search(.highlights(departmentID: 11), offset: 20, limit: 10)

        #expect(stub.lastPath == "/public/collection/v1.1/search")
        #expect(stub.lastQueryValue("isHighlight") == "true")
        #expect(stub.lastQueryValue("hasImages") == "true")
        #expect(stub.lastQueryValue("departmentId") == "11")
        #expect(stub.lastQueryValue("offset") == "20")
        #expect(stub.lastQueryValue("limit") == "10")
        #expect(stub.lastQueryValue("q") == nil)
        #expect(page.total == 125)
        #expect(page.offset == 20)
        #expect(page.objectIDs.count == 10)
        #expect(page.nextOffset == 30)
    }

    @Test func searchEncodesPlusAndPipes() async throws {
        let stub = StubbedClient { _ in try .json("search-empty") }
        let page = try await stub.client.search(MetSearchQuery("C++ guide", medium: ["Silk", "Quilts"]))

        #expect(page.isEmpty)
        let query = try #require(stub.requests.last?.url?.query)
        #expect(query.contains("q=C%2B%2B%20guide"))
        #expect(stub.lastQueryValue("q") == "C++ guide")
        #expect(stub.lastQueryValue("medium") == "Silk|Quilts")
    }

    @Test func searchLimits() async throws {
        let stub = StubbedClient { _ in try .json("search-empty") }
        _ = try await stub.client.search(MetSearchQuery("cat"), limit: 2_000)
        #expect(stub.lastQueryValue("limit") == "500")

        _ = try await stub.client.search(MetSearchQuery("cat"), offset: 9_900, limit: 500)
        #expect(stub.lastQueryValue("limit") == "100")

        await #expect(throws: MetMuseumError.self) {
            _ = try await stub.client.search(MetSearchQuery("cat"), offset: 10_000)
        }
    }

    @Test func searchPagesFollowOffsets() async throws {
        let all = Array(1...7)
        let stub = StubbedClient { request in
            let offset = Int(request.queryValue("offset") ?? "0") ?? 0
            let limit = Int(request.queryValue("limit") ?? "100") ?? 100
            let slice = Array(all.dropFirst(offset).prefix(limit))
            return .ids(slice, total: all.count)
        }
        let ids = try await stub.client.searchPages(MetSearchQuery("x"), pageSize: 3).collectIDs()

        #expect(ids == all)
        #expect(stub.requests.compactMap { $0.queryValue("offset") } == ["0", "3", "6"])
    }

    @Test func objectsKeepOrderAndSkipMissing() async throws {
        let stub = StubbedClient(maxConcurrentRequests: 3) { request in
            guard let id = request.objectID else { return .status(500) }
            if id == 3 { return try .json("error-not-found", status: 404) }
            return .object(id)
        }
        let objects = try await stub.client.objects(ids: [5, 1, 3, 4, 1, 2])

        #expect(objects.map(\.id) == [5, 1, 4, 2])
        #expect(stub.requests.count == 5)
    }

    @Test func objectsStopOnOtherErrors() async throws {
        let stub = StubbedClient(maxRetries: 0) { request in
            request.objectID == 2 ? .status(500) : .object(request.objectID ?? 0)
        }
        await #expect(throws: MetMuseumError.self) {
            _ = try await stub.client.objects(ids: [1, 2, 3])
        }
    }

    @Test func searchObjectsKeepsPublicDomainImagesUpToTheLimit() async throws {
        // 1, 4 and 7 are not public domain; 5 has no image.
        let stub = StubbedClient { request in
            if request.url?.path.hasSuffix("/search") == true {
                return .ids(Array(1...12))
            }
            let id = request.objectID ?? 0
            return .object(id, publicDomain: id % 3 != 1, image: id != 5)
        }
        let objects = try await stub.client.searchObjects(.highlights(departmentID: 11), limit: 4)

        #expect(objects.map(\.id) == [2, 3, 6, 8])
        #expect(objects.allSatisfy(\.hasPublicDomainImage))
    }

    @Test func searchObjectsWithoutFilters() async throws {
        let stub = StubbedClient { request in
            if request.url?.path.hasSuffix("/search") == true {
                return .ids([1, 2, 3])
            }
            let id = request.objectID ?? 0
            return .object(id, publicDomain: id != 2)
        }
        let objects = try await stub.client.searchObjects(MetSearchQuery("x"), limit: 10, publicDomainOnly: false, requireImage: false)
        #expect(objects.map(\.id) == [1, 2, 3])
    }

    @Test func retriesWhenBusy() async throws {
        let counter = Counter()
        let stub = StubbedClient { _ in
            if counter.increment() == 1 {
                return .status(503)
            }
            return try .json("departments")
        }
        let departments = try await stub.client.departments()

        #expect(departments.count == 19)
        #expect(stub.requests.count == 2)
    }

    @Test func givesUpAfterRetries() async throws {
        let stub = StubbedClient(maxRetries: 1) { _ in .status(429) }
        do {
            _ = try await stub.client.departments()
            Issue.record("Expected an HTTP error")
        } catch MetMuseumError.http(let statusCode, _, _) {
            #expect(statusCode == 429)
        }
        #expect(stub.requests.count == 2)
    }

    @Test func forbiddenIsNotRetried() async throws {
        let stub = StubbedClient { _ in .raw("<html>Access denied</html>", status: 403) }
        await #expect(throws: MetMuseumError.self) {
            _ = try await stub.client.departments()
        }
        #expect(stub.requests.count == 1)
    }

    @Test func badJSON() async throws {
        let stub = StubbedClient { _ in .raw("not json") }
        do {
            _ = try await stub.client.departments()
            Issue.record("Expected a decoding error")
        } catch MetMuseumError.decoding(let type, _) {
            #expect(type == "DepartmentsResponse")
        }
    }

    @Test func defaultSearchURL() {
        let configuration = MetMuseumConfiguration()
        #expect(configuration.baseURL.absoluteString == "https://collectionapi.metmuseum.org/public/collection/v1")
        #expect(configuration.searchURL.absoluteString == "https://collectionapi.metmuseum.org/public/collection/v1.1/search")
        #expect(configuration.requestsPerSecond == 80)
        #expect(configuration.maxConcurrentRequests == 6)
    }
}

/// A thread-safe counter for stub handlers.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    /// Adds one and returns the new value.
    func increment() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}
