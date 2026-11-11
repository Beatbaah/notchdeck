import AppKit
import EventKit
import JavaScriptCore
import XCTest
@testable import NotchDeck

/// A quit player must never be relaunched by a script, and a stuck one must not hang the controls.
final class PlayerScriptGuardTests: XCTestCase {
    func testAGuardedScriptDoesNotLaunchAnAppThatIsClosed() throws {
        let candidates = [("TextEdit", "com.apple.TextEdit"), ("Stickies", "com.apple.Stickies"), ("Chess", "com.apple.Chess")]
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        guard let (name, id) = candidates.first(where: {
            !running.contains($0.1) && NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.1) != nil
        }) else { throw XCTSkip("No closed test app available") }

        // Compiling a script that names an app launches it, so the check must come first.
        AppleScript.run("tell application \"\(name)\" to count documents", ifRunning: id)

        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty, "\(name) was launched")
    }

    func testEveryPlayerScriptTimesOut() {
        for player in Player.allCases {
            let sample = NowPlaying(player: player, isPlaying: true, title: "t", artist: "", album: "", artworkURL: nil, ref: "1:1")
            let sources = [PlayerScripts.querySource(player)!, PlayerScripts.seek(to: 1, in: sample), PlayerScripts.artworkSource(player)]
                + [.playPause, .next, .previous].map { PlayerScripts.command($0, to: sample) }
            for source in sources.compactMap({ $0 }) {
                XCTAssertTrue(source.contains("with timeout of"), "\(player): \(source)")
            }
        }
    }
}

/// Volume and mute must answer even while a player script is stuck.
final class AppleScriptQueueTests: XCTestCase {
    func testSystemScriptsRunWhileThePlayerQueueIsBusy() {
        AppleScript.queue.async { Thread.sleep(forTimeInterval: 3) }
        let done = expectation(description: "volume script returned")
        AppleScript.runSystem("return 1") { _ in done.fulfill() }
        wait(for: [done], timeout: 1)
    }
}

/// The page script that finds the media in a browser tab.
final class BrowserMediaTests: XCTestCase {
    private func found(_ media: String) -> String? {
        let js = JSContext()!
        js.evaluateScript("var document={querySelectorAll:function(){return \(media);}};")
        let value = js.evaluateScript("(function(){" + PlayerScripts.jsFindMedia + "return e?e.id:null;})()")
        return value?.isNull == false ? value?.toString() : nil
    }

    func testAMutedAutoplayVideoIsNotMusic() {
        XCTAssertNil(found("[{id:'ad',currentSrc:'x',duration:30,paused:false,muted:true,volume:1}]"))
        XCTAssertNil(found("[{id:'ad',currentSrc:'x',duration:30,paused:false,muted:false,volume:0}]"))
    }

    func testAudibleMediaIsStillFound() {
        let media = "[{id:'ad',currentSrc:'x',duration:30,paused:false,muted:true,volume:1},"
            + "{id:'song',currentSrc:'y',duration:200,paused:false,muted:false,volume:0.8}]"
        XCTAssertEqual(found(media), "song")
    }
}

/// Granting calendar access in System Settings must show events without a relaunch.
final class CalendarAccessTests: XCTestCase {
    func testAccessGrantedInSettingsIsPickedUpOnReload() {
        var status = EKAuthorizationStatus.denied
        let model = CalendarModel(authorizationStatus: { status })
        XCTAssertEqual(model.access, .denied)

        if #available(macOS 14.0, *) { status = .fullAccess } else { status = .authorized }
        model.reload()

        XCTAssertEqual(model.access, .granted)
    }
}
