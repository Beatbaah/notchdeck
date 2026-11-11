import AppKit

@main
@MainActor
enum NotchDeckMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // menu bar utility: no Dock icon
        app.run()
    }
}
