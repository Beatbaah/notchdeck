import SwiftUI

struct NotchRootView: View {
    @ObservedObject var state: NotchState
    let models: Models

    var body: some View {
        let size = state.isExpanded ? state.expandedSize : state.collapsedSize
        let shape = NotchShape(topRadius: NotchState.topRadius,
                               bottomRadius: state.isExpanded ? 24 : state.collapsedCornerRadius)

        ZStack(alignment: .top) {
            // Black like the Dynamic Island; the clear glass fades in only as the
            // island grows into the open panel (and out as it shrinks back).
            Color.black
                .opacity(state.isExpanded ? 0 : 1) // the glass replaces it, never sits on it
            GlassBackground()
                .opacity(state.isExpanded ? 1 : 0)
            // The strip beside the physical notch stays black, fading into the glass.
            LinearGradient(stops: [.init(color: .black, location: 0),
                                   .init(color: .black, location: stripFraction),
                                   .init(color: .black.opacity(0), location: min(1, stripFraction + 0.09))],
                           startPoint: .top, endPoint: .bottom)
                .opacity(state.isExpanded ? 1 : 0)

            if state.isExpanded {
                ExpandedView(state: state, models: models)
                    .frame(width: state.expandedSize.width, height: state.expandedSize.height)
                    // Clear glass over a bright window: a soft shadow keeps white text readable.
                    .shadow(color: .black.opacity(0.45), radius: 1.5, x: 0, y: 0.5)
                    // Content arrives a beat after the shape, sharpening into place.
                    .transition(.asymmetric(
                        insertion: .modifier(active: IslandArrival(progress: 0), identity: IslandArrival(progress: 1))
                            .animation(Island.open.delay(0.07)),
                        removal: .opacity.animation(.easeOut(duration: 0.1))))
            } else {
                CollapsedView(state: state, music: models.music)
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .environment(\.colorScheme, .dark)
                    .transition(.asymmetric(insertion: .opacity.animation(.easeIn(duration: 0.15).delay(0.12)),
                                            removal: .opacity.animation(.easeOut(duration: 0.08))))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // White text and icons in either system appearance, like the Dynamic Island.
        .environment(\.colorScheme, .dark)
    }

    /// The menu bar strip's share of the open panel's height.
    private var stripFraction: CGFloat {
        state.notchSize.height / max(1, state.expandedSize.height)
    }
}

/// Content settling in as the island opens: from a little small, faint and soft to sharp.
struct IslandArrival: ViewModifier {
    let progress: CGFloat
    func body(content: Content) -> some View {
        content
            .scaleEffect(0.9 + 0.1 * progress, anchor: .top)
            .opacity(progress)
            .blur(radius: 6 * (1 - progress))
    }
}

/// The closed notch: bare, with a live activity on its sides, or popping out a new track.
struct CollapsedView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var music: MusicController

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                leading.frame(width: state.sideSlot)
                Spacer(minLength: 0)
                trailing.frame(width: state.sideSlot)
            }
            .padding(.horizontal, NotchState.topRadius + (state.peek != nil ? 10 : 0))
            .frame(height: state.notchSize.height)

            if let peek = state.peek {
                HStack(spacing: 10) {
                    ArtworkView(image: music.artwork, size: 26, corner: 6)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(peek.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        if !peek.artist.isEmpty {
                            Text(peek.artist).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    EqualizerBars(playing: music.isPlaying)
                }
                .padding(.horizontal, 18)
                .frame(height: NotchState.peekHeight - 6)
                .transition(.modifier(active: IslandArrival(progress: 0), identity: IslandArrival(progress: 1))
                    .animation(Island.open.delay(0.08)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Now playing: \(peek.title)\(peek.artist.isEmpty ? "" : " by \(peek.artist)")")
            }
        }
    }

    @ViewBuilder private var leading: some View {
        switch state.liveActivity {
        case .music where state.peek == nil:
            ArtworkView(image: music.artwork, size: max(14, state.notchSize.height - 12), corner: 5)
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var trailing: some View {
        switch state.liveActivity {
        case .music where state.peek == nil:
            EqualizerBars(playing: music.isPlaying)
        default:
            EmptyView()
        }
    }
}

struct ExpandedView: View {
    @ObservedObject var state: NotchState
    let models: Models

    var body: some View {
        VStack(spacing: 10) {
            // This row sits in the menu bar strip, on either side of the physical notch.
            HStack(spacing: 4) {
                ForEach(NotchTab.allCases) { tab in
                    TabButton(tab: tab, selected: state.tab == tab) { state.tab = tab }
                }
                Spacer(minLength: state.notchSize.width + 12)
                BatteryBadge(system: models.system)
                SettingsMenu()
            }
            .frame(height: state.notchSize.height)
            .environment(\.colorScheme, .dark) // the tab row sits in the black strip

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, NotchState.topRadius + 14)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var content: some View {
        switch state.tab {
        case .home: HomeView(models: models)
        case .calendar: CalendarView(calendar: models.calendar)
        case .shelf: ShelfView(shelf: models.shelf)
        case .clipboard: ClipboardView(clipboard: models.clipboard)
        case .notes: NotesView()
        case .apps: LauncherView(launcher: models.launcher)
        }
    }
}

struct BatteryBadge: View {
    @ObservedObject var system: SystemModel

    var body: some View {
        if let level = system.batteryLevel {
            HStack(spacing: 4) {
                Text("\(level)%").font(.system(size: 11, weight: .medium)).monospacedDigit()
                Image(systemName: system.batterySymbol)
                    .font(.system(size: 13))
                    .foregroundStyle(system.isCharging ? Color.green : (level <= 20 ? Color.red : Color.white))
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Battery \(level)%\(system.isCharging ? ", charging" : "")")
        }
    }
}

struct SettingsMenu: View {
    @State private var launchAtLogin = LoginItem.isEnabled
    @AppStorage(MusicController.browsersKey) private var browsers = false

    var body: some View {
        Menu {
            Toggle("Launch at Login", isOn: $launchAtLogin)
            // Off by default: each browser asks for permission the first time.
            Toggle("Media from Browsers", isOn: $browsers)
            if browsers {
                Text("Turn on \"Allow JavaScript from Apple Events\" in each browser")
            }
            Divider()
            Button("Quit NotchDeck") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "gearshape.fill")
        }
        .accessibilityLabel("Settings")
        .help("Settings")
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onChange(of: launchAtLogin) { LoginItem.set($0) }
    }
}
