import Foundation

/// A work in The Met's collection, as `GET /objects/{objectID}` returns it.
///
/// Every field of the API is here under a Swift name. Empty strings are kept as the API sends them
/// (most fields are `""` when unknown); the computed properties below turn them into optionals,
/// URLs and dates. Records that send `null`, leave a key out, or use a number for a string are read
/// without failing.
///
/// The image fields are empty for works that are not in the public domain: the API only serves
/// images of Open Access works. Use ``isPublicDomain`` or ``hasPublicDomainImage`` to filter.
public struct MetObject: Codable, Hashable, Identifiable, Sendable {
    /// `objectID`.
    public var id: Int
    public var isHighlight: Bool
    public var accessionNumber: String
    public var accessionYear: String
    /// Whether the work is Open Access (CC0). Only these works have images in the API.
    public var isPublicDomain: Bool
    /// The full-size image (`…/original/…`), or `""`.
    public var primaryImage: String
    /// A web-sized image (`…/web-large/…`, about 1,000 pixels on the long side), or `""`.
    public var primaryImageSmall: String
    /// More full-size images: other views and details.
    public var additionalImages: [String]
    public var constituents: [MetConstituent]
    public var department: String
    public var objectName: String
    public var title: String
    public var culture: String
    public var period: String
    public var dynasty: String
    public var reign: String
    public var portfolio: String
    public var artistRole: String
    public var artistPrefix: String
    public var artistDisplayName: String
    public var artistDisplayBio: String
    public var artistSuffix: String
    public var artistAlphaSort: String
    public var artistNationality: String
    public var artistBeginDate: String
    public var artistEndDate: String
    public var artistGender: String
    public var artistWikidataURL: String
    public var artistULANURL: String
    /// The date as written by the museum, such as `"1889"` or `"ca. 1665"`.
    public var objectDate: String
    /// The first year of the date range, negative for B.C.
    public var objectBeginDate: Int
    /// The last year of the date range, negative for B.C.
    public var objectEndDate: Int
    public var medium: String
    public var dimensions: String
    public var measurements: [MetMeasurement]
    public var creditLine: String
    public var geographyType: String
    public var city: String
    public var state: String
    public var county: String
    public var country: String
    public var region: String
    public var subregion: String
    public var locale: String
    public var locus: String
    public var excavation: String
    public var river: String
    public var classification: String
    public var rightsAndReproduction: String
    public var linkResource: String
    /// When the record last changed, as the API writes it (`2026-07-29T04:54:31.183Z`).
    public var metadataDate: String
    public var repository: String
    /// The work's page on metmuseum.org.
    public var objectURL: String
    public var tags: [MetTag]
    public var objectWikidataURL: String
    public var isTimelineWork: Bool
    /// The gallery the work hangs in, such as `"822"`, or `""` when it is not on view.
    public var galleryNumber: String

