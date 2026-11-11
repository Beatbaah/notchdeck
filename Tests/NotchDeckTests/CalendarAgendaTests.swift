import XCTest
@testable import NotchDeck

final class CalendarAgendaTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Africa/Accra")!
        return c
    }()
    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }
    private func item(_ title: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarItem {
        CalendarItem(id: title, title: title, start: start, end: end, isAllDay: allDay, location: nil, colorHex: "#FF0000")
    }

    func testTodayAndTomorrowAllDayFirstEndedHidden() {
        let now = at(11, 10, 0)
        let items = [
            item("Lunch", at(11, 12), at(11, 13)),
            item("Standup", at(11, 9), at(11, 9, 15)),          // ended: hidden
            item("Holiday", at(11, 0), at(12, 0), allDay: true),
            item("Review", at(11, 9, 30), at(11, 10, 30)),      // ongoing: shown
            item("Dentist", at(12, 8), at(12, 9)),
            item("Next week", at(18, 8), at(18, 9)),            // beyond tomorrow: hidden
        ]
        let sections = CalendarAgenda.sections(items, now: now, calendar: cal)
        XCTAssertEqual(sections.map(\.title), ["Today", "Tomorrow"])
        XCTAssertEqual(sections[0].items.map(\.title), ["Holiday", "Review", "Lunch"])
        XCTAssertEqual(sections[1].items.map(\.title), ["Dentist"])
    }

    func testAnEmptyDayIsLeftOut() {
        let sections = CalendarAgenda.sections([item("Dentist", at(12, 8), at(12, 9))], now: at(11, 10), calendar: cal)
        XCTAssertEqual(sections.map(\.title), ["Tomorrow"])
    }

    func testNextEventIsTheOngoingOrNextTimedOneToday() {
        let now = at(11, 10, 0)
        let items = [
            item("Holiday", at(11, 0), at(12, 0), allDay: true),
            item("Lunch", at(11, 12), at(11, 13)),
            item("Review", at(11, 9, 30), at(11, 10, 30)),
            item("Dentist", at(12, 8), at(12, 9)),
        ]
        XCTAssertEqual(CalendarAgenda.next(items, now: now, calendar: cal)?.title, "Review")
        XCTAssertEqual(CalendarAgenda.next(items, now: at(11, 14), calendar: cal)?.title, nil) // nothing left today
    }
}
