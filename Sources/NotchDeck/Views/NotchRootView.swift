import SwiftUI

struct NotchRootView: View {
    @ObservedObject var state: NotchState
    let models: Models

    var body: some View {
        let size = state.isExpanded ? state.expandedSize : state.collapsedSize
        let shape = NotchShape(topRadius: NotchState.topRadius,
                               bottomRadius: state.isExpanded ? 24 : 10)

        ZStack(alignment: .top) {
            if state.isExpanded {
                // Frosted glass below the menu bar; solid black in the strip beside
                // the physical notch (so the camera cut-out never shows), fading in.
                GlassBackground()
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: stripFraction),
                                       .init(color: .black.opacity(0), location: min(1, stripFraction + 0.09))],
                               startPoint: .top, endPoint: .bottom)
            } else {
                Color.black
            }

            if state.isExpanded {
                ExpandedView(state: state, models: models)
                    .frame(width: state.expandedSize.width, height: state.expandedSize.height)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                CollapsedView(state: state, music: models.music, timer: models.timer)
                    .frame(width: state.collapsedSize.width, height: state.collapsedSize.height)
                    .environment(\.colorScheme, .dark)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The menu bar strip's share of the open panel's height.
    private var stripFraction: CGFloat {
        state.notchSize.height / max(1, state.expandedSize.height)
    }
}

/// The closed notch. With a live activity it widens to show artwork/bars or a countdown.
struct CollapsedView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var music: MusicController
    @ObservedObject var timer: TimerModel

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: state.sideSlot)
            Spacer(minLength: 0)
            trailing.frame(width: state.sideSlot)
        }
        .padding(.horizontal, NotchState.topRadius)
        .frame(height: state.notchSize.height)
    }

    @ViewBuilder private var leading: some View {
        switch state.liveActivity {
        case .music:
            ArtworkView(image: music.artwork, size: max(14, state.notchSize.height - 12), corner: 5)
        case .timer:
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder private var trailing: some View {
        switch state.liveActivity {
        case .music:
            EqualizerBars(playing: music.isPlaying)
        case .timer:
            Text(timer.remainingText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.orange)
        case .none:
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
