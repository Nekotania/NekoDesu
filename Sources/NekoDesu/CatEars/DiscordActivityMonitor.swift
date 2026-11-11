import AppKit
import CoreAudio

protocol DiscordActivityObserving {
    func currentObservation() -> DiscordObservation
}

/// Observes only whether Discord is running, whether it has an on-screen
/// window, and whether an input device is in use. It never reads window
/// titles or contents and never opens an audio stream.
struct DiscordActivityMonitor: DiscordActivityObserving {
    static let discordBundleIdentifier = "com.hnc.discord"

    var runningProcessID: () -> pid_t? = DiscordProbes.runningProcessID
    var hasOnScreenWindow: (pid_t) -> Bool = DiscordProbes.hasOnScreenWindow
    var microphoneActivity: () -> MicrophoneActivity = AudioInputProbe.microphoneActivity

    func currentObservation() -> DiscordObservation {
        guard let processID = runningProcessID() else {
            return DiscordObservation(presence: .notRunning, microphone: .unknown)
        }
        return DiscordObservation(
            presence: hasOnScreenWindow(processID) ? .visible : .background,
            microphone: microphoneActivity()
        )
    }
}

enum DiscordProbes {
    static func runningProcessID() -> pid_t? {
        NSWorkspace.shared.runningApplications
            .first { isDiscord(bundleIdentifier: $0.bundleIdentifier) && !$0.isTerminated }?
            .processIdentifier
    }

    /// Bundle identifiers are case-insensitive, and the shipping Discord app
    /// spells its own `com.hnc.Discord`.
    static func isDiscord(bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.caseInsensitiveCompare(DiscordActivityMonitor.discordBundleIdentifier) == .orderedSame
    }

    static func hasOnScreenWindow(processID: pid_t) -> Bool {
        // Owner and layer are available without Screen Recording permission;
        // window titles are not requested.
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return windows.contains { window in
            let owner = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue
            return owner == processID && layer == 0
        }
    }
}

/// Reads CoreAudio device properties only. No capture stream is opened, so
/// macOS does not ask for microphone permission.
enum AudioInputProbe {
    static func microphoneActivity() -> MicrophoneActivity {
        guard let devices = deviceIDs() else { return .unknown }
        let inputDevices = devices.filter(hasInputStreams)
        if inputDevices.isEmpty { return .idle }

        var sawAnAnswer = false
        for device in inputDevices {
            switch isRunningSomewhere(device) {
            case true?: return .inUse
            case false?: sawAnAnswer = true
            case nil: break
            }
        }
        return sawAnAnswer ? .idle : .unknown
    }

    private static func deviceIDs() -> [AudioDeviceID]? {
        var address = propertyAddress(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        let systemObject = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr else { return nil }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &devices) == noErr else { return nil }
        return devices
    }

    private static func hasInputStreams(_ device: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func isRunningSomewhere(_ device: AudioDeviceID) -> Bool? {
        var address = propertyAddress(
            kAudioDevicePropertyDeviceIsRunningSomewhere,
            scope: kAudioObjectPropertyScopeGlobal
        )
        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &isRunning) == noErr else { return nil }
        return isRunning != 0
    }

    private static func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
