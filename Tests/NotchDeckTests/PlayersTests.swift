import XCTest
@testable import NotchDeck

final class PlayersTests: XCTestCase {
    func testDelimitedReplyFromAScriptablePlayer() {
        let s = NowPlaying.parse("playing|~|Essence|~|Wizkid|~|Made in Lagos|~|https://i.scdn.co/x.jpg", player: .spotify)
        XCTAssertEqual(s?.title, "Essence")
        XCTAssertEqual(s?.artist, "Wizkid")
        XCTAssertEqual(s?.isPlaying, true)
        XCTAssertEqual(s?.artworkURL, "https://i.scdn.co/x.jpg")
        XCTAssertNil(NowPlaying.parse("stopped", player: .music))
        XCTAssertNil(NowPlaying.parse("garbage", player: .vlc))
    }

    func testBrowserReplyUsesMediaSessionMetadata() {
        let json = #"{"playing":true,"title":"Calm Down","artist":"Rema","artwork":"https://i.ytimg.com/a.jpg","ref":"2:5"}"#
        let s = NowPlaying.parseBrowser(json, player: .chrome)
        XCTAssertEqual(s?.title, "Calm Down")
        XCTAssertEqual(s?.artist, "Rema")
        XCTAssertEqual(s?.isPlaying, true)
        XCTAssertEqual(s?.ref, "2:5")
        XCTAssertEqual(s?.player.displayName, "Chrome")
        XCTAssertNil(NowPlaying.parseBrowser("", player: .safari))
        XCTAssertNil(NowPlaying.parseBrowser("missing value", player: .safari))
    }

    func testAPlayingSourceWinsThenTheFirstInOrder() {
        let paused = NowPlaying(player: .music, isPlaying: false, title: "A", artist: "", album: "", artworkURL: nil, ref: nil)
        let playing = NowPlaying(player: .safari, isPlaying: true, title: "B", artist: "", album: "", artworkURL: nil, ref: nil)
        XCTAssertEqual(NowPlaying.pick([paused, playing])?.title, "B")
        XCTAssertEqual(NowPlaying.pick([paused])?.title, "A")
        XCTAssertNil(NowPlaying.pick([]))
    }

    func testOnlyRunningPlayersAreAskedAndBrowsersOnlyWhenSwitchedOn() {
        let running: Set<String> = ["com.apple.Music", "com.google.Chrome", "org.videolan.vlc"]
        XCTAssertEqual(Player.toQuery(running: running, browsersOn: false), [.music, .vlc])
        XCTAssertEqual(Player.toQuery(running: running, browsersOn: true), [.music, .vlc, .chrome])
    }
}
