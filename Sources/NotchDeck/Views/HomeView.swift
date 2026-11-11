import SwiftUI

struct HomeView: View {
    let models: Models

    var body: some View {
        HStack(spacing: 10) {
            MusicCard(music: models.music, calendar: models.calendar)
            ControlsCard(system: models.system, timer: models.timer).frame(width: 210)
        }
    }
}

struct MusicCard: View {
    @ObservedObject var music: MusicController
    @ObservedObject var calendar: CalendarModel

    var body: some View {
        Card {
            if music.player == nil, let next = CalendarAgenda.next(calendar.items, now: Date()) {
                // Nothing playing: the space shows what's next today instead.
                VStack(alignment: .leading, spacing: 8) {
                    Label("Next", systemImage: "calendar").font(.caption).foregroundStyle(.secondary)
                    EventRow(item: next)
                    Spacer(minLength: 0)
                    Text("Play in Music, Spotify, VLC or a browser").font(.caption).foregroundStyle(.tertiary)
                }
            } else if music.player == nil {
                VStack(spacing: 6) {
                    Image(systemName: "music.note").font(.title2).foregroundStyle(.secondary)
                    Text("Nothing playing").font(.callout).foregroundStyle(.secondary)
                    Text("Play in Music, Spotify, VLC or a browser").font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 12) {
                    ArtworkView(image: music.artwork, size: 96, corner: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(music.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        Text(music.artist).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                        Text(music.player?.displayName ?? "").font(.caption2).foregroundStyle(.tertiary)
                        Spacer(minLength: 4)
                        TrackProgress(music: music)
                        HStack(spacing: 20) {
                            controlButton("backward.fill", size: 14, label: "Previous track") { music.previous() }
                            controlButton(music.isPlaying ? "pause.fill" : "play.fill", size: 20,
                                          label: music.isPlaying ? "Pause" : "Play") { music.playPause() }
                            controlButton("forward.fill", size: 14, label: "Next track") { music.next() }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

/// Volume, battery, the timer (one row) and display sleep.
struct ControlsCard: View {
    @ObservedObject var system: SystemModel
    @ObservedObject var timer: TimerModel
    private let presets: [Double] = [1, 5, 15, 25]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Button { system.toggleMute() } label: {
                        Image(systemName: system.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 18)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(system.muted ? "Unmute" : "Mute")
                    Slider(value: Binding(get: { system.volume }, set: { system.setVolume($0) }), in: 0...100)
                        .controlSize(.small)
                        .accessibilityLabel("Volume")
                }
                if let level = system.batteryLevel {
                    HStack(spacing: 6) {
                        Image(systemName: system.batterySymbol).frame(width: 18)
                        Text("\(level)%\(system.isCharging ? " · charging" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                timerRow
                Spacer(minLength: 0)
                Button { system.sleepDisplay() } label: {
                    Label("Sleep display", systemImage: "moon.fill")
                }
                .buttonStyle(PillButtonStyle())
            }
        }
    }

    @ViewBuilder private var timerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer").frame(width: 18).foregroundStyle(timer.isActive ? .orange : .primary)
                .accessibilityHidden(true)
            if timer.isActive {
                Text(timer.remainingText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Timer \(timer.remainingText) left")
                Spacer(minLength: 0)
                iconButton(timer.isRunning ? "pause.fill" : "play.fill", label: timer.isRunning ? "Pause timer" : "Resume timer") { timer.toggle() }
                iconButton("xmark", label: "Stop timer") { timer.cancel() }
            } else {
                ForEach(presets, id: \.self) { minutes in
                    Button("\(Int(minutes))") { timer.start(minutes: minutes) }
                        .buttonStyle(ChipButtonStyle())
                        .accessibilityLabel("Start a \(Int(minutes))-minute timer")
                }
                Text("min").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold)).frame(width: 22, height: 22)
        }
        .buttonStyle(ChipButtonStyle())
        .accessibilityLabel(label)
    }
}

/// A small round-cornered chip for compact controls.
struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .padding(.horizontal, 7)
            .frame(minWidth: 24, minHeight: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(configuration.isPressed ? 0.2 : 0.1)))
            .contentShape(Rectangle())
    }
}

/// The song's progress, with times; drag to jump. Hidden when the length is unknown.
struct TrackProgress: View {
    @ObservedObject var music: MusicController
    @State private var dragging: Double?

    var body: some View {
        if let duration = music.duration {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let at = dragging ?? music.livePosition(at: context.date) ?? 0
                VStack(spacing: 2) {
                    Slider(value: Binding(get: { at }, set: { dragging = $0 }), in: 0...max(duration, 1)) { editing in
                        if !editing, let target = dragging {
                            music.seek(to: target)
                            dragging = nil
                        }
                    }
                    .controlSize(.mini)
                    .accessibilityLabel("Track position")
                    .accessibilityValue("\(TrackTime.text(at)) of \(TrackTime.text(duration))")
                    HStack {
                        Text(TrackTime.text(at))
                        Spacer()
                        Text("-" + TrackTime.text(duration - at))
                    }
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
