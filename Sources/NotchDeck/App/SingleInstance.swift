import AppKit

/// Only one NotchDeck at a time: opening it again opens the running copy's
/// panel instead of starting a second one (two copies fight over the notch).
enum SingleInstance {
    static let openNotification = Notification.Name("local.notchdeck.openNotch")

    static func otherCopy(runningPIDs: [pid_t], myPID: pid_t) -> pid_t? {
        runningPIDs.first { $0 != myPID }
    }

    /// True when another copy is running; that copy is asked to open its panel.
    static func handOverIfAlreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let copies = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .map { Copy(pid: $0.processIdentifier, launched: $0.launchDate ?? .distantFuture) }
        guard let me = copies.first(where: { $0.pid == myPID }),
              shouldYield(me: me, others: copies.filter { $0.pid != myPID }) else { return false }
        DistributedNotificationCenter.default().postNotificationName(openNotification, object: nil, userInfo: nil, deliverImmediately: true)
        return true
    }
}

extension SingleInstance {
    struct Copy { let pid: pid_t; let launched: Date }

    /// The copy launched first stays (lowest PID on a tie), so two copies started at the
    /// same moment (login item plus a manual open) never both quit.
    static func shouldYield(me: Copy, others: [Copy]) -> Bool {
        others.contains { $0.launched < me.launched || ($0.launched == me.launched && $0.pid < me.pid) }
    }
}
