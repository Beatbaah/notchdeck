import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable {
    case home, calendar, shelf, clipboard, notes, apps

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .calendar: return "calendar"
        case .shelf: return "tray.full.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .notes: return "note.text"
        case .apps: return "square.grid.2x2.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return "Home"
        case .calendar: return "Calendar"
        case .shelf: return "File Shelf"
        case .clipboard: return "Clipboard"
        case .notes: return "Notes"
        case .apps: return "Apps"
        }
    }
}

/// What the closed notch shows on its left and right edges.
enum LiveActivity: Equatable {
    case none, music
}

final class NotchState: ObservableObject {
    /// Width of the small outward curve where the shape meets the top edge of the screen.
    static let topRadius: CGFloat = 8

    @Published var isExpanded = false
    @Published var tab: NotchTab = .home
    @Published var notchSize = CGSize(width: 190, height: 32)
    @Published var hasNotch = false
    @Published var liveActivity: LiveActivity = .none
    /// The pointer is on the closed notch, just before it opens: the island swells.
    @Published var isHovering = false
    /// A new track, shown briefly below the closed notch (like a Dynamic Island alert).
    @Published var peek: Peek?

    struct Peek: Equatable {
        let title: String
        let artist: String
    }
    static let peekHeight: CGFloat = 40
    static let peekWidth: CGFloat = 320

    let expandedWidth: CGFloat = 640
    let contentHeight: CGFloat = 190

    var expandedSize: CGSize {
        CGSize(width: expandedWidth, height: notchSize.height + contentHeight)
    }

    /// Extra width added on each side of the closed notch for a live activity.
    var sideSlot: CGFloat {
        switch liveActivity {
        case .none: return 0
        case .music: return 34
        }
    }

    var collapsedSize: CGSize {
        let base = notchSize.width + 2 * NotchState.topRadius + 2 * sideSlot
        if peek != nil {
            return CGSize(width: max(base, NotchState.peekWidth), height: notchSize.height + NotchState.peekHeight)
        }
        let swell: CGFloat = isHovering ? 1 : 0
        return CGSize(width: base + 12 * swell, height: notchSize.height + 4 * swell)
    }

    /// Bottom corners: tight on the bare notch, rounder as the island grows.
    var collapsedCornerRadius: CGFloat { peek != nil ? 20 : 10 }
}

/// The island's motion: a lively, slightly bouncy open; a calmer close.
enum Island {
    static let open = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let close = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let swell = Animation.spring(response: 0.28, dampingFraction: 0.62)
}

/// When a track change pops out of the closed notch.
enum PeekPolicy {
    static func shouldPeek(oldTitle: String?, newTitle: String, playing: Bool, expanded: Bool) -> Bool {
        !expanded && playing && !newTitle.isEmpty && newTitle != oldTitle
    }
}
