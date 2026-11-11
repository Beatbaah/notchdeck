import AppKit
import UniformTypeIdentifiers

/// Pinned apps shown in the Apps tab.
final class LauncherModel: ObservableObject {
    @Published private(set) var apps: [URL] = []

    private let defaultsKey = "launcher.paths"
    private static let defaultPaths = [
        "/System/Library/CoreServices/Finder.app",
        "/Applications/Safari.app",
        "/System/Applications/Mail.app",
        "/System/Applications/Notes.app",
        "/System/Applications/Calendar.app",
        "/System/Applications/Utilities/Terminal.app",
        "/System/Applications/System Settings.app",
    ]

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? Self.defaultPaths
        apps = paths
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    func open(_ url: URL) {
        NSWorkspace.shared.openApplication(at: url,
                                           configuration: NSWorkspace.OpenConfiguration(),
                                           completionHandler: nil)
    }

    func add(_ url: URL) {
        guard !apps.contains(url) else { return }
        apps.append(url)
        save()
    }

    func remove(_ url: URL) {
        apps.removeAll { $0 == url }
        save()
    }

    @MainActor
    func addViaPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK {
            panel.urls.forEach { add($0) }
        }
    }

    private func save() {
        UserDefaults.standard.set(apps.map { $0.path }, forKey: defaultsKey)
    }
}
