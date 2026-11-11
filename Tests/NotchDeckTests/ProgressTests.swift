import XCTest
@testable import NotchDeck

final class ProgressTests: XCTestCase {
    func testScriptablePlayersReportPositionAndLength() {
        let m = NowPlaying.parse("playing|~|Ebeye Yie|~|MC Abraham|~|Vol 3|~||~|102.5|~|210", player: .music)
        XCTAssertEqual(m?.position, 102.5)
        XCTAssertEqual(m?.duration, 210)
        XCTAssertNil(m?.artworkURL)
        // Older shape (no timing) still parses, without a bar.
        let s = NowPlaying.parse("paused|~|Essence|~|Wizkid|~|Made in Lagos|~|https://i.scdn.co/x.jpg", player: .spotify)
        XCTAssertEqual(s?.artworkURL, "https://i.scdn.co/x.jpg")
        XCTAssertNil(s?.duration)
    }

    func testSpotifyLengthArrivesInMillisecondsAndIsConverted() {
        let s = NowPlaying.parse("playing|~|Essence|~|Wizkid|~|Made in Lagos|~|https://a|~|30|~|248000", player: .spotify)
        XCTAssertEqual(s?.duration, 248)
    }

    func testBrowsersReportPositionAndLength() {
        let b = NowPlaying.parseBrowser(#"{"playing":true,"title":"Calm Down","artist":"Rema","position":61.2,"duration":239.9,"ref":"1:2"}"#, player: .safari)
        XCTAssertEqual(b?.position, 61.2)
        XCTAssertEqual(b?.duration, 239.9)
        // Live streams have no fixed length: no bar.
        let live = NowPlaying.parseBrowser(#"{"playing":true,"title":"Live","position":5,"duration":null}"#, player: .chrome)
        XCTAssertNil(live?.duration)
    }

    func testTimesReadLikeAPlayer() {
        XCTAssertEqual(TrackTime.text(0), "0:00")
        XCTAssertEqual(TrackTime.text(102.9), "1:42")
        XCTAssertEqual(TrackTime.text(3725), "1:02:05")
    }

    func testThePositionKeepsMovingBetweenChecksOnlyWhilePlaying() {
        let t0 = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(TrackTime.live(position: 10, duration: 200, playing: true, since: t0, now: t0.addingTimeInterval(1.5)), 11.5)
        XCTAssertEqual(TrackTime.live(position: 10, duration: 200, playing: false, since: t0, now: t0.addingTimeInterval(1.5)), 10)
        XCTAssertEqual(TrackTime.live(position: 199, duration: 200, playing: true, since: t0, now: t0.addingTimeInterval(5)), 200)
    }
}
