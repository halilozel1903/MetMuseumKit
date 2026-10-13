import Foundation

/// The filters of `GET /search`.
///
/// ```swift
/// // Highlighted European paintings with images.
/// MetSearchQuery(isHighlight: true, hasImages: true, departmentID: 11)
///
/// // "sunflowers" in the title only, made in France between 1850 and 1900, in oil.
/// MetSearchQuery("sunflowers", field: .title, medium: ["Paintings"], geoLocation: ["France"], dates: 1850...1900)
/// ```
///
/// Only the filters you set are sent. `true`/`false` filters are sent as `true` or `false`; leave
/// one `nil` to not filter on it.
public struct MetSearchQuery: Hashable, Sendable {
    /// The search term (`q`). Optional on `/v1.1/search`: a filter-only search returns every
    /// match, such as every highlight of a department.
    public var text: String?
    /// Which field `text` is matched against.
    public var field: MetSearchField
    /// `isHighlight`: only works the museum marks as highlights.
    public var isHighlight: Bool?
    /// `hasImages`: only works with images. Note that the API counts works whose images are not
    /// served (not in the public domain) as having images; filter the fetched objects with
    /// ``MetObject/hasPublicDomainImage`` as well.
    public var hasImages: Bool?
    /// `isOnView`: only works on view in the museum.
    public var isOnView: Bool?
    /// `departmentId`.
    public var departmentID: Int?
    /// `medium`, values joined with `|`, such as `["Paintings"]` or `["Quilts", "Silk"]`.
    public var medium: [String]
    /// `geoLocation`, values joined with `|`, such as `["France", "Paris"]`.
    public var geoLocation: [String]
    /// `dateBegin` and `dateEnd`, in years; negative years are B.C. The API needs both, so they
    /// are one range.
    public var dates: ClosedRange<Int>?

    public init(
        _ text: String? = nil,
        field: MetSearchField = .anywhere,
        isHighlight: Bool? = nil,
        hasImages: Bool? = nil,
        isOnView: Bool? = nil,
        departmentID: Int? = nil,
        medium: [String] = [],
        geoLocation: [String] = [],
        dates: ClosedRange<Int>? = nil
    ) {
        self.text = text
        self.field = field
        self.isHighlight = isHighlight
        self.hasImages = hasImages
        self.isOnView = isOnView
        self.departmentID = departmentID
        self.medium = medium
        self.geoLocation = geoLocation
        self.dates = dates
    }

    /// `dateBegin`.
    public var dateBegin: Int? { dates?.lowerBound }
    /// `dateEnd`.
    public var dateEnd: Int? { dates?.upperBound }

    /// The query items, in a stable order with `q` last. Blank values are left out.
    public var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        func flag(_ name: String, _ value: Bool?) {
            if let value { items.append(URLQueryItem(name: name, value: value ? "true" : "false")) }
        }
        flag("isHighlight", isHighlight)
        if let name = field.parameter {
            items.append(URLQueryItem(name: name, value: "true"))
        }
        if let departmentID {
            items.append(URLQueryItem(name: "departmentId", value: String(departmentID)))
        }
        flag("isOnView", isOnView)
        let media = medium.compactMap(\.nonEmpty)
        if !media.isEmpty {
            items.append(URLQueryItem(name: "medium", value: media.joined(separator: "|")))
        }
        flag("hasImages", hasImages)
        let places = geoLocation.compactMap(\.nonEmpty)
        if !places.isEmpty {
            items.append(URLQueryItem(name: "geoLocation", value: places.joined(separator: "|")))
        }
        if let dates {
            items.append(URLQueryItem(name: "dateBegin", value: String(dates.lowerBound)))
            items.append(URLQueryItem(name: "dateEnd", value: String(dates.upperBound)))
        }
        if let text = text?.nonEmpty {
            items.append(URLQueryItem(name: "q", value: text))
        }
        return items
    }

    /// A query with `isHighlight`, `hasImages` and `departmentID` set: the highlights of a
    /// department that have images.
    public static func highlights(departmentID: Int? = nil) -> MetSearchQuery {
        MetSearchQuery(isHighlight: true, hasImages: true, departmentID: departmentID)
    }
}

/// Which field the search term is matched against.
public enum MetSearchField: String, CaseIterable, Hashable, Sendable {
    /// Any of the object's data (the default).
    case anywhere
    /// `title=true`: the title only.
    case title
    /// `tags=true`: the subject keywords only.
    case tags
    /// `artistOrCulture=true`: the artist's name or the culture only.
    case artistOrCulture

    /// The parameter that selects this field, or `nil` for ``anywhere``.
    var parameter: String? {
        switch self {
        case .anywhere: return nil
        case .title: return "title"
        case .tags: return "tags"
        case .artistOrCulture: return "artistOrCulture"
        }
    }
}

/// One page of search results: object IDs, the total, and where the page starts.
public struct MetSearchPage: Hashable, Sendable {
    /// Every match across all pages.
    public var total: Int
    /// The IDs on this page, in the API's order.
    public var objectIDs: [Int]
    /// The index of the first ID on this page.
    public var offset: Int
    /// The page size that was asked for.
    public var limit: Int

    public init(total: Int, objectIDs: [Int], offset: Int, limit: Int) {
        self.total = total
        self.objectIDs = objectIDs
        self.offset = offset
        self.limit = limit
    }

    /// Whether this page holds no IDs.
    public var isEmpty: Bool { objectIDs.isEmpty }

    /// The offset of the next page, or `nil` on the last reachable page. The API serves only the
    /// first ``MetMuseumClient/maxSearchResults`` results of a query.
    public var nextOffset: Int? {
        let next = offset + objectIDs.count
        guard !objectIDs.isEmpty, next < min(total, MetMuseumClient.maxSearchResults) else { return nil }
        return next
    }

    /// Whether there is another page.
    public var hasMore: Bool { nextOffset != nil }
}
