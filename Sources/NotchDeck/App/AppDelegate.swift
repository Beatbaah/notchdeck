import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Already running: open that copy's panel and quit this one.
        if SingleInstance.handOverIfAlreadyRunning() {
            NSApp.terminate(nil)
            return
        }
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(openNotch),
                                                            name: SingleInstance.openNotification, object: nil)
        let controller = NotchController(models: Models())
        controller.start()
        self.controller = controller
        hotKey = HotKey { [weak controller] in controller?.toggle() }
        if hotKey?.isRegistered != true { NSLog("NotchDeck: \(HotKey.displayText) is taken by another app") }
        setUpStatusItem()
    }

    /// A small menu bar icon, so the app can always be opened or quit even if the notch is hidden.
    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                     accessibilityDescription: "NotchDeck")

        let menu = NSMenu()
        let open = NSMenuItem(title: hotKey?.isRegistered == true ? "Open Notch  \(HotKey.displayText)" : "Open Notch", action: #selector(openNotch), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchDeck",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func openNotch() {
        controller?.expand(tab: .home, pinned: true)
    }
}
