import XCTest
@testable import NotchDeck

final class ShelfModelTests: XCTestCase {
    private var dir: URL!
    private var defaults: UserDefaults!
    private let suite = "notchdeck.tests.shelf"

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: dir)
    }

    private func file(_ name: String) -> URL {
        let url = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        return url
    }

    func testAFileRenamedAfterShelvingIsStillThereAfterARestart() throws {
        let original = file("report.pdf")
        ShelfModel(defaults: defaults).add(original)

        let renamed = dir.appendingPathComponent("report-final.pdf")
        try FileManager.default.moveItem(at: original, to: renamed)

        let reloaded = ShelfModel(defaults: defaults)
        XCTAssertEqual(reloaded.files.map(\.lastPathComponent), ["report-final.pdf"])
    }

    func testFilesShelvedByTheOldVersionStillLoad() {
        let old = file("notes.txt")
        defaults.set([old.path], forKey: "shelf.paths")
        XCTAssertEqual(ShelfModel(defaults: defaults).files.map(\.lastPathComponent), ["notes.txt"])
    }

    func testADeletedFileDropsOff() throws {
        let gone = file("gone.txt")
        let kept = file("kept.txt")
        let shelf = ShelfModel(defaults: defaults)
        shelf.add(gone)
        shelf.add(kept)
        try FileManager.default.removeItem(at: gone)
        XCTAssertEqual(ShelfModel(defaults: defaults).files.map(\.lastPathComponent), ["kept.txt"])
    }
}
