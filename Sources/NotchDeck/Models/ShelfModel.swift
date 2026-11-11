import AppKit

/// Files dropped on the notch. Only references are kept; files are never moved or copied.
final class ShelfModel: ObservableObject {
    @Published private(set) var files: [URL] = []

    // Bookmarks follow a file when it's moved or renamed; plain paths (the
    // first version) don't, so they're only read once, then replaced.
    private let bookmarksKey = "shelf.bookmarks"
    private let legacyPathsKey = "shelf.paths"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let bookmarks = defaults.array(forKey: bookmarksKey) as? [Data] {
            files = bookmarks.compactMap(Self.resolve)
        } else {
            files = (defaults.stringArray(forKey: legacyPathsKey) ?? [])
                .filter { FileManager.default.fileExists(atPath: $0) }
                .map { URL(fileURLWithPath: $0) }
        }
        save()
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

    func clear() {
        files.removeAll()
        save()
    }

    private func save() {
        let bookmarks = files.compactMap { try? $0.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) }
        defaults.set(bookmarks, forKey: bookmarksKey)
        defaults.removeObject(forKey: legacyPathsKey)
    }
}
