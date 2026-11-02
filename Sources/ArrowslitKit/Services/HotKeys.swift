import Carbon
import Foundation

/// The ⌃⌥ launcher shortcuts, registered with Carbon so they work from any app without
/// requiring Accessibility. They are released when the feature is turned off or the app quits.
@MainActor
public final class HotKeys {
    public var onPress: ((WorkbenchTab) -> Void)?
    public var onVorssaintPress: ((VorssaintPage) -> Void)?

    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    fileprivate static weak var current: HotKeys?

    public init() {}

    public var isRegistered: Bool { !refs.isEmpty }

    public func register() {
        guard refs.isEmpty else { return }
        HotKeys.current = self
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &spec, nil, &handler)
        }
        for (index, tab) in Self.items.enumerated() {
            guard let key = tab.shortcutKey, let code = Self.keyCode(key) else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index))
            let status = RegisterEventHotKey(code, UInt32(controlKey | optionKey), id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) }
        }
        for (index, page) in Self.vorssaintItems.enumerated() {
            guard let code = Self.keyCode(Character(page.shortcutKey)) else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(100 + index))
            let status = RegisterEventHotKey(code, UInt32(optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { refs.append(ref) }
        }
    }

    public func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }

    fileprivate func pressed(_ index: Int) {
        if index >= 100 {
            let pageIndex = index - 100
            guard Self.vorssaintItems.indices.contains(pageIndex) else { return }
            onVorssaintPress?(Self.vorssaintItems[pageIndex])
            return
        }
        guard Self.items.indices.contains(index) else { return }
        onPress?(Self.items[index])
    }

    /// Stable order for the Carbon IDs; the launcher uses the same tabs.
    static let items: [WorkbenchTab] = [
        .nowPlaying, .timer, .stopwatch, .calendar, .sports, .reminders,
        .clipboard, .tray, .notes, .mirror, .keepAwake, .stats,
    ]

    /// Vorssaint's page shortcuts use Option-Command, so they do not collide
    /// with Arrowslit's existing Control-Option shortcuts.
    static let vorssaintItems: [VorssaintPage] = VorssaintPage.allCases

    private static let signature: OSType = 0x4152_534C // "ARSL"

    nonisolated static func keyCode(_ key: Character) -> UInt32? {
        let codes: [Character: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "F": kVK_ANSI_F, "G": kVK_ANSI_G, "I": kVK_ANSI_I, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T, "V": kVK_ANSI_V,
            "W": kVK_ANSI_W, "Z": kVK_ANSI_Z,
        ]
        return codes[key].map { UInt32($0) }
    }
}

/// Carbon calls this on the main thread.
private func hotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    guard status == noErr else { return status }
    let index = Int(id.id)
    MainActor.assumeIsolated { HotKeys.current?.pressed(index) }
    return noErr
}
