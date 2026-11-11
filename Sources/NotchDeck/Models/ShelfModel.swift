import AppKit

/// Files dropped on the notch. Only references are kept; files are never moved or copied.
final class ShelfModel: ObservableObject {
    @Published private(set) var files: [URL] = []

    // Bookmarks follow a file when it's moved or renamed; plain paths (the
    // first version) don't, so they're only read once, then replaced.
    private let bookmarksKey = "shelf.bookmarks"
    private let legacyPathsKey = "shelf.paths"
    private let defaults: UserDefaults
    /// Files on a drive that isn't plugged in: kept, shown again when it's back.
    private var waiting: [Data] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let bookmarks = defaults.array(forKey: bookmarksKey) as? [Data] {
            for bookmark in bookmarks {
                switch Self.locate(bookmark) {
                case .present(let url): files.append(url)
                case .onUnpluggedDrive: waiting.append(bookmark)
                case .gone: break
                }
            }
        } else {
            files = (defaults.stringArray(forKey: legacyPathsKey) ?? [])
                .filter { FileManager.default.fileExists(atPath: $0) }
                .map { URL(fileURLWithPath: $0) }
        }
        save()
    }

    enum Location: Equatable { case present(URL), onUnpluggedDrive, gone }

    static func locate(_ bookmark: Data) -> Location {
        if let url = resolve(bookmark) { return .present(url) }
        if let path = URL.resourceValues(forKeys: [.pathKey], fromBookmarkData: bookmark)?.path,
           isOnUnmountedVolume(path) { return .onUnpluggedDrive }
        return .gone
    }

    /// A path on a drive under /Volumes that isn't mounted right now.
    static func isOnUnmountedVolume(_ path: String) -> Bool {
        let parts = (path as NSString).pathComponents
        guard parts.count > 2, parts[1] == "Volumes" else { return false }
        return !FileManager.default.fileExists(atPath: "/Volumes/" + parts[2])
    }

    /// The file's current location, or nil if it no longer exists.
    private static func resolve(_ bookmark: Data) -> URL? {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url.standardizedFileURL
    }

    func add(_ url: URL) {
        let url = url.standardizedFileURL
        guard !files.contains(url) else { return }
        files.append(url)
        save()
    }

    func add(providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async { self?.add(url) }
            }
        }
        return accepted
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
        save()
    }

    /// Drops files deleted since, parks ones whose drive was unplugged, and brings back
    /// ones whose drive is plugged in again. Called when the shelf is shown.
    func refresh() {
        var still: [URL] = []
        for url in files {
            if FileManager.default.fileExists(atPath: url.path) {
                still.append(url)
            } else if Self.isOnUnmountedVolume(url.path),
                      let bookmark = bookmarks[url] {
                waiting.append(bookmark)
            }
        }
        var stillWaiting: [Data] = []
        for bookmark in waiting {
            switch Self.locate(bookmark) {
            case .present(let url): if !still.contains(url) { still.append(url) }
            case .onUnpluggedDrive: stillWaiting.append(bookmark)
            case .gone: break
            }
        }
        waiting = stillWaiting
        if still != files { files = still }
        save()
    }

    func clear() {
        files.removeAll()
        save()
    }

    /// The latest bookmark for each file shown (kept so a file can wait for its drive).
    private var bookmarks: [URL: Data] = [:]

    private func save() {
        for url in files where bookmarks[url] == nil {
            bookmarks[url] = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        bookmarks = bookmarks.filter { files.contains($0.key) }
        defaults.set(files.compactMap { bookmarks[$0] } + waiting, forKey: bookmarksKey)
        defaults.removeObject(forKey: legacyPathsKey)
    }
}
