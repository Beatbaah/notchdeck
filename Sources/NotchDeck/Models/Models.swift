import Foundation

/// Every feature model, created once and shared with the views.
final class Models {
    let music = MusicController()
    let clipboard = ClipboardModel()
    let shelf = ShelfModel()
    let launcher = LauncherModel()
    let system = SystemModel()
    let calendar = CalendarModel()
}
