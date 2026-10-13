import Foundation

/// A curatorial department, as `GET /departments` lists it.
public struct MetDepartment: Codable, Hashable, Identifiable, Sendable {
    /// `departmentId`. Pass it to ``MetSearchQuery/departmentID`` or
    /// ``MetMuseumClient/objectIDs(departmentIDs:metadataDate:)``.
    public var id: Int
    /// Such as `"European Paintings"`.
    public var displayName: String

    public init(id: Int, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case id = "departmentId"
        case displayName
    }
}

/// The body of `GET /departments`.
struct DepartmentsResponse: Decodable {
    let departments: [MetDepartment]

    enum CodingKeys: String, CodingKey {
        case departments
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        departments = c.lossyArray(MetDepartment.self, .departments)
    }
}

/// A list of object IDs with the total count: the body of `GET /objects`.
public struct MetObjectIDList: Codable, Hashable, Sendable {
    /// How many objects match.
    public var total: Int
    /// Their IDs. The API sends `null` when nothing matches; that is read as empty.
    public var objectIDs: [Int]

    public init(total: Int, objectIDs: [Int]) {
        self.total = total
        self.objectIDs = objectIDs
    }

    enum CodingKeys: String, CodingKey {
        case total, objectIDs
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        objectIDs = c.lossyArray(Int.self, .objectIDs)
        total = c.lossyInt(.total) ?? objectIDs.count
    }

    /// Whether nothing matched.
    public var isEmpty: Bool { objectIDs.isEmpty }
}
