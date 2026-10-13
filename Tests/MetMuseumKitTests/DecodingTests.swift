import Foundation
import Testing
@testable import MetMuseumKit

@Suite("Decoding")
struct DecodingTests {
    @Test func publicDomainPainting() throws {
        let object = try Fixture.decode(MetObject.self, from: "object-436535")

        #expect(object.id == 436535)
        #expect(object.title == "Wheat Field with Cypresses")
        #expect(object.isHighlight)
        #expect(object.isPublicDomain)
        #expect(object.hasPublicDomainImage)
        #expect(object.artistDisplayName == "Vincent van Gogh")
        #expect(object.artistWikidataURL == "https://www.wikidata.org/wiki/Q5582")
        #expect(object.department == "European Paintings")
        #expect(object.objectBeginDate == 1889)
        #expect(object.objectEndDate == 1889)
        #expect(object.dateRange == 1889...1889)
        #expect(object.displayDate == "1889")
        #expect(object.galleryNumber == "822")
        #expect(object.isTimelineWork)
        #expect(object.objectWikidataURL == "https://www.wikidata.org/wiki/Q18578426")
        #expect(object.tagTerms == ["Landscapes", "Cypresses", "Summer"])
        #expect(object.tags.first?.aatURL == "http://vocab.getty.edu/page/aat/300132294")
        #expect(object.webURL?.absoluteString == "https://www.metmuseum.org/art/collection/search/436535")
        #expect(object.metadataDateValue != nil)
    }

    @Test func constituentsAndMeasurements() throws {
        let object = try Fixture.decode(MetObject.self, from: "object-436535")

        let artist = try #require(object.primaryConstituent)
        #expect(artist.constituentID == 161947)
        #expect(artist.role == "Artist")
        #expect(artist.constituentULANURL == "http://vocab.getty.edu/page/ulan/500115588")

        #expect(object.measurements.count == 2)
        let overall = try #require(object.overallMeasurement)
        #expect(overall.elementName == "Overall")
        #expect(overall.elementDescription == nil)
        #expect(overall.height == 73.2)
        #expect(overall.width == 93.4)
        #expect(overall.depth == nil)
    }

    @Test func restrictedWorkHasNoImage() throws {
        let object = try Fixture.decode(MetObject.self, from: "object-restricted")

        #expect(object.id == 1)
        #expect(!object.isPublicDomain)
        #expect(!object.hasImage)
        #expect(!object.hasPublicDomainImage)
        #expect(object.imageURL(.small) == nil)
        #expect(object.imageURL(.original) == nil)
        #expect(object.allImageURLs().isEmpty)
        #expect(object.measurements.isEmpty)
        #expect(object.tags.isEmpty)
        #expect(object.primaryConstituent?.role == "Maker")
        #expect(object.place == "Philadelphia, United States")
    }

    @Test func lossyRecord() throws {
        let object = try Fixture.decode(MetObject.self, from: "object-lossy")

        #expect(object.id == 5432)
        #expect(!object.isHighlight)
        #expect(object.accessionYear == "1917")
        #expect(object.primaryImageSmall == "")
        #expect(object.additionalImages.isEmpty)
        #expect(object.constituents.isEmpty)
        #expect(object.period == "")
        #expect(object.galleryNumber == "305")
        #expect(object.measurements.first?.elementMeasurements.isEmpty == true)
        #expect(object.tagTerms == ["Saints"])
        #expect(object.displayTitle == "Plaque")
        #expect(object.displayArtist == "Byzantine")
        #expect(object.displayDate == "300 B.C.–250 B.C.")
        #expect(object.metadataDateValue != nil)
    }

    @Test func objectWithoutIDFails() {
        let data = Data(#"{"title":"No id"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MetObject.self, from: data)
        }
    }

    @Test func encodesBackToTheAPIShape() throws {
        let object = try Fixture.decode(MetObject.self, from: "object-436535")
        let data = try JSONEncoder().encode(object)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["objectID"] as? Int == 436535)
        #expect(json["GalleryNumber"] as? String == "822")
        #expect(json["artistULAN_URL"] as? String == "http://vocab.getty.edu/page/ulan/500115588")
        let again = try JSONDecoder().decode(MetObject.self, from: data)
        #expect(again == object)
    }

    @Test func departments() throws {
        let response = try Fixture.decode(DepartmentsResponse.self, from: "departments")

        #expect(response.departments.count == 19)
        #expect(response.departments.first == MetDepartment(id: 1, displayName: "American Decorative Arts"))
        #expect(response.departments.contains(MetDepartment(id: 11, displayName: "European Paintings")))
    }

    @Test func emptySearchReadsNullAsEmpty() throws {
        let list = try Fixture.decode(MetObjectIDList.self, from: "search-empty")

        #expect(list.total == 0)
        #expect(list.objectIDs.isEmpty)
        #expect(list.isEmpty)
    }

    @Test func objectIDList() throws {
        let list = try Fixture.decode(MetObjectIDList.self, from: "search-highlights")

        #expect(list.total == 125)
        #expect(list.objectIDs.count == 10)
        #expect(list.objectIDs.first == 435600)
    }
}
