import AppKit

/// Runs AppleScript on background queues so the UI never waits on Music, Spotify or volume calls.
enum AppleScript {
    /// Player scripts, one at a time.
    static let queue = DispatchQueue(label: "notchdeck.applescript", qos: .userInitiated)
    /// Volume and mute, kept apart so a stuck player never holds them up.
    static let systemQueue = DispatchQueue(label: "notchdeck.applescript.system", qos: .userInitiated)

    /// Synchronous. Call only from `queue`.
    @discardableResult
    static func run(_ source: String) -> NSAppleEventDescriptor? {
        runReportingError(source).result
    }

    /// Also gives the error number on failure (-1743: the user hasn't allowed NotchDeck to control the app).
    static func runReportingError(_ source: String) -> (result: NSAppleEventDescriptor?, errorNumber: Int?) {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return (nil, nil) }
        let result = script.executeAndReturnError(&error)
        guard let error else { return (result, nil) }
        return (nil, error[NSAppleScript.errorNumber] as? Int ?? 0)
    }

    /// Runs only while the app is open. Synchronous; call only from `queue`.
    /// Checked here, not inside the script: merely compiling `tell application "X"` launches X,
    /// so a player quit since the last poll would otherwise come back.
    @discardableResult
    static func run(_ source: String, ifRunning bundleID: String) -> NSAppleEventDescriptor? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else { return nil }
        return run(source)
    }

    /// Volume and mute: runs on `systemQueue` and calls `completion` on the main thread.
    static func runSystem(_ source: String, completion: ((NSAppleEventDescriptor?) -> Void)? = nil) {
        runAsync(source, on: systemQueue, completion: completion)
    }

    /// Runs on a background queue (players' by default) and calls `completion` on the main thread.
    /// With `ifRunning`, the script is skipped when that app isn't open.
    static func runAsync(_ source: String, on queue: DispatchQueue = queue, ifRunning bundleID: String? = nil,
                         completion: ((NSAppleEventDescriptor?) -> Void)? = nil) {
        queue.async {
            let result = bundleID.map { run(source, ifRunning: $0) } ?? run(source)
            if let completion {
                DispatchQueue.main.async { completion(result) }
            }
        }
    }
}
