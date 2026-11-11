import Foundation

/// Sends a stream of values (a slider being dragged) without piling up work:
/// at most one send is in flight, and while it runs only the newest value
/// waits. When the slider stops, the last value is always the one applied.
/// Use from one thread (the main thread).
final class LatestValueSender<Value> {
    private let perform: (Value, @escaping () -> Void) -> Void
    private var busy = false
    private var waiting: Value?

    /// `perform` must call its completion when the send has finished.
    init(perform: @escaping (Value, @escaping () -> Void) -> Void) {
        self.perform = perform
    }

    func send(_ value: Value) {
        if busy {
            waiting = value
            return
        }
        busy = true
        perform(value) { [weak self] in self?.finished() }
    }

    private func finished() {
        busy = false
        if let next = waiting {
            waiting = nil
            send(next)
        }
    }
}
