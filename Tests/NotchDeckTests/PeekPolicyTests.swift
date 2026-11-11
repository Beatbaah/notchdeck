import XCTest
@testable import NotchDeck

final class PeekPolicyTests: XCTestCase {
    func testANewTrackPeeksOnlyWhileClosedAndPlaying() {
        XCTAssertTrue(PeekPolicy.shouldPeek(oldTitle: "Essence", newTitle: "Calm Down", playing: true, expanded: false))
        XCTAssertFalse(PeekPolicy.shouldPeek(oldTitle: "Essence", newTitle: "Calm Down", playing: true, expanded: true))   // already open
        XCTAssertFalse(PeekPolicy.shouldPeek(oldTitle: "Essence", newTitle: "Calm Down", playing: false, expanded: false)) // paused
    }

    func testTheSameTrackOrNothingDoesNotPeek() {
        XCTAssertFalse(PeekPolicy.shouldPeek(oldTitle: "Essence", newTitle: "Essence", playing: true, expanded: false))
        XCTAssertFalse(PeekPolicy.shouldPeek(oldTitle: "Essence", newTitle: "", playing: true, expanded: false))
    }

    func testTheFirstTrackAfterLaunchPeeksToo() {
        XCTAssertTrue(PeekPolicy.shouldPeek(oldTitle: nil, newTitle: "Essence", playing: true, expanded: false))
    }
}
