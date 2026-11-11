import AppKit
import SwiftUI

/// A borderless panel that can take keyboard focus (for Notes) without activating the app.
final class NotchPanel: NSPanel {
    /// Esc.
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
    override var canBecomeMain: Bool { false }
}

/// Lets a click on a button work straight away, without first focusing the panel.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Detects a file drag that started in another app (for example Finder): the drag
/// pasteboard changes while the button is down. It's read only around clicks, not every tick.
struct DragWatch {
    private var lastChangeCount: Int?
    private var wasDown = false
    private(set) var active = false

    mutating func update(buttonDown: Bool, changeCount: () -> Int, hasFiles: () -> Bool) -> Bool {
        if buttonDown {
            wasDown = true
            if !active, let last = lastChangeCount {
                let count = changeCount()
                if count != last {
                    active = hasFiles()
                    lastChangeCount = count
                }
            }
        } else {
            // A fresh baseline after each release (and once at start).
            if wasDown || lastChangeCount == nil { lastChangeCount = changeCount() }
            wasDown = false
            active = false
        }
        return active
    }
}

/// Owns the panel that sits over the notch, and opens or closes it as the pointer moves.
@MainActor
final class NotchController: NSObject {
    let state = NotchState()
    let models: Models

    private var panel: NotchPanel?
    private var pollTimer: Timer?
    private weak var screen: NSScreen?

    private var hoverSince: Date?
    private var outsideSince: Date?
    /// Opened by the shortcut or menu: stays until dismissed (see `ClosePolicy`).
    private var pinned = false
    private var pointerHasEntered = false
    private var screenAwake = true

    private var lastTitle: String?
    private var peekHide: DispatchWorkItem?

    private var dragWatch = DragWatch()
    private var fileDragActive = false

    init(models: Models) {
        self.models = models
        super.init()
    }

    func start() {
        buildPanel()
        layout()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)

        // Nothing to watch while the display sleeps or another user is switched in.
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            ws.addObserver(self, selector: #selector(screenAsleep), name: name, object: nil)
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(self, selector: #selector(screenAwoke), name: name, object: nil)
        }

        // It may launch (at login, say) with the display already off.
        if CGDisplayIsAsleep(CGMainDisplayID()) != 0 {
            screenAsleep()
        } else {
            startPolling()
        }
    }

