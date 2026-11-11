import Foundation

/// Players NotchDeck can read and control. All are asked over AppleScript,
/// and only while already open (scripting a closed app would launch it).
/// Browsers need "Allow JavaScript from Apple Events" turned on once in the
/// browser (Safari: Develop menu; Chrome, Brave, Edge: View → Developer).
enum Player: String, CaseIterable {
    case spotify, music, vlc, safari, chrome, brave, edge

    /// Asked in this order; a player that's actually playing still wins.
    static let order: [Player] = [.spotify, .music, .vlc, .safari, .chrome, .brave, .edge]

    var bundleID: String {
        switch self {
        case .spotify: return "com.spotify.client"
        case .music: return "com.apple.Music"
        case .vlc: return "org.videolan.vlc"
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        case .brave: return "com.brave.Browser"
        case .edge: return "com.microsoft.edgemac"
        }
    }

    /// The name AppleScript knows the app by.
    var appName: String {
        switch self {
        case .spotify: return "Spotify"
        case .music: return "Music"
        case .vlc: return "VLC"
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        case .brave: return "Brave Browser"
        case .edge: return "Microsoft Edge"
        }
    }

    var displayName: String {
        switch self {
        case .chrome: return "Chrome"
        case .brave: return "Brave"
        case .edge: return "Edge"
        default: return appName
        }
    }

    var isBrowser: Bool { [.safari, .chrome, .brave, .edge].contains(self) }

    /// The players worth asking right now: open ones, and browsers only when
    /// the "Media from browsers" switch is on.
    static func toQuery(running: Set<String>, browsersOn: Bool) -> [Player] {
        order.filter { running.contains($0.bundleID) && (browsersOn || !$0.isBrowser) }
    }
}

/// What one player reports.
struct NowPlaying: Equatable {
    var player: Player
    var isPlaying: Bool
    var title: String
    var artist: String
    var album: String
    var artworkURL: String?
    /// For a browser: "window:tab" of the tab that's playing.
    var ref: String?
    /// Seconds into the track, and its length; nil when unknown (a live stream).
    var position: Double? = nil
    var duration: Double? = nil

    static let separator = "|~|"

    /// Music, Spotify and VLC reply
    /// "playing|~|title|~|artist|~|album[|~|artworkURL[|~|position|~|length]]" or "stopped".
    /// Spotify gives the length in milliseconds.
    static func parse(_ output: String, player: Player) -> NowPlaying? {
        let parts = output.components(separatedBy: separator)
        guard parts.count >= 4, parts[0] == "playing" || parts[0] == "paused" else { return nil }
        var now = NowPlaying(player: player, isPlaying: parts[0] == "playing", title: parts[1], artist: parts[2], album: parts[3],
                             artworkURL: parts.count > 4 && !parts[4].isEmpty ? parts[4] : nil, ref: nil)
        if parts.count > 6, let position = number(parts[5]), var length = number(parts[6]), length > 0 {
            if player == .spotify { length /= 1000 }
            now.position = position
            now.duration = length
        }
        return now
    }

