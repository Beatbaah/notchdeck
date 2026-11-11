import AppKit

/// Reads now-playing info from Music and Spotify over AppleScript, and sends transport commands.
final class MusicController: ObservableObject {
    enum Player: String {
        case music = "Music"
        case spotify = "Spotify"

        var bundleID: String {
            switch self {
            case .music: return "com.apple.Music"
            case .spotify: return "com.spotify.client"
            }
        }
    }

    private struct Snapshot {
        var player: Player
        var playing: Bool
        var title: String
        var artist: String
        var album: String
        var artworkURL: String?
    }

    @Published private(set) var player: Player?
    @Published private(set) var isPlaying = false
    @Published private(set) var title = ""
    @Published private(set) var artist = ""
    @Published private(set) var artwork: NSImage?

    private var timer: Timer?
    private var artworkKey = ""
    private var busy = false

    init() {
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    func refresh() {
        guard !busy else { return }
        // Only talk to players that are already open; scripting a closed app would launch it.
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let candidates = [Player.spotify, .music].filter { running.contains($0.bundleID) }
        guard !candidates.isEmpty else { apply(nil); return }

        busy = true
        AppleScript.queue.async { [weak self] in
            let snapshots = candidates.compactMap { MusicController.query($0) }
            let pick = snapshots.first(where: { $0.playing }) ?? snapshots.first
            DispatchQueue.main.async {
                self?.busy = false
                self?.apply(pick)
            }
        }
    }

    func playPause() {
        isPlaying.toggle()
        send("playpause")
    }

    func next() { send("next track") }
    func previous() { send("previous track") }

    private func send(_ command: String) {
        guard let player else { return }
        let source = "tell application \"\(player.rawValue)\" to \(command)"
        AppleScript.runAsync(source) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.refresh() }
        }
    }

    private func apply(_ snapshot: Snapshot?) {
        guard let snapshot else {
            if player != nil {
                player = nil
                isPlaying = false
                title = ""
                artist = ""
                artwork = nil
                artworkKey = ""
            }
            return
        }
        player = snapshot.player
        isPlaying = snapshot.playing
        title = snapshot.title
        artist = snapshot.artist

        let key = [snapshot.player.rawValue, snapshot.title, snapshot.artist, snapshot.album].joined(separator: "|")
        if key != artworkKey {
            artworkKey = key
            artwork = nil
            loadArtwork(for: snapshot, key: key)
        }
    }

    private func loadArtwork(for snapshot: Snapshot, key: String) {
        switch snapshot.player {
        case .music:
            AppleScript.runAsync("tell application \"Music\" to get raw data of artwork 1 of current track") { [weak self] result in
                guard let self, self.artworkKey == key, let data = result?.data else { return }
                self.artwork = NSImage(data: data)
            }
        case .spotify:
            guard let string = snapshot.artworkURL, let url = URL(string: string) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                let image = data.flatMap { NSImage(data: $0) }
                DispatchQueue.main.async {
                    guard let self, self.artworkKey == key else { return }
                    self.artwork = image
                }
            }.resume()
        }
    }

    /// Runs on `AppleScript.queue`.
    private static func query(_ player: Player) -> Snapshot? {
        let artworkPart = player == .spotify ? " & sep & (artwork url of t)" : ""
        let source = """
        tell application "\(player.rawValue)"
            if player state is stopped then return "stopped"
            set sep to "|~|"
            set ps to "paused"
            if player state is playing then set ps to "playing"
            set t to current track
            return ps & sep & (name of t) & sep & (artist of t) & sep & (album of t)\(artworkPart)
        end tell
        """
        guard let output = AppleScript.run(source)?.stringValue, output != "stopped" else { return nil }
        let parts = output.components(separatedBy: "|~|")
        guard parts.count >= 4 else { return nil }
        return Snapshot(player: player,
                        playing: parts[0] == "playing",
                        title: parts[1],
                        artist: parts[2],
                        album: parts[3],
                        artworkURL: parts.count > 4 ? parts[4] : nil)
    }
}
