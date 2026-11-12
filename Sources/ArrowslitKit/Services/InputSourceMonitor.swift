import Carbon
import Foundation
import Observation

/// Reports keyboard layout changes, the way the notch shows them.
@MainActor
@Observable
public final class InputSourceMonitor {
    public private(set) var code = ""
    public private(set) var name = ""

    @ObservationIgnored public var onChange: ((String, String) -> Void)?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var currentID: String?
    @ObservationIgnored private var primed = false

    public init() {}

    public func start() {
        guard observer == nil else { return }
        let reading = Self.reading()
        code = reading.code
        name = reading.name
        currentID = reading.id
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.changed() }
        }
        // A notification can arrive while the app is still launching. Let
        // that pass settle the baseline instead of flashing a HUD.
        primed = false
        DispatchQueue.main.async { [weak self] in self?.primed = true }
    }

    public func stop() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observer = nil
        currentID = nil
    }

    private func changed() {
        let reading = Self.reading()
        guard reading.id != currentID else { return }
        currentID = reading.id
        guard primed else { return }
        code = reading.code
        name = reading.name
        guard !reading.code.isEmpty else { return }
        onChange?(reading.code, reading.name)
    }

    private nonisolated static func reading() -> (id: String, code: String, name: String) {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return ("", "", "")
        }
        let id = value(source, kTISPropertyInputSourceID) ?? ""
        let localized = value(source, kTISPropertyLocalizedName) ?? ""
        let code: String
        if let last = id.split(separator: ".").last {
            code = String(last).uppercased()
        } else {
            code = localized.isEmpty ? "Keyboard" : localized
        }
        return (id.isEmpty ? localized : id, code, localized.isEmpty ? code : localized)
    }

    private nonisolated static func value(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
