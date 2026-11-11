import SwiftUI

extension Color {
    init(hex: String) {
        let v = UInt64(hex.dropFirst(), radix: 16) ?? 0x8E8E93
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

enum EventTime {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    static func text(_ item: CalendarItem) -> String {
        if item.isAllDay { return "All day" }
        return "\(formatter.string(from: item.start)) – \(formatter.string(from: item.end))"
    }
}

struct CalendarView: View {
    @ObservedObject var calendar: CalendarModel

    var body: some View {
        Card {
            switch calendar.access {
            case .notAsked:
                prompt(icon: "calendar", text: "See today's and tomorrow's events here.",
                       button: "Show my calendar") { calendar.requestAccess() }
            case .denied:
                prompt(icon: "calendar.badge.exclamationmark", text: "NotchDeck can't read your calendar.",
                       button: "Allow in System Settings") { calendar.openPrivacySettings() }
            case .granted:
                agenda
            }
        }
        .onAppear { calendar.reload() }
    }

    @ViewBuilder private var agenda: some View {
        let sections = CalendarAgenda.sections(calendar.items, now: Date())
        if sections.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "calendar").font(.title2).foregroundStyle(Color.glassSecondary)
                Text("Nothing on today or tomorrow").font(.callout).foregroundStyle(Color.glassSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sections, id: \.title) { section in
                        Text(section.title).font(.caption).foregroundStyle(Color.glassSecondary)
                        ForEach(section.items) { item in
                            Button { calendar.openCalendarApp() } label: { EventRow(item: item) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func prompt(icon: String, text: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.glassSecondary)
            Text(text).font(.callout).foregroundStyle(Color.glassSecondary)
            Button(button, action: action).buttonStyle(PillButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EventRow: View {
    let item: CalendarItem

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: item.colorHex)).frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text([EventTime.text(item), item.location].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11)).foregroundStyle(Color.glassSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}
