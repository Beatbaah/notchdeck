import XCTest
@testable import NotchDeck

final class LatestValueSenderTests: XCTestCase {
    /// A slider drag fires dozens of values; only one command may be in flight,
    /// and the last value dragged to must be the one that lands.
    func testSendsOneAtATimeAndEndsOnTheLatestValue() {
        var sent: [Int] = []
        var finish: (() -> Void)?
        let sender = LatestValueSender<Int> { value, done in
            sent.append(value)
            finish = done
        }

        sender.send(10)       // goes out at once
        sender.send(20)       // waiting
        sender.send(30)       // replaces 20
        sender.send(40)       // replaces 30
        XCTAssertEqual(sent, [10])

        finish?()             // 10 done -> the latest waiting value goes
        XCTAssertEqual(sent, [10, 40])

        finish?()             // nothing waiting
        XCTAssertEqual(sent, [10, 40])

        sender.send(50)       // idle again -> immediate
        XCTAssertEqual(sent, [10, 40, 50])
    }
}
