import Foundation

extension Notification.Name {
    static let notchDeckTimerFinished = Notification.Name("NotchDeckTimerFinished")
}

/// A single countdown timer. Posts `.notchDeckTimerFinished` when it reaches zero.
final class TimerModel: ObservableObject {
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0
    @Published private(set) var isRunning = false
    @Published private(set) var isActive = false

    private var endDate: Date?
    private var ticker: Timer?

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    var remainingText: String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func start(minutes: Double) {
        total = minutes * 60
        remaining = total
        endDate = Date().addingTimeInterval(total)
        isRunning = true
        isActive = true
        startTicker()
    }

    func toggle() {
        guard isActive else { return }
        if isRunning {
            remaining = max(0, endDate?.timeIntervalSinceNow ?? remaining)
            endDate = nil
            isRunning = false
            ticker?.invalidate()
            ticker = nil
        } else {
            endDate = Date().addingTimeInterval(remaining)
            isRunning = true
            startTicker()
        }
    }

    func cancel() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isRunning = false
        isActive = false
        remaining = 0
        total = 0
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            cancel()
            NotificationCenter.default.post(name: .notchDeckTimerFinished, object: self)
        }
    }
}
