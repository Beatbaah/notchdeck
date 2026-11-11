import Foundation

/// Runs AppleScript on one serial background queue so the UI never waits on Music, Spotify or volume calls.
enum AppleScript {
    static let queue = DispatchQueue(label: "notchdeck.applescript", qos: .userInitiated)

    /// Synchronous. Call only from `queue`.
    @discardableResult
    static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        return error == nil ? result : nil
    }

    /// Runs on the background queue and calls `completion` on the main thread.
    static func runAsync(_ source: String, completion: ((NSAppleEventDescriptor?) -> Void)? = nil) {
        queue.async {
            let result = run(source)
            if let completion {
                DispatchQueue.main.async { completion(result) }
            }
        }
    }
}
