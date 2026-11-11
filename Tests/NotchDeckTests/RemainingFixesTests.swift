import AppKit
import Carbon.HIToolbox
import XCTest
@testable import NotchDeck

/// Shelf files on a drive that isn't plugged in wait for it; deleted files leave.
final class ShelfDriveTests: XCTestCase {
    private let suite = "notchdeck.tests.shelfdrive"
    private var defaults: UserDefaults!
    private var image: URL!

    override func setUpWithError() throws {
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        image = FileManager.default.temporaryDirectory.appendingPathComponent("ndshelf-\(UUID().uuidString).dmg")
        try hdiutil(["create", "-size", "2m", "-fs", "HFS+", "-volname", "NDShelfTest", image.path])
    }

    override func tearDownWithError() throws {
        try? hdiutil(["detach", "/Volumes/NDShelfTest", "-force"])
        try? FileManager.default.removeItem(at: image)
        defaults.removePersistentDomain(forName: suite)
    }

    @discardableResult
    private func hdiutil(_ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        p.arguments = args + ["-quiet"]
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw XCTSkip("hdiutil \(args[0]) failed") }
        return p.terminationStatus
    }

    func testAFileOnADriveThatIsUnpluggedComesBackWithTheDrive() throws {
        try hdiutil(["attach", image.path, "-nobrowse"])
        let file = URL(fileURLWithPath: "/Volumes/NDShelfTest/song.mp3")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        ShelfModel(defaults: defaults).add(file)

        try hdiutil(["detach", "/Volumes/NDShelfTest"])
        XCTAssertEqual(ShelfModel(defaults: defaults).files, [], "an unplugged drive's file isn't shown")

        try hdiutil(["attach", image.path, "-nobrowse"])
        XCTAssertEqual(ShelfModel(defaults: defaults).files.map(\.lastPathComponent), ["song.mp3"])
    }

    func testAFileDeletedWhileRunningLeavesOnRefresh() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("gone.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8))
        let shelf = ShelfModel(defaults: defaults)
        shelf.add(file)
        try FileManager.default.removeItem(at: file)

        shelf.refresh()

        XCTAssertEqual(shelf.files, [])
        try? FileManager.default.removeItem(at: dir)
    }
}

/// Two copies started together: exactly one stays.
final class SingleInstanceTieTests: XCTestCase {
    func testTheEarliestLaunchStaysAndTheOtherYields() {
        let t = Date()
        let older = SingleInstance.Copy(pid: 300, launched: t)
        let newer = SingleInstance.Copy(pid: 200, launched: t.addingTimeInterval(1))
        XCTAssertFalse(SingleInstance.shouldYield(me: older, others: [newer]))
        XCTAssertTrue(SingleInstance.shouldYield(me: newer, others: [older]))
    }

    func testSameLaunchTimeLowerPIDStays() {
        let t = Date()
        let a = SingleInstance.Copy(pid: 100, launched: t)
        let b = SingleInstance.Copy(pid: 101, launched: t)
        XCTAssertFalse(SingleInstance.shouldYield(me: a, others: [b]))
        XCTAssertTrue(SingleInstance.shouldYield(me: b, others: [a]))
    }

    func testAloneNeverYields() {
        XCTAssertFalse(SingleInstance.shouldYield(me: .init(pid: 1, launched: Date()), others: []))
    }
}

/// HDMI and similar outputs have no volume; the slider mustn't show 0.
final class VolumeReadTests: XCTestCase {
    func testMissingValueIsNoVolume() {
        let missing = NSAppleEventDescriptor(typeCode: 0x6D73_6E67) // 'msng'
        XCTAssertNil(SystemModel.volume(from: missing))
        XCTAssertEqual(SystemModel.volume(from: NSAppleEventDescriptor(int32: 40)), 40)
    }
}

/// What the clipboard history keeps.
final class ClipboardFilterTests: XCTestCase {
    func testPasswordManagerSecretsAreSkipped() {
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        XCTAssertFalse(ClipboardModel.shouldKeep(text: "hunter2", types: [.string, concealed]))
        XCTAssertTrue(ClipboardModel.shouldKeep(text: "hello", types: [.string]))
        XCTAssertFalse(ClipboardModel.shouldKeep(text: "   \n", types: [.string]))
    }

    func testHugeCopiesAreNotKept() {
        let huge = String(repeating: "a", count: ClipboardModel.maxLength + 1)
        XCTAssertFalse(ClipboardModel.shouldKeep(text: huge, types: [.string]))
    }

    func testThePreviewIsShortAndOnOneLine() {
        let item = ClipItem(text: "first line\nsecond " + String(repeating: "x", count: 10_000))
        XCTAssertLessThanOrEqual(item.preview.count, ClipItem.previewLength)
        XCTAssertFalse(item.preview.contains("\n"))
        XCTAssertTrue(item.preview.hasPrefix("first line second"))
    }

    @available(macOS 15.4, *)
    func testABlockedClipboardIsReported() {
        XCTAssertTrue(ClipboardModel.isBlocked(.alwaysDeny))
        XCTAssertFalse(ClipboardModel.isBlocked(.alwaysAllow))
        XCTAssertFalse(ClipboardModel.isBlocked(.default))
    }
}

/// Moving past the notch shouldn't open it; resting on it should.
final class HoverPolicyTests: XCTestCase {
    func testBrushingPastDoesNotOpen() {
        XCTAssertFalse(HoverPolicy.shouldOpen(hoveringFor: 0.12, fileDrag: false))
        XCTAssertTrue(HoverPolicy.shouldOpen(hoveringFor: 0.2, fileDrag: false))
    }

    func testAFileDragOpensAtOnce() {
        XCTAssertTrue(HoverPolicy.shouldOpen(hoveringFor: 0, fileDrag: true))
    }
}

/// Browser commands go to the same tab even if windows are reordered.
final class BrowserTabTests: XCTestCase {
    func testCommandsAddressTheWindowByID() {
        for player in [Player.safari, .chrome] {
            let now = NowPlaying(player: player, isPlaying: true, title: "t", artist: "", album: "", artworkURL: nil, ref: "4242:3")
            let script = PlayerScripts.command(.playPause, to: now)
            XCTAssertTrue(script.contains("tab 3 of window id 4242"), script)
        }
    }

    func testTheQueryReportsTheWindowID() {
        XCTAssertTrue(PlayerScripts.querySource(.chrome)!.contains("(id of w)"))
    }
}

/// A shortcut another app already owns is reported, not advertised.
final class HotKeyTests: XCTestCase {
    func testASecondRegistrationOfTheSameKeysFails() {
        let keys = (UInt32(kVK_ANSI_J), UInt32(controlKey | optionKey | shiftKey | cmdKey))
        let first = HotKey(keyCode: keys.0, modifiers: keys.1) {}
        let second = HotKey(keyCode: keys.0, modifiers: keys.1) {}
        XCTAssertTrue(first.isRegistered)
        XCTAssertFalse(second.isRegistered)
    }
}

/// Without a notch, the closed pill hides while an app is full screen.
final class PillPolicyTests: XCTestCase {
    func testPillHidesOnlyWithoutANotchAndWithoutAMenuBar() {
        XCTAssertTrue(PillPolicy.showsClosedPill(hasNotch: false, menuBarVisible: true))
        XCTAssertFalse(PillPolicy.showsClosedPill(hasNotch: false, menuBarVisible: false))
        XCTAssertTrue(PillPolicy.showsClosedPill(hasNotch: true, menuBarVisible: false))
    }
}
