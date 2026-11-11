import SwiftUI
import AppKit

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    // Clear glass stays readable by dimming only where content sits.
                    .fill(Color.black.opacity(0.22))
            )
            .foregroundStyle(Color.white)
    }
}

/// Text colours on clear glass: brighter than the system's faint greys.
extension Color {
    static let glassSecondary = Color.white.opacity(0.75)
    static let glassTertiary = Color.white.opacity(0.6)
}

struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.28 : 0.16)))
            .contentShape(Capsule())
    }
}

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    var corner: CGFloat = 10

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(Color.glassSecondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// Four bouncing bars shown while music is playing.
struct EqualizerBars: View {
    let playing: Bool
    var color: Color = .green

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: playing ? 4 + 9 * abs(sin(t * 3.2 + Double(i) * 1.3)) : 3)
                }
            }
            .frame(height: 14)
        }
    }
}

struct TabButton: View {
    let tab: NotchTab
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.55))
                .frame(width: 28, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(selected ? 0.16 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The open panel's background: the system's clear Liquid Glass (macOS 26+),
/// untinted, so the window behind shows through. It still honours Reduce
/// Transparency.
/// Older macOS gets the frosted material macOS used before.
struct GlassBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 24

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .clear
            glass.cornerRadius = cornerRadius
            return glass
        }
        let view = NSVisualEffectView()
        view.appearance = NSAppearance(named: .darkAqua)
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
