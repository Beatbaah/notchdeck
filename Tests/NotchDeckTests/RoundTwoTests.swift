import AppKit
import SwiftUI
import XCTest
@testable import NotchDeck

/// Opened by the shortcut or menu, the panel waits for the user instead of closing on a timer.
final class ClosePolicyTests: XCTestCase {
    func testHoverOpenedPanelClosesShortlyAfterThePointerLeaves() {
        XCTAssertFalse(ClosePolicy.shouldClose(pinned: false, pointerInside: true, pointerHasEntered: true, outsideFor: 0))
        XCTAssertFalse(ClosePolicy.shouldClose(pinned: false, pointerInside: false, pointerHasEntered: true, outsideFor: 0.1))
        XCTAssertTrue(ClosePolicy.shouldClose(pinned: false, pointerInside: false, pointerHasEntered: true, outsideFor: 0.3))
    }

    func testShortcutOpenedPanelStaysOpenWhileThePointerIsElsewhere() {
        XCTAssertFalse(ClosePolicy.shouldClose(pinned: true, pointerInside: false, pointerHasEntered: false, outsideFor: 60))
    }

    func testShortcutOpenedPanelClosesOnceThePointerHasVisitedAndLeft() {
        XCTAssertTrue(ClosePolicy.shouldClose(pinned: true, pointerInside: false, pointerHasEntered: true, outsideFor: 0.3))
    }
}

/// Esc closes the panel when it has keyboard focus.
@MainActor
final class NotchPanelEscapeTests: XCTestCase {
    func testEscapeCallsOnCancel() {
        let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        var cancelled = false
        panel.onCancel = { cancelled = true }
        panel.cancelOperation(nil)
        XCTAssertTrue(cancelled)
    }
}

/// Reduce Motion swaps the bouncy springs for plain fades.
final class ReduceMotionTests: XCTestCase {
    override func tearDown() { Island.reduceMotion = { false } }

    func testSpringsBecomeFadesWithReduceMotion() {
        Island.reduceMotion = { false }
        XCTAssertNotEqual(Island.open, Island.fade)
        Island.reduceMotion = { true }
        XCTAssertEqual(Island.open, Island.fade)
        XCTAssertEqual(Island.close, Island.fade)
        XCTAssertEqual(Island.swell, Island.fade)
    }

    func testEqualizerStaysStillWithReduceMotion() {
        XCTAssertTrue(EqualizerBars.animates(playing: true, reduceMotion: false))
        XCTAssertFalse(EqualizerBars.animates(playing: true, reduceMotion: true))
        XCTAssertFalse(EqualizerBars.animates(playing: false, reduceMotion: false))
    }
}

/// Players are asked less often while nobody is looking.
final class PollPolicyTests: XCTestCase {
    func testOpenPanelPollsEveryTick() {
        XCTAssertTrue(PollPolicy.shouldPollPlayers(panelOpen: true, screenAwake: true, sinceLast: 1.5))
    }

    func testClosedPanelPollsEveryFiveSeconds() {
        XCTAssertFalse(PollPolicy.shouldPollPlayers(panelOpen: false, screenAwake: true, sinceLast: 3))
        XCTAssertTrue(PollPolicy.shouldPollPlayers(panelOpen: false, screenAwake: true, sinceLast: 5))
    }

    func testNothingPollsWhileTheScreenSleeps() {
        XCTAssertFalse(PollPolicy.shouldPollPlayers(panelOpen: true, screenAwake: false, sinceLast: 60))
    }
}

/// The drag pasteboard is only read around clicks, not 20 times a second.
final class DragWatchTests: XCTestCase {
    func testIdleTicksDoNotReadTheDragPasteboard() {
        var watch = DragWatch()
        var reads = 0
        for _ in 0..<100 {
            _ = watch.update(buttonDown: false, changeCount: { reads += 1; return 7 }, hasFiles: { false })
        }
        XCTAssertLessThanOrEqual(reads, 1)
    }

    func testAFileDragFromAnotherAppIsSeen() {
        var watch = DragWatch()
        var count = 7
        XCTAssertFalse(watch.update(buttonDown: false, changeCount: { count }, hasFiles: { false }))
        XCTAssertFalse(watch.update(buttonDown: true, changeCount: { count }, hasFiles: { true }))
        count = 8 // Finder writes the dragged file
        XCTAssertTrue(watch.update(buttonDown: true, changeCount: { count }, hasFiles: { true }))
        XCTAssertFalse(watch.update(buttonDown: false, changeCount: { count }, hasFiles: { true }))
    }

    func testAPlainClickIsNotADrag() {
        var watch = DragWatch()
        XCTAssertFalse(watch.update(buttonDown: false, changeCount: { 3 }, hasFiles: { true }))
        XCTAssertFalse(watch.update(buttonDown: true, changeCount: { 3 }, hasFiles: { true }))
    }
}
