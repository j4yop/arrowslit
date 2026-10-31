import CoreAudio
import CoreGraphics
import Foundation
import IOKit.ps
import Observation

/// Watches the small system signals the notch can react to: power, the default audio device,
/// volume and display brightness. It emits alerts only for changes that happen while the app is
/// running; opening the app never replays the current state.
@MainActor
@Observable
public final class SystemMonitorService {
    public private(set) var batteryLevel: Int = 100
    public private(set) var isOnAC = false
    public private(set) var isCharging = false

    @ObservationIgnored public var onAlert: ((NotchAlert) -> Void)?
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var ticks = 0
    @ObservationIgnored private var powerRules = PowerAlertRules()
    @ObservationIgnored private var lastOutputDevice: AudioDeviceID = 0
    @ObservationIgnored private var lastVolume: Float?
    @ObservationIgnored private var lastMuted: Bool?
    @ObservationIgnored private var lastBrightness: Float?
    @ObservationIgnored private var brightnessReader: BrightnessReader?
    @ObservationIgnored private var displayHandle: UnsafeMutableRawPointer?
    @ObservationIgnored private var brightnessUnavailable = false
    #if DEBUG
    @ObservationIgnored private var isDemo = false
    #endif

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public func start() {
        guard timer == nil else { return }
        pollPower()
        pollAudio()
        pollBrightness()

        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        if let displayHandle { dlclose(displayHandle) }
        displayHandle = nil
        brightnessReader = nil
        brightnessUnavailable = false
        lastOutputDevice = 0
        lastVolume = nil
        lastMuted = nil
        lastBrightness = nil
    }

    private func tick() {
        #if DEBUG
        guard !isDemo else { return }
        #endif
        ticks += 1
        if ticks % 5 == 0 { pollPower() }

        if settings.alertHeadphones || settings.alertVolumeBrightness {
            pollAudio()
        } else {
            lastOutputDevice = 0
            lastVolume = nil
            lastMuted = nil
        }

        if settings.alertVolumeBrightness {
            pollBrightness()
        } else {
            lastBrightness = nil
        }
    }

    // MARK: - Power

    private func pollPower() {
        guard let snapshot = Self.readPower() else { return }
        batteryLevel = snapshot.level
        isOnAC = snapshot.isOnAC
        isCharging = snapshot.isCharging

        let alerts = powerRules.observe(
            snapshot,
            chargingAlerts: settings.alertCharging,
            lowBatteryAlerts: settings.alertLowBattery
        )
        alerts.forEach { onAlert?($0) }
    }

    private nonisolated static func readPower() -> PowerSnapshot? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any],
                let type = description[kIOPSTypeKey] as? String,
                type == kIOPSInternalBatteryType,
                let level = description[kIOPSCurrentCapacityKey] as? Int else {
                continue
            }
            let charging = description[kIOPSIsChargingKey] as? Bool ?? false
            let state = description[kIOPSPowerSourceStateKey] as? String
            return PowerSnapshot(
                level: min(max(level, 0), 100),
                isCharging: charging,
                isOnAC: state == kIOPSACPowerValue
            )
        }
        return nil
    }

    // MARK: - Audio

    private struct OutputDevice {
        var id: AudioDeviceID
        var transport: UInt32
        var name: String
    }

    private func pollAudio() {
        guard let output = Self.outputDevice() else {
            lastOutputDevice = 0
            lastVolume = nil
            lastMuted = nil
            return
        }

        if settings.alertHeadphones {
            let previous = lastOutputDevice
            lastOutputDevice = output.id
            let isBluetooth = output.transport == kAudioDeviceTransportTypeBluetooth
                || output.transport == kAudioDeviceTransportTypeBluetoothLE
            if isBluetooth, previous != 0, previous != output.id {
                onAlert?(.headphones(name: output.name))
            }
        } else {
            lastOutputDevice = 0
        }

        if settings.alertVolumeBrightness {
            guard let (volume, muted) = Self.volume(of: output.id) else {
                lastVolume = nil
                lastMuted = nil
                return
            }
            if let lastVolume, let lastMuted,
               abs(volume - lastVolume) > 0.005 || muted != lastMuted {
                onAlert?(.level(kind: .volume, value: muted ? 0 : Double(volume), muted: muted))
            }
            lastVolume = volume
            lastMuted = muted
        } else {
            lastVolume = nil
            lastMuted = nil
        }
    }

    private nonisolated static func outputDevice() -> OutputDevice? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        ) == noErr, device != 0 else {
            return nil
        }

        var transport: UInt32 = 0
        var transportSize = UInt32(MemoryLayout<UInt32>.size)
        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let transportStatus = AudioObjectGetPropertyData(
            device,
            &transportAddress,
            0,
            nil,
            &transportSize,
            &transport
        )

        return OutputDevice(
            id: device,
            transport: transportStatus == noErr ? transport : 0,
            name: deviceName(device)
        )
    }

    private nonisolated static func deviceName(_ device: AudioDeviceID) -> String {
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return "Bluetooth headphones" }
        let value = name as String
        return value.isEmpty ? "Bluetooth headphones" : value
    }

    private nonisolated static func volume(of device: AudioDeviceID) -> (Float, Bool)? {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        if status != noErr {
            address.mElement = 1
            status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        }
        guard status == noErr else { return nil }

        var mute: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted = false
        if AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &muteSize, &mute) == noErr {
            muted = mute != 0
        }
        return (min(max(volume, 0), 1), muted)
    }

    // MARK: - Brightness

    private typealias BrightnessReader = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private func pollBrightness() {
        guard let value = currentBrightness() else {
            lastBrightness = nil
            return
        }
        if let lastBrightness, abs(value - lastBrightness) > 0.02 {
            onAlert?(.level(kind: .brightness, value: Double(value), muted: false))
        }
        lastBrightness = value
    }

    private func currentBrightness() -> Float? {
        guard !brightnessUnavailable else { return nil }
        if brightnessReader == nil {
            guard let handle = dlopen(
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                RTLD_LAZY
            ), let symbol = dlsym(handle, "DisplayServicesGetBrightness") else {
                brightnessUnavailable = true
                return nil
            }
            displayHandle = handle
            brightnessReader = unsafeBitCast(symbol, to: BrightnessReader.self)
        }
        guard let brightnessReader else { return nil }
        var value: Float = 0
        guard brightnessReader(CGMainDisplayID(), &value) == 0 else { return nil }
        return min(max(value, 0), 1)
    }

    #if DEBUG
    /// Debug builds only: render the lock-screen charging strip without waiting for a charger.
    public func showDemoPower(level: Int = 80, onAC: Bool = true, charging: Bool = true) {
        isDemo = true
        batteryLevel = level
        isOnAC = onAC
        isCharging = charging
    }

    public func endDemoPower() {
        isDemo = false
        pollPower()
    }
    #endif
}