    /// Polling the pointer 20 times a second is cheap, needs no Accessibility permission,
    /// and keeps working while the user drags files from Finder. The tolerance lets
    /// macOS batch its wake-ups with other timers.
    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: 0.05, target: self, selector: #selector(tick),
                          userInfo: nil, repeats: true)
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .default)
        pollTimer = timer
    }

    @objc private func screenAsleep() {
        screenAwake = false
        models.music.screenAwake = false
        collapse()
        pollTimer?.invalidate()
        pollTimer = nil
        // Park the closed notch's animated bars; the first tick after waking brings them back.
        peekHide?.cancel()
        state.peek = nil
        state.liveActivity = .none
    }

    @objc private func screenAwoke() {
        screenAwake = true
        models.music.screenAwake = true
        models.music.refresh()
        startPolling()
    }

    // MARK: Panel

    private func buildPanel() {
        let panel = NotchPanel(contentRect: .zero,
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered,
                               defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true
        panel.onCancel = { [weak self] in self?.collapse() }

        let host = FirstMouseHostingView(rootView: NotchRootView(state: state, models: models))
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel
    }

    @objc private func screensChanged() {
        layout()
    }

    /// Finds the screen with a notch (or the main screen) and places the panel at its top centre.
    private func layout() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
                ?? NSScreen.main ?? NSScreen.screens.first else { return }
        self.screen = screen

        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            state.hasNotch = true
            state.notchSize = CGSize(width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
        } else {
            // No notch: draw a pill of similar size in the middle of the menu bar.
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            state.hasNotch = false
            state.notchSize = CGSize(width: 190, height: menuBar > 0 ? menuBar : 24)
        }

        let size = state.expandedSize
        let frame = NSRect(x: screen.frame.midX - size.width / 2,
                           y: screen.frame.maxY - size.height,
                           width: size.width,
                           height: size.height)
        panel?.setFrame(frame, display: true)
    }

    // MARK: Hover tracking

    @objc private func tick() {
        guard let screen, screenAwake else { return }
        updateLiveActivity()
        trackFileDrag()

        let mouse = NSEvent.mouseLocation
        let now = Date()
        let top = screen.frame.maxY

        let closed = state.collapsedSize
        let closedRect = NSRect(x: screen.frame.midX - closed.width / 2, y: top - closed.height,
                                width: closed.width, height: closed.height)
            .insetBy(dx: -6, dy: -4)

        let open = state.expandedSize
        let openRect = NSRect(x: screen.frame.midX - open.width / 2, y: top - open.height,
                              width: open.width, height: open.height)
            .insetBy(dx: -8, dy: -8)

        if !state.isExpanded {
            let over = closedRect.contains(mouse)
            if over != state.isHovering {
                withAnimation(Island.swell) { state.isHovering = over }
            }
            guard over else { hoverSince = nil; return }
            let start = hoverSince ?? now
            hoverSince = start
            let delay: TimeInterval = fileDragActive ? 0 : 0.12
            if now.timeIntervalSince(start) >= delay {
                expand(tab: fileDragActive ? .shelf : nil)
            }
        } else {
            if fileDragActive, openRect.contains(mouse), state.tab != .shelf {
                state.tab = .shelf
            }
            if openRect.contains(mouse) {
                pointerHasEntered = true
                outsideSince = nil
                return
            }
            let start = outsideSince ?? now
            outsideSince = start
            if ClosePolicy.shouldClose(pinned: pinned, pointerInside: false, pointerHasEntered: pointerHasEntered,
                                       outsideFor: now.timeIntervalSince(start)) {
                collapse()
            }
        }
    }

    /// Detects a file drag that started in another app (for example Finder).
    private func trackFileDrag() {
        fileDragActive = dragWatch.update(buttonDown: (NSEvent.pressedMouseButtons & 1) != 0,
                                          changeCount: { NSPasteboard(name: .drag).changeCount },
                                          hasFiles: { NSPasteboard(name: .drag).types?.contains(.fileURL) ?? false })
    }

    private func updateLiveActivity() {
        let activity: LiveActivity = models.music.isPlaying ? .music : .none
        let title = models.music.title
        if title != lastTitle {
            if PeekPolicy.shouldPeek(oldTitle: lastTitle, newTitle: title, playing: models.music.isPlaying, expanded: state.isExpanded) {
                showPeek(title: title, artist: models.music.artist)
            }
            lastTitle = title
        }
        if state.liveActivity != activity {
            withAnimation(Island.open) {
                state.liveActivity = activity
            }
        }
    }

    /// A new track pops out of the closed notch for a few seconds.
    private func showPeek(title: String, artist: String) {
        peekHide?.cancel()
        withAnimation(Island.open) { state.peek = NotchState.Peek(title: title, artist: artist) }
        let hide = DispatchWorkItem { [weak self] in
            withAnimation(Island.close) { self?.state.peek = nil }
        }
        peekHide = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: hide)
    }

    // MARK: Open / close

    /// `pinned`: opened from the keyboard or menu, so it stays open and takes keyboard focus
    /// (for Esc) until the user dismisses it.
    func expand(tab: NotchTab? = nil, pinned: Bool = false) {
        hoverSince = nil
        outsideSince = nil
        if pinned {
            self.pinned = true
            pointerHasEntered = false
            panel?.makeKey()
        }
        if let tab { state.tab = tab }
        guard !state.isExpanded else { return }

        models.system.refresh()
        models.music.panelOpen = true
        models.music.refresh()
        panel?.ignoresMouseEvents = false
        peekHide?.cancel()
        withAnimation(Island.open) {
            state.isHovering = false
            state.peek = nil
            state.isExpanded = true
        }
    }

    /// The keyboard shortcut: open (and stay open until dismissed), or close.
    func toggle() {
        if state.isExpanded { collapse() } else { expand(pinned: true) }
    }

    func collapse() {
        outsideSince = nil
        pinned = false
        pointerHasEntered = false
        models.music.panelOpen = false
        guard state.isExpanded, let panel else { return }

        // If Notes had keyboard focus, hand it back to the app the user was in.
        if panel.isKeyWindow {
            panel.makeFirstResponder(nil)
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
        panel.ignoresMouseEvents = true
        withAnimation(Island.close) {
            state.isExpanded = false
        }
    }
}