    enum CodingKeys: String, CodingKey {
        case id = "objectID"
        case isHighlight, accessionNumber, accessionYear, isPublicDomain
        case primaryImage, primaryImageSmall, additionalImages, constituents
        case department, objectName, title, culture, period, dynasty, reign, portfolio
        case artistRole, artistPrefix, artistDisplayName, artistDisplayBio, artistSuffix
        case artistAlphaSort, artistNationality, artistBeginDate, artistEndDate, artistGender
        case artistWikidataURL = "artistWikidata_URL"
        case artistULANURL = "artistULAN_URL"
        case objectDate, objectBeginDate, objectEndDate, medium, dimensions, measurements
        case creditLine, geographyType, city, state, county, country, region, subregion
        case locale, locus, excavation, river, classification, rightsAndReproduction
        case linkResource, metadataDate, repository, objectURL, tags
        case objectWikidataURL = "objectWikidata_URL"
        case isTimelineWork
        case galleryNumber = "GalleryNumber"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.lossyInt(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, DecodingError.Context(
                codingPath: c.codingPath,
                debugDescription: "An object needs an objectID"
            ))
        }
        self.id = id
        isHighlight = c.lossyBool(.isHighlight)
        accessionNumber = c.lossyString(.accessionNumber)
        accessionYear = c.lossyString(.accessionYear)
        isPublicDomain = c.lossyBool(.isPublicDomain)
        primaryImage = c.lossyString(.primaryImage)
        primaryImageSmall = c.lossyString(.primaryImageSmall)
        additionalImages = c.lossyArray(String.self, .additionalImages)
        constituents = c.lossyArray(MetConstituent.self, .constituents)
        department = c.lossyString(.department)
        objectName = c.lossyString(.objectName)
        title = c.lossyString(.title)
        culture = c.lossyString(.culture)
        period = c.lossyString(.period)
        dynasty = c.lossyString(.dynasty)
        reign = c.lossyString(.reign)
        portfolio = c.lossyString(.portfolio)
        artistRole = c.lossyString(.artistRole)
        artistPrefix = c.lossyString(.artistPrefix)
        artistDisplayName = c.lossyString(.artistDisplayName)
        artistDisplayBio = c.lossyString(.artistDisplayBio)
        artistSuffix = c.lossyString(.artistSuffix)
        artistAlphaSort = c.lossyString(.artistAlphaSort)
        artistNationality = c.lossyString(.artistNationality)
        artistBeginDate = c.lossyString(.artistBeginDate)
        artistEndDate = c.lossyString(.artistEndDate)
        artistGender = c.lossyString(.artistGender)
        artistWikidataURL = c.lossyString(.artistWikidataURL)
        artistULANURL = c.lossyString(.artistULANURL)
        objectDate = c.lossyString(.objectDate)
        objectBeginDate = c.lossyInt(.objectBeginDate) ?? 0
        objectEndDate = c.lossyInt(.objectEndDate) ?? 0
        medium = c.lossyString(.medium)
        dimensions = c.lossyString(.dimensions)
        measurements = c.lossyArray(MetMeasurement.self, .measurements)
        creditLine = c.lossyString(.creditLine)
        geographyType = c.lossyString(.geographyType)
        city = c.lossyString(.city)
        state = c.lossyString(.state)
        county = c.lossyString(.county)
        country = c.lossyString(.country)
        region = c.lossyString(.region)
        subregion = c.lossyString(.subregion)
        locale = c.lossyString(.locale)
        locus = c.lossyString(.locus)
        excavation = c.lossyString(.excavation)
        river = c.lossyString(.river)
        classification = c.lossyString(.classification)
        rightsAndReproduction = c.lossyString(.rightsAndReproduction)
        linkResource = c.lossyString(.linkResource)
        metadataDate = c.lossyString(.metadataDate)
        repository = c.lossyString(.repository)
        objectURL = c.lossyString(.objectURL)
        tags = c.lossyArray(MetTag.self, .tags)
        objectWikidataURL = c.lossyString(.objectWikidataURL)
        isTimelineWork = c.lossyBool(.isTimelineWork)
        galleryNumber = c.lossyString(.galleryNumber)
    }
}

// MARK: - Convenience

extension MetObject {
    /// The title, or the object name (such as `"Painting"`) when the title is empty.
    public var displayTitle: String {
        title.nonEmpty ?? objectName.nonEmpty ?? "Untitled"
    }

    /// The artist's name, or the culture (such as `"Japan"`) for works without a known maker.
    public var displayArtist: String? {
        artistDisplayName.nonEmpty ?? culture.nonEmpty
    }

    /// The date as written by the museum, or the year range when that is empty.
    public var displayDate: String? {
        if let date = objectDate.nonEmpty { return date }
        guard let range = dateRange else { return nil }
        let begin = MetObject.year(range.lowerBound)
        return range.lowerBound == range.upperBound ? begin : begin + "–" + MetObject.year(range.upperBound)
    }

    /// `objectBeginDate...objectEndDate`, or `nil` when the API sends no dates (both `0`) or an
    /// inverted range.
    public var dateRange: ClosedRange<Int>? {
        if objectBeginDate == 0 && objectEndDate == 0 { return nil }
        guard objectBeginDate <= objectEndDate else { return nil }
        return objectBeginDate...objectEndDate
    }

    /// `"1889"`, or `"300 B.C."` for a negative year.
    static func year(_ value: Int) -> String {
        value < 0 ? String(-value) + " B.C." : String(value)
    }

    /// The work's page on metmuseum.org.
    public var webURL: URL? {
        objectURL.httpURL
    }

    /// The constituent with the role `"Artist"`, or the first constituent.
    public var primaryConstituent: MetConstituent? {
        constituents.first { $0.role.caseInsensitiveCompare("Artist") == .orderedSame } ?? constituents.first
    }

