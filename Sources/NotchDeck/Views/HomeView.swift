import SwiftUI

struct HomeView: View {
    let models: Models

    var body: some View {
        HStack(spacing: 10) {
            MusicCard(music: models.music, calendar: models.calendar)
            ControlsCard(system: models.system).frame(width: 190)
        }
    }
}

struct MusicCard: View {
    @ObservedObject var music: MusicController
    @ObservedObject var calendar: CalendarModel

    var body: some View {
        Card {
            if music.player == nil, let problem = music.problem {
                // A player is open but NotchDeck isn't allowed to read it.
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.title2).foregroundStyle(Color.glassSecondary)
                    Text(problem.message).font(.callout).foregroundStyle(Color.glassSecondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    if let url = problem.settingsURL {
                        Button("Open System Settings") { NSWorkspace.shared.open(url) }
                            .buttonStyle(PillButtonStyle())
                            .frame(maxWidth: 200)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if music.player == nil, let next = CalendarAgenda.next(calendar.items, now: Date()) {
                // Nothing playing: the space shows what's next today instead.
                VStack(alignment: .leading, spacing: 8) {
                    Label("Next", systemImage: "calendar").font(.caption).foregroundStyle(Color.glassSecondary)
                    EventRow(item: next)
                    Spacer(minLength: 0)
                    Text("Play in Music, Spotify, VLC or a browser").font(.caption).foregroundStyle(Color.glassTertiary)
                }
            } else if music.player == nil {
                VStack(spacing: 6) {
                    Image(systemName: "music.note").font(.title2).foregroundStyle(Color.glassSecondary)
                    Text("Nothing playing").font(.callout.weight(.semibold)).foregroundStyle(Color.glassSecondary)
                    Text("Play in Music, Spotify, VLC or a browser").font(.caption).foregroundStyle(Color.glassTertiary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 12) {
                    ArtworkView(image: music.artwork, size: 96, corner: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(music.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                        Text(music.artist).font(.system(size: 12)).foregroundStyle(Color.glassSecondary).lineLimit(1)
                        Text(music.player?.displayName ?? "").font(.caption2).foregroundStyle(Color.glassTertiary)
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

/// Volume, battery and display sleep.
struct ControlsCard: View {
    @ObservedObject var system: SystemModel

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
                            .foregroundStyle(Color.glassSecondary)
                    }
                }
                Spacer(minLength: 0)
                Button { system.sleepDisplay() } label: {
                    Label("Sleep display", systemImage: "moon.fill")
                }
                .buttonStyle(PillButtonStyle())
            }
        }
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
                    .foregroundStyle(Color.glassSecondary)
                }
            }
        }
    }
}