    /// AppleScript writes decimals the way the Mac's region does ("102,5" in some).
    private static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    /// Browsers reply with JSON built from the page's media element and Media Session.
    static func parseBrowser(_ output: String, player: Player) -> NowPlaying? {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String, !title.isEmpty else { return nil }
        let artwork = (json["artwork"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        var now = NowPlaying(player: player, isPlaying: json["playing"] as? Bool ?? false, title: title,
                             artist: json["artist"] as? String ?? "", album: "", artworkURL: artwork, ref: json["ref"] as? String)
        if let length = json["duration"] as? Double, length.isFinite, length > 0 {
            now.duration = length
            now.position = json["position"] as? Double
        }
        return now
    }

    /// A player that's playing wins; otherwise the first (paused) one in order.
    static func pick(_ all: [NowPlaying]) -> NowPlaying? {
        all.first(where: \.isPlaying) ?? all.first
    }
}

/// The AppleScript for each player. Runs on `AppleScript.queue`.
enum PlayerScripts {
    private static let sep = NowPlaying.separator

    static func query(_ player: Player) -> NowPlaying? {
        guard let source = querySource(player) else { return nil }
        guard let output = AppleScript.run(source, ifRunning: player.bundleID)?.stringValue else { return nil }
        return player.isBrowser ? NowPlaying.parseBrowser(output, player: player) : NowPlaying.parse(output, player: player)
    }

    /// The query script for a player (also compiled by the tests).
    static func querySource(_ player: Player) -> String? {
        unguardedQuery(player).map { guarded($0) }
    }

    private static func unguardedQuery(_ player: Player) -> String? {
        switch player {
        case .music, .spotify:
            // Artwork URL (Spotify only), then position and length.
            let artwork = player == .spotify ? "(artwork url of t)" : "\"\""
            let source = """
            tell application "\(player.appName)"
                if player state is stopped then return "stopped"
                set sep to "\(sep)"
                set ps to "paused"
                if player state is playing then set ps to "playing"
                set t to current track
                return ps & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & \(artwork) & sep & (player position as text) & sep & (duration of t as text)
            end tell
            """
            return source
        case .vlc:
            let source = """
            tell application "VLC"
                try
                    set n to name of current item
                on error
                    return "stopped"
                end try
                set ps to "paused"
                if playing then set ps to "playing"
                set p to ""
                set d to ""
                try
                    set p to (current time as text)
                    set d to (duration of current item as text)
                end try
                return ps & "\(sep)" & n & "\(sep)" & "" & "\(sep)" & "" & "\(sep)" & "" & "\(sep)" & p & "\(sep)" & d
            end tell
            """
            return source
        case .safari, .chrome, .brave, .edge:
            return browserQuery(player)
        }
    }

    /// Gives up on a stuck or unanswered app after a few seconds instead of AppleScript's two minutes.
    /// (Run player scripts with `AppleScript.run(_:ifRunning:)` so a quit app isn't relaunched.)
    static func guarded(_ source: String) -> String {
        """
        with timeout of 3 seconds
        \(source)
        end timeout
        """
    }

    /// Music's artwork script; other players send an artwork URL instead.
    static func artworkSource(_ player: Player) -> String? {
        guard player == .music else { return nil }
        return guarded("tell application \"Music\" to get raw data of artwork 1 of current track")
    }

    enum Command { case playPause, next, previous }

    static func command(_ command: Command, to now: NowPlaying) -> String {
        guarded(unguardedCommand(command, to: now))
    }

    private static func unguardedCommand(_ command: Command, to now: NowPlaying) -> String {
        switch now.player {
        case .music, .spotify:
            let verb = ["playpause", "next track", "previous track"][command.index]
            return "tell application \"\(now.player.appName)\" to \(verb)"
        case .vlc:
            let verb = ["play", "next", "previous"][command.index]
            return "tell application \"VLC\" to \(verb)"
        case .safari, .chrome, .brave, .edge:
            let parts = (now.ref ?? "1:1").split(separator: ":").map(String.init)
            let (w, t) = (parts.first ?? "1", parts.count > 1 ? parts[1] : "1")
            let js = [jsPlayPause, jsNext, jsPrevious][command.index]
            return now.player == .safari
                ? "tell application \"Safari\" to do JavaScript \"\(js)\" in tab \(t) of window \(w)"
                : "tell application \"\(now.player.appName)\" to execute tab \(t) of window \(w) javascript \"\(js)\""
        }
    }

    /// Jump to a point in the track.
    static func seek(to seconds: Double, in now: NowPlaying) -> String {
        guarded(unguardedSeek(to: seconds, in: now))
    }

    private static func unguardedSeek(to seconds: Double, in now: NowPlaying) -> String {
        let at = String(format: "%.1f", max(0, seconds))
        switch now.player {
        case .music, .spotify:
            return "tell application \"\(now.player.appName)\" to set player position to \(at)"
        case .vlc:
            return "tell application \"VLC\" to set current time to \(Int(max(0, seconds)))"
        case .safari, .chrome, .brave, .edge:
            let parts = (now.ref ?? "1:1").split(separator: ":").map(String.init)
            let (w, t) = (parts.first ?? "1", parts.count > 1 ? parts[1] : "1")
            let js = "(function(){" + jsFindMedia + "if(e)e.currentTime=" + at + ";})()"
            return now.player == .safari
                ? "tell application \"Safari\" to do JavaScript \"\(js)\" in tab \(t) of window \(w)"
                : "tell application \"\(now.player.appName)\" to execute tab \(t) of window \(w) javascript \"\(js)\""
        }
    }

    // MARK: Browsers

    /// Sites whose tabs are always checked; the front window's active tab is checked too.
    private static let mediaHosts = [
        "youtube.com", "soundcloud.com", "open.spotify.com", "music.apple.com", "audiomack.com", "boomplay.com",
        "deezer.com", "tidal.com", "mixcloud.com", "twitch.tv", "vimeo.com",
    ]

    // Muted or silent media (autoplay previews, feed videos) isn't treated as playing.
    // Page scripts use only single quotes, so they sit inside AppleScript's double quotes as they are.
    static let jsFindMedia =
        "var m=Array.prototype.slice.call(document.querySelectorAll('video,audio')).filter(function(e){return e.currentSrc&&e.duration>0&&!e.muted&&e.volume>0;});"
        + "var e=m.filter(function(x){return !x.paused;})[0]||m[0];"

    private static let jsQuery =
        "(function(){" + jsFindMedia + "if(!e)return '';"
        + "var md=navigator.mediaSession&&navigator.mediaSession.metadata;var art='';"
        + "if(md&&md.artwork&&md.artwork.length){art=md.artwork[md.artwork.length-1].src;}"
        + "return JSON.stringify({playing:!e.paused,title:(md&&md.title)||document.title,artist:(md&&md.artist)||location.hostname,artwork:art,"
        + "position:e.currentTime,duration:isFinite(e.duration)?e.duration:null});})()"

    private static let jsPlayPause = "(function(){" + jsFindMedia + "if(e){if(e.paused)e.play();else e.pause();}})()"

    private static func jsClick(_ selectors: [String], fallback: String) -> String {
        "(function(){var s=['" + selectors.joined(separator: "','") + "'];for(var i=0;i<s.length;i++){var b=document.querySelector(s[i]);if(b){b.click();return;}}"
            + jsFindMedia + fallback + "})()"
    }
    private static let jsNext = jsClick(
        [".ytp-next-button", "ytmusic-player-bar .next-button", "[data-testid=control-button-skip-forward]", ".skipControl__next"],
        fallback: "if(e&&e.duration)e.currentTime=e.duration;")
    private static let jsPrevious = jsClick(
        ["ytmusic-player-bar .previous-button", "[data-testid=control-button-skip-back]", ".skipControl__previous"],
        fallback: "if(e)e.currentTime=0;")

    private static func browserQuery(_ player: Player) -> String {
        let hostTest = mediaHosts.map { "u contains \"\($0)\"" }.joined(separator: " or ")
        // Safari and the Chromium browsers name the same things differently.
        let isSafari = player == .safari
        let activeIndex = isSafari ? "(index of current tab of w)" : "(active tab index of w)"
        let run = isSafari ? "do JavaScript \"\(jsQuery)\" in t" : "execute t javascript \"\(jsQuery)\""
        return """
        tell application "\(player.appName)"
            set wi to 0
            repeat with w in windows
                set wi to wi + 1
                set ti to 0
                set active to \(activeIndex)
                repeat with t in tabs of w
                    set ti to ti + 1
                    set u to ""
                    try
                        set u to URL of t
                    end try
                    if u is missing value then set u to ""
                    if (\(hostTest)) or (wi = 1 and ti = active) then
                        try
                            set r to \(run)
                            if r is not missing value and r is not "" then return "{\\"ref\\":\\"" & wi & ":" & ti & "\\"," & (text 2 thru -1 of r)
                        end try
                    end if
                end repeat
            end repeat
        end tell
        return ""
        """
    }
}

private extension PlayerScripts.Command {
    var index: Int {
        switch self {
        case .playPause: return 0
        case .next: return 1
        case .previous: return 2
        }
    }
}

/// Track times as players show them, and the position between checks.
enum TrackTime {
    static func text(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// Players are asked every 1.5 s; in between, a playing track keeps moving.
    static func live(position: Double, duration: Double, playing: Bool, since: Date, now: Date) -> Double {
        guard playing else { return position }
        return min(duration, position + now.timeIntervalSince(since))
    }
}