    /// Where the work comes from: city, region and country, the most specific first.
    public var place: String? {
        let parts = [city, state, region, country].compactMap(\.nonEmpty)
        var seen = Set<String>()
        let unique = parts.filter { seen.insert($0).inserted }
        return unique.isEmpty ? nil : unique.joined(separator: ", ")
    }

    /// The subject keywords, such as `["Landscapes", "Cypresses", "Summer"]`.
    public var tagTerms: [String] {
        tags.compactMap { $0.term.nonEmpty }
    }

    /// When the record last changed, or `nil` when the date can't be read.
    public var metadataDateValue: Date? {
        MetDate.parse(metadataDate)
    }

    /// The overall measurements, such as height and width in centimeters, when the API lists them.
    public var overallMeasurement: MetMeasurement? {
        measurements.first { $0.elementName.caseInsensitiveCompare("Overall") == .orderedSame } ?? measurements.first
    }
}

/// A person or company that made or is otherwise linked to a work.
public struct MetConstituent: Codable, Hashable, Sendable {
    public var constituentID: Int
    /// Such as `"Artist"`, `"Maker"` or `"Publisher"`.
    public var role: String
    public var name: String
    public var constituentULANURL: String
    public var constituentWikidataURL: String
    public var gender: String

    enum CodingKeys: String, CodingKey {
        case constituentID, role, name, gender
        case constituentULANURL = "constituentULAN_URL"
        case constituentWikidataURL = "constituentWikidata_URL"
    }

    public init(constituentID: Int, role: String, name: String, constituentULANURL: String = "", constituentWikidataURL: String = "", gender: String = "") {
        self.constituentID = constituentID
        self.role = role
        self.name = name
        self.constituentULANURL = constituentULANURL
        self.constituentWikidataURL = constituentWikidataURL
        self.gender = gender
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        constituentID = c.lossyInt(.constituentID) ?? 0
        role = c.lossyString(.role)
        name = c.lossyString(.name)
        constituentULANURL = c.lossyString(.constituentULANURL)
        constituentWikidataURL = c.lossyString(.constituentWikidataURL)
        gender = c.lossyString(.gender)
    }
}

/// One measured part of a work, such as `"Overall"` or `"Frame"`.
public struct MetMeasurement: Codable, Hashable, Sendable {
    public var elementName: String
    public var elementDescription: String?
    /// Values by name, such as `["Height": 73.2, "Width": 93.4]`: centimeters for lengths,
    /// kilograms for weights.
    public var elementMeasurements: [String: Double]

    public init(elementName: String, elementDescription: String? = nil, elementMeasurements: [String: Double]) {
        self.elementName = elementName
        self.elementDescription = elementDescription
        self.elementMeasurements = elementMeasurements
    }

    enum CodingKeys: String, CodingKey {
        case elementName, elementDescription, elementMeasurements
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        elementName = c.lossyString(.elementName)
        elementDescription = (try? c.decodeIfPresent(String.self, forKey: .elementDescription)) ?? nil
        elementMeasurements = (try? c.decodeIfPresent([String: Double].self, forKey: .elementMeasurements)) ?? [:]
    }

    /// The height in centimeters.
    public var height: Double? { elementMeasurements["Height"] }
    /// The width in centimeters.
    public var width: Double? { elementMeasurements["Width"] }
    /// The depth in centimeters.
    public var depth: Double? { elementMeasurements["Depth"] }
}

/// A subject keyword, with links to the Getty AAT and Wikidata.
public struct MetTag: Codable, Hashable, Sendable {
    public var term: String
    public var aatURL: String?
    public var wikidataURL: String?

    enum CodingKeys: String, CodingKey {
        case term
        case aatURL = "AAT_URL"
        case wikidataURL = "Wikidata_URL"
    }

    public init(term: String, aatURL: String? = nil, wikidataURL: String? = nil) {
        self.term = term
        self.aatURL = aatURL
        self.wikidataURL = wikidataURL
    }
}

/// Reads the API's ISO 8601 timestamps, with or without fractional seconds.
enum MetDate {
    static func parse(_ text: String) -> Date? {
        guard let text = text.nonEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: text)
    }

    /// `YYYY-MM-DD` in UTC, the format the `metadataDate` parameter takes.
    static func day(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
