import CoreAudio
import Foundation

/// Thin, failure-tolerant wrappers around the Core Audio property API.
enum AudioHW {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: UInt32 = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func value<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, default fallback: T) -> T {
        var address = address
        var value = fallback
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        return status == noErr ? value : fallback
    }

    static func objects(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> [AudioObjectID] {
        var address = address
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = ids.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer.baseAddress!)
        }
        guard status == noErr else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    static func string(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> String? {
        var address = address
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static func defaultOutputDevice() -> AudioDeviceID {
        value(system, address(kAudioHardwarePropertyDefaultOutputDevice), default: AudioDeviceID(0))
    }

    static func deviceName(_ device: AudioDeviceID) -> String? {
        string(device, address(kAudioObjectPropertyName))
    }

    static func isBluetooth(_ device: AudioDeviceID) -> Bool {
        let transport: UInt32 = value(device, address(kAudioDevicePropertyTransportType), default: 0)
        return transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    }

    static func inputDevices() -> [AudioDeviceID] {
        objects(system, address(kAudioHardwarePropertyDevices)).filter { device in
            var streams = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
            var size: UInt32 = 0
            return AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &size) == noErr && size > 0
        }
    }

    static func outputDevices() -> [AudioDeviceID] {
        objects(system, address(kAudioHardwarePropertyDevices)).filter { device in
            var streams = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
            var size: UInt32 = 0
            return AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &size) == noErr && size > 0
        }
    }

    /// Makes `device` the Mac's sound output. True when macOS accepted it.
    static func setDefaultOutputDevice(_ device: AudioDeviceID) -> Bool {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = device
        return AudioObjectSetPropertyData(system, &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id) == noErr
    }

    static func isRunningSomewhere(_ device: AudioDeviceID) -> Bool {
        let running: UInt32 = value(device, address(kAudioDevicePropertyDeviceIsRunningSomewhere), default: 0)
        return running != 0
    }

    struct InputProcess: Equatable {
        var pid: pid_t
        var bundleIdentifier: String?
    }

    /// Processes with an active input stream (macOS 14+). Nil if the system can't say.
    static func processesUsingInput() -> [InputProcess]? {
        var listAddress = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &listAddress, 0, nil, &size) == noErr else { return nil }
        return objects(system, listAddress).compactMap { process in
            let running: UInt32 = value(process, address(kAudioProcessPropertyIsRunningInput), default: 0)
            guard running != 0 else { return nil }
            let pid: pid_t = value(process, address(kAudioProcessPropertyPID), default: 0)
            return InputProcess(pid: pid, bundleIdentifier: string(process, address(kAudioProcessPropertyBundleID)))
        }
    }

    /// Registers a listener that runs on the main queue. Returns a token for removal.
    ///
    /// This uses the function-pointer API, not the block one: a Swift closure is bridged to a new
    /// block each time it's passed, so `AudioObjectRemovePropertyListenerBlock` never matched and
    /// listeners piled up on every device change until the app spun at full CPU.
    @discardableResult
    static func listen(
        _ object: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        handler: @escaping @MainActor () -> Void
    ) -> Listener? {
        var address = address
        let context = ListenerContext(handler: handler)
        let pointer = Unmanaged.passRetained(context).toOpaque()
        guard AudioObjectAddPropertyListener(object, &address, audioListenerProc, pointer) == noErr else {
            Unmanaged<ListenerContext>.fromOpaque(pointer).release()
            return nil
        }
        return Listener(object: object, address: address, context: pointer)
    }

    final class Listener {
        let object: AudioObjectID
        let address: AudioObjectPropertyAddress
        private var context: UnsafeMutableRawPointer?

        init(object: AudioObjectID, address: AudioObjectPropertyAddress, context: UnsafeMutableRawPointer) {
            self.object = object
            self.address = address
            self.context = context
        }

        /// Safe to call more than once.
        func remove() {
            guard let context else { return }
            self.context = nil
            var address = address
            AudioObjectRemovePropertyListener(object, &address, audioListenerProc, context)
            Unmanaged<ListenerContext>.fromOpaque(context).release()
        }

        deinit { remove() }
    }
}

/// What a property listener calls. Core Audio and Core Media IO call listeners on their own
/// threads, so the handler is sent to the main queue.
final class ListenerContext: @unchecked Sendable {
    let handler: @MainActor () -> Void

    init(handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    func fire() {
        DispatchQueue.main.async { [self] in
            MainActor.assumeIsolated { handler() }
        }
    }
}

private func audioListenerProc(
    _ object: AudioObjectID,
    _ count: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ context: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context else { return noErr }
    Unmanaged<ListenerContext>.fromOpaque(context).takeUnretainedValue().fire()
    return noErr
}

extension AudioHW {
    /// The default output's volume, 0...1, when the device exposes a settable
    /// scalar. Falls back to the first two channels for devices without a
    /// main-element volume.
    static func outputVolume() -> Float? {
        let device = defaultOutputDevice()
        guard device != 0 else { return nil }
        let main = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput)
        if isSettable(device, main) {
            return value(device, main, default: Float(0.5))
        }
        let channels = [address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, element: 1),
                        address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, element: 2)]
        let values = channels.filter { isSettable(device, $0) }.map { value(device, $0, default: Float(0.5)) }
        return values.isEmpty ? nil : values.reduce(0, +) / Float(values.count)
    }

    static func setOutputVolume(_ volume: Float) {
        let device = defaultOutputDevice()
        guard device != 0 else { return }
        let clamped = min(max(volume, 0), 1)
        let main = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput)
        if isSettable(device, main) {
            var value = clamped
            var address = main
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float>.size), &value)
            return
        }
        for element in [1, 2] {
            let channel = address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, element: UInt32(element))
            guard isSettable(device, channel) else { continue }
            var value = clamped
            var address = channel
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float>.size), &value)
        }
    }

    static func outputMuted() -> Bool {
        let device = defaultOutputDevice()
        guard device != 0 else { return false }
        let mute = address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        guard isSettable(device, mute) else { return false }
        return value(device, mute, default: UInt32(0)) != 0
    }

    static func setOutputMuted(_ muted: Bool) {
        let device = defaultOutputDevice()
        guard device != 0 else { return }
        let mute = address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        guard isSettable(device, mute) else { return }
        var value: UInt32 = muted ? 1 : 0
        var address = mute
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    static func isSettable(_ device: AudioDeviceID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var settable: DarwinBoolean = false
        return AudioObjectHasProperty(device, &address)
            && AudioObjectIsPropertySettable(device, &address, &settable) == noErr
            && settable.boolValue
    }
}
