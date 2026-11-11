import Foundation
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    /// Registered, but the user still has to allow it in System Settings → General → Login Items.
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("NotchDeck: could not change launch-at-login: \(error.localizedDescription)")
        }
    }
}
