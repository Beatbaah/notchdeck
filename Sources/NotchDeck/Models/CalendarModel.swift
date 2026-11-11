import AppKit
import EventKit

/// One event, copied out of EventKit so views and tests don't touch the store.
struct CalendarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let colorHex: String
}

/// Today and tomorrow, as the Calendar tab shows them.
enum CalendarAgenda {
    struct Section: Equatable {
        let title: String
        let items: [CalendarItem]
    }

    /// Events not yet over, today then tomorrow; all-day events first, then by start time.
    static func sections(_ items: [CalendarItem], now: Date, calendar: Calendar = .current) -> [Section] {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let after = calendar.date(byAdding: .day, value: 2, to: today) else { return [] }
        func day(_ title: String, _ from: Date, _ to: Date) -> Section? {
            let list = items
                .filter { $0.end > now && $0.start < to && $0.end > from }
                .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
            return list.isEmpty ? nil : Section(title: title, items: list)
        }
        return [day("Today", today, tomorrow), day("Tomorrow", tomorrow, after)].compactMap { $0 }
    }

    /// The timed event happening now or next today, if any.
    static func next(_ items: [CalendarItem], now: Date, calendar: Calendar = .current) -> CalendarItem? {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
        return items
            .filter { !$0.isAllDay && $0.end > now && $0.start < tomorrow }
            .min { $0.start < $1.start }
    }
}

/// Reads today's and tomorrow's events. Asks for calendar access only when
/// the Calendar tab's button is pressed, never on launch.
final class CalendarModel: ObservableObject {
    enum Access { case notAsked, granted, denied }

    @Published private(set) var access: Access = .notAsked
    @Published private(set) var items: [CalendarItem] = []

    private let store = EKEventStore()
    private var timer: Timer?

    init() {
        access = Self.currentAccess()
        NotificationCenter.default.addObserver(self, selector: #selector(storeChanged), name: .EKEventStoreChanged, object: store)
        // Ended events drop off, and "today" rolls over at midnight.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.reload() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        reload()
    }

    private static func currentAccess() -> Access {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            switch status {
            case .fullAccess: return .granted
            case .notDetermined: return .notAsked
            default: return .denied
            }
        }
        switch status {
        case .authorized: return .granted
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    func requestAccess() {
        let done: (Bool, Error?) -> Void = { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.access = granted ? .granted : .denied
                self?.reload()
            }
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: done)
        } else {
            store.requestAccess(to: .event, completion: done)
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    @objc private func storeChanged() {
        DispatchQueue.main.async { self.reload() }
    }

    func reload() {
        guard access == .granted else { items = []; return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 2, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        items = store.events(matching: predicate).map { event in
            CalendarItem(id: event.eventIdentifier ?? UUID().uuidString,
                         title: event.title ?? "Untitled",
                         start: event.startDate,
                         end: event.endDate,
                         isAllDay: event.isAllDay,
                         location: event.location.flatMap { $0.isEmpty ? nil : $0 },
                         colorHex: event.calendar.map { Self.hex($0.color) } ?? "#8E8E93")
        }
    }

    private static func hex(_ color: NSColor) -> String {
        guard let c = color.usingColorSpace(.sRGB) else { return "#8E8E93" }
        return String(format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
