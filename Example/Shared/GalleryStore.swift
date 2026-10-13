import Foundation
import Observation
import MetMuseumKit

/// The app's data, all from one `MetMuseumClient` on the live collection API: the departments,
/// and caches for the objects and highlight lists already loaded.
@Observable
@MainActor
final class GalleryStore {
    let client: MetMuseumClient

    private(set) var departments: [MetDepartment] = []
    private(set) var departmentsError: String?

    @ObservationIgnored private var objectCache: [Int: MetObject] = [:]
    @ObservationIgnored private var highlightCache: [Int: [MetObject]] = [:]
    /// How many times a request is tried before the error is shown.
    private let attempts: Int

    init(client: MetMuseumClient, attempts: Int = 1) {
        self.client = client
        self.attempts = max(1, attempts)
    }

    /// The live API. Screenshot scenes retry failed requests a few times, since a capture must not
    /// show an error.
    static func make(for scene: ScreenshotScene?) -> GalleryStore {
        GalleryStore(client: .shared, attempts: scene == nil ? 1 : 4)
    }

    /// Runs `operation`, trying again after a pause when it fails, up to `attempts` times.
    nonisolated static func retrying<T: Sendable>(
        attempts: Int,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch {
                guard attempt < attempts, !Task.isCancelled else { throw error }
                print("Request failed (attempt \(attempt) of \(attempts)): \(error)")
                try await Task.sleep(for: .seconds(Double(attempt) * 3))
                attempt += 1
            }
        }
    }

    // MARK: - Departments

    func loadDepartments() async {
        guard departments.isEmpty else { return }
        let client = self.client
        do {
            departments = try await Self.retrying(attempts: attempts) {
                try await client.departments()
            }
            departmentsError = nil
        } catch {
            departmentsError = error.localizedDescription
        }
    }

    func department(id: Int) -> MetDepartment? {
        departments.first { $0.id == id }
    }

    // MARK: - Objects

    func object(id: Int) async throws -> MetObject {
        if let cached = objectCache[id] {
            return cached
        }
        let client = self.client
        let object = try await Self.retrying(attempts: attempts) {
            try await client.object(id: id)
        }
        objectCache[id] = object
        return object
    }

    /// The highlights of a department that are in the public domain and have an image.
    func highlights(departmentID: Int, limit: Int = 24) async throws -> [MetObject] {
        if let cached = highlightCache[departmentID] {
            return cached
        }
        let client = self.client
        let objects = try await Self.retrying(attempts: attempts) {
            try await client.highlights(departmentID: departmentID, limit: limit)
        }
        remember(objects)
        highlightCache[departmentID] = objects
        return objects
    }

    /// The number of matches and the first `limit` objects with an image, optionally only those
    /// in the public domain.
    func search(_ query: MetSearchQuery, publicDomainOnly: Bool, limit: Int = 30) async throws -> SearchResult {
        let client = self.client
        let result = try await Self.retrying(attempts: attempts) {
            let page = try await client.search(query, limit: 1)
            let objects = try await client.searchObjects(query, limit: limit, publicDomainOnly: publicDomainOnly)
            return SearchResult(total: page.total, objects: objects)
        }
        remember(result.objects)
        return result
    }

    private func remember(_ objects: [MetObject]) {
        for object in objects {
            objectCache[object.id] = object
        }
    }
}

struct SearchResult: Sendable {
    var total: Int
    var objects: [MetObject]
}
