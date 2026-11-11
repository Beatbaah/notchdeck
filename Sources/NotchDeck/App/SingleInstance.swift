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
        let pids = NSRunningApplication.runningApplications(withBundleIdentifier: id).map(\.processIdentifier)
        guard otherCopy(runningPIDs: pids, myPID: ProcessInfo.processInfo.processIdentifier) != nil else { return false }
        DistributedNotificationCenter.default().postNotificationName(openNotification, object: nil, userInfo: nil, deliverImmediately: true)
        return true
    }
}
