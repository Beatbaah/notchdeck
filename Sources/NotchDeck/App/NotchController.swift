import AppKit
import SwiftUI

/// A borderless panel that can take keyboard focus (for Notes) without activating the app.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Lets a click on a button work straight away, without first focusing the panel.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
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
    private var holdOpenUntil = Date.distantPast

    private var lastDragChangeCount = NSPasteboard(name: .drag).changeCount
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(timerFinished),
                                               name: .notchDeckTimerFinished,
                                               object: nil)

        // Polling the pointer 20 times a second is cheap, needs no Accessibility permission,
        // and keeps working while the user drags files from Finder.
        let timer = Timer(timeInterval: 0.05, target: self, selector: #selector(tick),
                          userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .default)
        pollTimer = timer
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
        guard let screen else { return }
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
            guard closedRect.contains(mouse) else { hoverSince = nil; return }
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
            if openRect.contains(mouse) || now < holdOpenUntil {
                outsideSince = nil
                return
            }
            let start = outsideSince ?? now
            outsideSince = start
            if now.timeIntervalSince(start) >= 0.3 {
                collapse()
            }
        }
    }

    /// Detects a file drag that started in another app (for example Finder).
    private func trackFileDrag() {
        let dragBoard = NSPasteboard(name: .drag)
        let buttonDown = (NSEvent.pressedMouseButtons & 1) != 0
        if buttonDown {
            if !fileDragActive, dragBoard.changeCount != lastDragChangeCount {
                fileDragActive = dragBoard.types?.contains(.fileURL) ?? false
                lastDragChangeCount = dragBoard.changeCount
            }
        } else {
            fileDragActive = false
            lastDragChangeCount = dragBoard.changeCount
        }
    }

    private func updateLiveActivity() {
        let activity: LiveActivity
        if models.timer.isActive {
            activity = .timer
        } else if models.music.isPlaying {
            activity = .music
        } else {
            activity = .none
        }
        if state.liveActivity != activity {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                state.liveActivity = activity
            }
        }
    }

    // MARK: Open / close

    func expand(tab: NotchTab? = nil, holdOpenFor seconds: TimeInterval = 0) {
        hoverSince = nil
        outsideSince = nil
        if seconds > 0 { holdOpenUntil = Date().addingTimeInterval(seconds) }
        if let tab { state.tab = tab }
        guard !state.isExpanded else { return }

        models.system.refresh()
        models.music.refresh()
        panel?.ignoresMouseEvents = false
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            state.isExpanded = true
        }
    }

    func collapse() {
        outsideSince = nil
        guard state.isExpanded, let panel else { return }

        // If Notes had keyboard focus, hand it back to the app the user was in.
        if panel.isKeyWindow {
            panel.makeFirstResponder(nil)
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        }
        panel.ignoresMouseEvents = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            state.isExpanded = false
        }
    }

    @objc private func timerFinished() {
        NSSound(named: "Glass")?.play()
        expand(tab: .home, holdOpenFor: 5)
    }
}
