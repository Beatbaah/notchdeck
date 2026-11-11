import AppKit
import IOKit.ps

/// Output volume, mute and battery level.
final class SystemModel: ObservableObject {
    @Published var volume: Double = 50
    @Published var muted = false
    /// False when the current output has no software volume (the slider is then disabled).
    @Published private(set) var volumeAvailable = true
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var isCharging = false

    private var timer: Timer?

    init() {
        refreshBattery()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.refreshBattery() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        refreshBattery()
        refreshVolume()
    }

    func refreshVolume() {
        AppleScript.runSystem("output volume of (get volume settings)") { [weak self] result in
            guard let self, let result else { return }
            if let level = Self.volume(from: result) {
                self.volume = level
                self.volumeAvailable = true
            } else {
                self.volumeAvailable = false
            }
        }
        AppleScript.runSystem("output muted of (get volume settings)") { [weak self] result in
            if let result { self?.muted = result.booleanValue }
        }
    }

    // A slider drag fires many values; send one at a time, ending on the latest.
    private lazy var volumeSender = LatestValueSender<Int> { level, done in
        AppleScript.runSystem("set volume output volume \(level)") { _ in done() }
    }

    func setVolume(_ value: Double) {
        volume = value
        volumeSender.send(Int(value.rounded()))
    }

    func toggleMute() {
        muted.toggle()
        AppleScript.runSystem("set volume output muted \(muted ? "true" : "false")")
    }

    /// Turns the display off. If "require password immediately" is on, this also locks the Mac.
    func sleepDisplay() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }

    func refreshBattery() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            batteryLevel = nil
            return
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let capacity = description[kIOPSMaxCapacityKey] as? Int,
                  capacity > 0 else { continue }
            batteryLevel = Int((Double(current) / Double(capacity) * 100).rounded())
            isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
            return
        }
        batteryLevel = nil // desktop Mac
    }

    var batterySymbol: String {
        guard let level = batteryLevel else { return "powerplug.fill" }
        if isCharging { return "battery.100.bolt" }
        switch level {
        case 88...: return "battery.100"
        case 63..<88: return "battery.75"
        case 38..<63: return "battery.50"
        case 13..<38: return "battery.25"
        default: return "battery.0"
        }
    }
}

extension SystemModel {
    /// The output volume, or nil when the output has none (HDMI and some USB devices reply `missing value`).
    static func volume(from result: NSAppleEventDescriptor) -> Double? {
        let missing: DescType = 0x6D73_6E67 // 'msng'
        if result.descriptorType == missing || (result.descriptorType == typeType && result.typeCodeValue == missing) {
            return nil
        }
        return Double(result.int32Value)
    }
}
