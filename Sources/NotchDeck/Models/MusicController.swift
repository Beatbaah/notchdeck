import AppKit

/// Reads now-playing info from the open players (see `Player`) over AppleScript, and sends transport commands.
final class MusicController: ObservableObject {
    /// The "Media from browsers" switch (Settings menu). Off by default, so
    /// browsers you never play media in don't trigger permission prompts.
    static let browsersKey = "players.browsers"

    @Published private(set) var player: Player?
    @Published private(set) var isPlaying = false
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var artwork: NSImage?
    /// Seconds in and length at the last check (nil: no bar, e.g. a live stream).
    @Published private(set) var position: Double?
    @Published private(set) var duration: Double?
    private(set) var positionCheckedAt = Date()

    /// Set by the notch: players are asked less often while nobody's looking (see `PollPolicy`).
    var panelOpen = false
    var screenAwake = true

    private var current: NowPlaying?
    private var timer: Timer?
    private var artworkKey = ""
    private var busy = false
    private var lastPoll = Date.distantPast

    init() {
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.pollIfDue() }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        // Spotify and Music announce track and play/pause changes, so those show at once
        // even between the slower checks.
        let center = DistributedNotificationCenter.default()
        for name in ["com.spotify.client.PlaybackStateChanged", "com.apple.Music.playerInfo"] {
            center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
        }
        refresh()
    }

    private func pollIfDue() {
        guard PollPolicy.shouldPollPlayers(panelOpen: panelOpen, screenAwake: screenAwake,
                                           sinceLast: Date().timeIntervalSince(lastPoll)) else { return }
        refresh()
    }

    func refresh() {
        guard !busy else { return }
        lastPoll = Date()
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let candidates = Player.toQuery(running: running, browsersOn: UserDefaults.standard.bool(forKey: Self.browsersKey))
        guard !candidates.isEmpty else { apply(nil); return }
        busy = true
        AppleScript.queue.async { [weak self] in
            let pick = NowPlaying.pick(candidates.compactMap(PlayerScripts.query))
            DispatchQueue.main.async {
                self?.busy = false
                self?.apply(pick)
            }
        }
    }

    func playPause() {
        isPlaying.toggle()
        send(.playPause)
    }
    func next() { send(.next) }

    /// Jump to a point in the track (the progress bar).
    func seek(to seconds: Double) {
        guard let current else { return }
        position = seconds
        positionCheckedAt = Date()
        AppleScript.runAsync(PlayerScripts.seek(to: seconds, in: current), ifRunning: current.player.bundleID) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.refresh() }
        }
    }

    /// Where the track is now, moving on between checks while it plays.
    func livePosition(at now: Date = Date()) -> Double? {
        guard let position, let duration else { return nil }
        return TrackTime.live(position: position, duration: duration, playing: isPlaying, since: positionCheckedAt, now: now)
    }
    func previous() { send(.previous) }

    private func send(_ command: PlayerScripts.Command) {
        guard let current else { return }
        AppleScript.runAsync(PlayerScripts.command(command, to: current), ifRunning: current.player.bundleID) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.refresh() }
        }
    }

    private func apply(_ now: NowPlaying?) {
        current = now
        guard let now else {
            if player != nil {
                player = nil
                isPlaying = false
                title = ""
                artist = ""
                artwork = nil
                artworkKey = ""
                position = nil
                duration = nil
            }
            return
        }
        position = now.position
        duration = now.duration
        positionCheckedAt = Date()
        player = now.player
        isPlaying = now.isPlaying
        title = now.title
        artist = now.artist
        let key = [now.player.rawValue, now.title, now.artist, now.album, now.artworkURL ?? ""].joined(separator: "|")
        if key != artworkKey {
            artworkKey = key
            artwork = nil
            loadArtwork(for: now, key: key)
        }
    }

    private func loadArtwork(for now: NowPlaying, key: String) {
        if now.player == .music {
            AppleScript.runAsync(PlayerScripts.artworkSource(.music)!, ifRunning: Player.music.bundleID) { [weak self] result in
                guard let self, self.artworkKey == key else { return }
                if let data = result?.data, let image = NSImage(data: data) {
                    self.artwork = image
                    return
                }
                // Streamed Apple Music songs have no artwork over AppleScript.
                ArtworkLookup.fetch(title: now.title, artist: now.artist) { [weak self] data in
                    guard let self, self.artworkKey == key, let data else { return }
                    self.artwork = NSImage(data: data)
                }
            }
            return
        }
        guard let string = now.artworkURL, let url = URL(string: string), url.scheme == "https" else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap { NSImage(data: $0) }
            DispatchQueue.main.async {
                guard let self, self.artworkKey == key else { return }
                self.artwork = image
            }
        }.resume()
    }
}
