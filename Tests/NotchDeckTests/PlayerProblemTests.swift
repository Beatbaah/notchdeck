import XCTest
@testable import NotchDeck

/// A player NotchDeck isn't allowed to read must say so, not show "Nothing playing" forever.
final class PlayerProblemTests: XCTestCase {
    private let song = NowPlaying(player: .music, isPlaying: true, title: "Song", artist: "", album: "", artworkURL: nil, ref: nil)

    func testAutomationDeniedIsReported() {
        XCTAssertEqual(PlayerScripts.outcome(output: nil, errorNumber: -1743, player: .spotify),
                       .problem(.automationDenied(.spotify)))
    }

    func testBrowserWithJavaScriptOffIsReported() {
        XCTAssertEqual(PlayerScripts.outcome(output: PlayerScripts.javaScriptOffReply, errorNumber: nil, player: .chrome),
                       .problem(.javaScriptOff(.chrome)))
    }

    func testOtherFailuresAndSilenceAreJustNothing() {
        XCTAssertEqual(PlayerScripts.outcome(output: nil, errorNumber: -1728, player: .music), .nothing)
        XCTAssertEqual(PlayerScripts.outcome(output: "stopped", errorNumber: nil, player: .music), .nothing)
        XCTAssertEqual(PlayerScripts.outcome(output: "", errorNumber: nil, player: .safari), .nothing)
    }

    func testAReplyIsParsedAsBefore() {
        XCTAssertEqual(PlayerScripts.outcome(output: "playing|~|Song|~||~|", errorNumber: nil, player: .music), .playing(song))
    }

    func testMusicWinsOverAProblemElsewhere() {
        let picked = NowPlaying.pick(outcomes: [.problem(.automationDenied(.spotify)), .playing(song)])
        XCTAssertEqual(picked.now, song)
        XCTAssertNil(picked.problem)
    }

    func testWithNothingPlayingTheProblemShows() {
        let picked = NowPlaying.pick(outcomes: [.nothing, .problem(.javaScriptOff(.safari))])
        XCTAssertNil(picked.now)
        XCTAssertEqual(picked.problem, .javaScriptOff(.safari))
    }

    func testMessagesTellTheUserWhatToTurnOn() {
        XCTAssertTrue(PlayerProblem.automationDenied(.spotify).message.contains("Spotify"))
        XCTAssertTrue(PlayerProblem.automationDenied(.spotify).message.contains("Automation"))
        XCTAssertTrue(PlayerProblem.javaScriptOff(.chrome).message.contains("Allow JavaScript from Apple Events"))
        XCTAssertNotNil(PlayerProblem.automationDenied(.music).settingsURL)
    }
}
