import Foundation
import Testing
@testable import MetMuseumKit

@Suite("Image URLs")
struct ImageTests {
    @Test func smallAndOriginal() throws {
        let object = try Fixture.decode(MetObject.self, from: "object-436535")

        #expect(object.imageURL(.small)?.absoluteString == "https://images.metmuseum.org/CRDImages/ep/web-large/DP-42549-001.jpg")
        #expect(object.imageURL(.original)?.absoluteString == "https://images.metmuseum.org/CRDImages/ep/original/DP-42549-001.jpg")
        #expect(object.smallImageURL == object.imageURL(.small))
        #expect(object.originalImageURL == object.imageURL(.original))
    }

    @Test func additionalImagesInBothSizes() throws {
        let object = try Fixture.decode(MetObject.self, from: "object-436535")

        #expect(object.additionalImageURLs(.small).map(\.absoluteString) == [
            "https://images.metmuseum.org/CRDImages/ep/web-large/DP-42549-002.jpg",
            "https://images.metmuseum.org/CRDImages/ep/web-large/DP-42549-003.jpg",
        ])
        #expect(object.additionalImageURLs(.original).first?.absoluteString == "https://images.metmuseum.org/CRDImages/ep/original/DP-42549-002.jpg")
        #expect(object.allImageURLs().count == 3)
    }

    @Test func smallFallsBackToTheWebRenditionOfTheOriginal() throws {
        let object = try Fixture.decode(MetObject.self, from: "object-lossy")

        #expect(object.imageURL(.small)?.absoluteString == "https://images.metmuseum.org/CRDImages/md/web-large/DP123.jpg")
        #expect(object.imageURL(.original)?.absoluteString == "https://images.metmuseum.org/CRDImages/md/original/DP123.jpg")
    }

    @Test func renditions() throws {
        let original = try #require(URL(string: "https://images.metmuseum.org/CRDImages/as/original/DP251139.jpg"))

        #expect(MetImageRendition(of: original) == .original)
        #expect(MetImageRendition.webLarge.url(for: original)?.absoluteString == "https://images.metmuseum.org/CRDImages/as/web-large/DP251139.jpg")
        #expect(MetImageRendition.original.url(for: original) == original)

        let elsewhere = try #require(URL(string: "https://example.com/CRDImages/as/original/DP251139.jpg"))
        #expect(MetImageRendition.webLarge.url(for: elsewhere) == nil)
        #expect(MetImageRendition(of: elsewhere) == nil)

        let noFolder = try #require(URL(string: "https://images.metmuseum.org/DP251139.jpg"))
        #expect(MetImageRendition.webLarge.url(for: noFolder) == nil)
    }

    @Test func publicDomainFilter() throws {
        let painting = try Fixture.decode(MetObject.self, from: "object-436535")
        let coin = try Fixture.decode(MetObject.self, from: "object-restricted")

        #expect([coin, painting, coin].publicDomainWithImages().map(\.id) == [436535])
    }
}

@Suite("Search query")
struct QueryTests {
    private func pairs(_ query: MetSearchQuery) -> [String] {
        query.queryItems.map { $0.name + "=" + ($0.value ?? "") }
    }

    @Test func emptyQuerySendsNothing() {
        #expect(MetSearchQuery().queryItems.isEmpty)
        #expect(MetSearchQuery("   ").queryItems.isEmpty)
    }

    @Test func highlights() {
        #expect(pairs(.highlights(departmentID: 11)) == ["isHighlight=true", "departmentId=11", "hasImages=true"])
        #expect(pairs(.highlights()) == ["isHighlight=true", "hasImages=true"])
    }

    @Test func everyFilterWithTheTermLast() {
        let query = MetSearchQuery(
            "sunflowers",
            field: .title,
            isHighlight: false,
            hasImages: true,
            isOnView: true,
            departmentID: 11,
            medium: ["Paintings", " ", "Oil"],
            geoLocation: ["France", "Paris"],
            dates: 1850...1900
        )
        #expect(pairs(query) == [
            "isHighlight=false",
            "title=true",
            "departmentId=11",
            "isOnView=true",
            "medium=Paintings|Oil",
            "hasImages=true",
            "geoLocation=France|Paris",
            "dateBegin=1850",
            "dateEnd=1900",
            "q=sunflowers",
        ])
        #expect(query.dateBegin == 1850)
        #expect(query.dateEnd == 1900)
    }

    @Test func fields() {
        #expect(pairs(MetSearchQuery("Hokusai", field: .artistOrCulture)) == ["artistOrCulture=true", "q=Hokusai"])
        #expect(pairs(MetSearchQuery("cats", field: .tags)) == ["tags=true", "q=cats"])
        #expect(pairs(MetSearchQuery("cats", field: .anywhere)) == ["q=cats"])
    }

    @Test func yearsBeforeChrist() {
        let query = MetSearchQuery("amphora", dates: -700 ... -500)
        #expect(pairs(query) == ["dateBegin=-700", "dateEnd=-500", "q=amphora"])
    }

    @Test func pagePaging() {
        let middle = MetSearchPage(total: 125, objectIDs: Array(1...40), offset: 40, limit: 40)
        #expect(middle.nextOffset == 80)
        #expect(middle.hasMore)

        let last = MetSearchPage(total: 125, objectIDs: Array(1...5), offset: 120, limit: 40)
        #expect(last.nextOffset == nil)

        let capped = MetSearchPage(total: 50_000, objectIDs: Array(1...500), offset: 9_500, limit: 500)
        #expect(capped.nextOffset == nil)

        let empty = MetSearchPage(total: 0, objectIDs: [], offset: 0, limit: 100)
        #expect(empty.isEmpty)
        #expect(!empty.hasMore)
    }
}
