import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController(models: Models())
        controller.start()
        self.controller = controller
        setUpStatusItem()
    }

    /// A small menu bar icon, so the app can always be opened or quit even if the notch is hidden.
    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                     accessibilityDescription: "NotchDeck")

        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Notch", action: #selector(openNotch), keyEquivalent: "")
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
        controller?.expand(tab: .home, holdOpenFor: 3)
    }
}
