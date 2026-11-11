import AppKit

/// Files dropped on the notch. Only references are kept; files are never moved or copied.
final class ShelfModel: ObservableObject {
    @Published private(set) var files: [URL] = []

    private let defaultsKey = "shelf.paths"

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        files = paths
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
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
        UserDefaults.standard.set(files.map { $0.path }, forKey: defaultsKey)
    }
}
