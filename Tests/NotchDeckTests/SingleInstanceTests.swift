import XCTest
@testable import NotchDeck

final class SingleInstanceTests: XCTestCase {
    func testAnotherCopyIsFoundButNotThisOne() {
        XCTAssertEqual(SingleInstance.otherCopy(runningPIDs: [100, 200], myPID: 200), 100)
        XCTAssertNil(SingleInstance.otherCopy(runningPIDs: [200], myPID: 200))
        XCTAssertNil(SingleInstance.otherCopy(runningPIDs: [], myPID: 200))
    }
}
