import XCTest
@testable import NotchDeck

/// Streamed Apple Music songs have no artwork over AppleScript, so the cover is looked up by title and artist.
final class ArtworkLookupTests: XCTestCase {
    func testSearchAsksForOneSongByArtistAndTitle() throws {
        let url = try XCTUnwrap(ArtworkLookup.searchURL(title: "Heaven Baby (feat. ZAYN)", artist: "Wizkid & Co"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "itunes.apple.com")
        XCTAssertEqual(items.first { $0.name == "term" }?.value, "Wizkid & Co Heaven Baby (feat. ZAYN)")
        XCTAssertEqual(items.first { $0.name == "entity" }?.value, "song")
        XCTAssertEqual(items.first { $0.name == "limit" }?.value, "1")
    }

    func testNoSearchWithoutATitle() {
        XCTAssertNil(ArtworkLookup.searchURL(title: "", artist: "Someone"))
    }

    func testCoverComesBackLargeFromTheFirstResult() {
        let json = #"{"resultCount":1,"results":[{"artworkUrl100":"https://is1-ssl.mzstatic.com/image/thumb/Music/ab/cd/100x100bb.jpg"}]}"#
        XCTAssertEqual(ArtworkLookup.artworkURL(fromResponse: Data(json.utf8))?.absoluteString,
                       "https://is1-ssl.mzstatic.com/image/thumb/Music/ab/cd/600x600bb.jpg")
    }

    func testNoResultsMeansNoCover() {
        XCTAssertNil(ArtworkLookup.artworkURL(fromResponse: Data(#"{"resultCount":0,"results":[]}"#.utf8)))
        XCTAssertNil(ArtworkLookup.artworkURL(fromResponse: Data("not json".utf8)))
    }

    func testOnlySecureCoverLinksAreUsed() {
        let json = #"{"results":[{"artworkUrl100":"http://example.com/100x100bb.jpg"}]}"#
        XCTAssertNil(ArtworkLookup.artworkURL(fromResponse: Data(json.utf8)))
    }
}
