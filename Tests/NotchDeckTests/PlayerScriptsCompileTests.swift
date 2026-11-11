import AppKit
import XCTest
@testable import NotchDeck

/// Every script must compile against the real app's dictionary. Apps that
/// aren't installed are skipped (compiling for a missing app opens a dialog).
final class PlayerScriptsCompileTests: XCTestCase {
    func testQueryAndCommandScriptsCompileForInstalledPlayers() throws {
        var checked: [String] = []
        for player in Player.allCases where NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.bundleID) != nil {
            let sample = NowPlaying(player: player, isPlaying: true, title: "t", artist: "", album: "", artworkURL: nil, ref: "1:1")
            let sources = [PlayerScripts.querySource(player)!, PlayerScripts.seek(to: 42.5, in: sample)]
                + [.playPause, .next, .previous].map { PlayerScripts.command($0, to: sample) }
            for source in sources {
                var error: NSDictionary?
                let script = NSAppleScript(source: source)!
                XCTAssertTrue(script.compileAndReturnError(&error), "\(player): \(error ?? [:])\n\(source)")
            }
            checked.append(player.displayName)
        }
        print("Compiled scripts for: \(checked.joined(separator: ", "))")
    }
}
