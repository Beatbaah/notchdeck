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
        CGSize(width: notchSize.width + 2 * NotchState.topRadius + 2 * sideSlot,
               height: notchSize.height)
    }
}
