import CoreAudio
import Foundation
import Observation

/// Mutes the Mac's microphone for every app at once (Zoom, Meet, FaceTime...). Uses the input
/// device's own mute switch when it has one; otherwise turns its input volume to zero and puts it
/// back afterwards.
@MainActor
@Observable
public final class MicrophoneMute {
    public private(set) var isMuted = false
    /// False when the current input device can't be muted or turned down.
    public private(set) var canMute = false

    @ObservationIgnored private var device: AudioDeviceID = 0
    @ObservationIgnored private var deviceListener: AudioHW.Listener?
    @ObservationIgnored private var muteListener: AudioHW.Listener?
    /// Volume to restore, when muting had to turn the volume down instead.
    @ObservationIgnored private var savedVolume: Float32?

    public init() {}

    public func start() {
        guard deviceListener == nil else { return }
        deviceListener = AudioHW.listen(AudioHW.system, AudioHW.address(kAudioHardwarePropertyDefaultInputDevice)) { [weak self] in
            self?.attach()
        }
        attach()
    }

    public func stop() {
        // Never leave someone muted after quitting.
        if isMuted { setMuted(false) }
        deviceListener?.remove()
        deviceListener = nil
        muteListener?.remove()
        muteListener = nil
    }

    public func toggle() {
        setMuted(!isMuted)
    }

    public func setMuted(_ muted: Bool) {
        guard device != 0 else { return }
        if Self.isSettable(device, Self.muteAddress) {
            var value: UInt32 = muted ? 1 : 0
            var address = Self.muteAddress
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        } else if Self.isSettable(device, Self.volumeAddress) {
            if muted {
                savedVolume = AudioHW.value(device, Self.volumeAddress, default: Float32(1))
                Self.setVolume(device, 0)
            } else {
                Self.setVolume(device, savedVolume ?? 1)
                savedVolume = nil
            }
        } else {
            return
        }
        refresh()
    }

    private func attach() {
        muteListener?.remove()
        muteListener = nil
        savedVolume = nil
        device = AudioHW.value(AudioHW.system, AudioHW.address(kAudioHardwarePropertyDefaultInputDevice), default: AudioDeviceID(0))
        if Self.isSettable(device, Self.muteAddress) {
            muteListener = AudioHW.listen(device, Self.muteAddress) { [weak self] in self?.refresh() }
        }
        refresh()
    }

    private func refresh() {
        canMute = device != 0 && (Self.isSettable(device, Self.muteAddress) || Self.isSettable(device, Self.volumeAddress))
        if Self.isSettable(device, Self.muteAddress) {
            let value: UInt32 = AudioHW.value(device, Self.muteAddress, default: 0)
            isMuted = value != 0
        } else {
            isMuted = savedVolume != nil
        }
    }

    private static let muteAddress = AudioHW.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeInput)
    private static let volumeAddress = AudioHW.address(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeInput)

    private static func isSettable(_ device: AudioDeviceID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(device, &address),
              AudioObjectIsPropertySettable(device, &address, &settable) == noErr else { return false }
        return settable.boolValue
    }

    private static func setVolume(_ device: AudioDeviceID, _ volume: Float32) {
        var value = volume
        var address = volumeAddress
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }
}
