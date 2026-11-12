import AppKit
import SwiftUI

@MainActor
final class CaptureController {
    private let state: AppState
    private let service = CaptureService()
    private var overlay: CaptureOverlayWindowController?
    private var result: CaptureResultWindowController?

    init(state: AppState) {
        self.state = state
    }

    func start(_ mode: CaptureMode, screen: NSScreen? = nil) {
        let target = screen ?? ScreenReader.screen(for: state.settings.displayChoice) ?? NSScreen.main ?? NSScreen.screens[0]
        state.collapse()
        switch mode {
        case .fullscreen:
            do {
                let capture = try service.captureFullScreen(includeCursor: captureCursor)
                show(capture)
            } catch {
                present(error)
            }
        case .area, .text:
            let overlay = CaptureOverlayWindowController(screen: target, mode: .area, haptic: state.settings.hapticFeedback)
            self.overlay = overlay
            overlay.selectArea { [weak self] rect in
                guard let self else { return }
                self.overlay = nil
                do {
                    let capture = try self.service.capture(rect: rect, includeCursor: self.captureCursor)
                    if mode == .text {
                        let text = try self.service.recognizeText(in: capture.image)
                        if !text.isEmpty {
                            let board = NSPasteboard.general
                            board.clearContents()
                            board.setString(text, forType: .string)
                        }
                        self.show(capture, copiedText: text)
                    } else {
                        self.show(capture)
                    }
                } catch {
                    self.present(error)
                }
            }
        case .window:
            let overlay = CaptureOverlayWindowController(screen: target, mode: .window, haptic: state.settings.hapticFeedback)
            self.overlay = overlay
            overlay.selectWindow { [weak self] id in
                guard let self else { return }
                self.overlay = nil
                do {
                    let capture = try self.service.capture(windowID: id, includeCursor: self.captureCursor)
                    self.show(capture)
                } catch {
                    self.present(error)
                }
            }
        }
    }

    private var captureCursor: Bool { state.settings.captureIncludeCursor }
    private var copyAfterCapture: Bool { state.settings.captureCopy }

    private func show(_ capture: CaptureService.Result, copiedText: String? = nil) {
        if copyAfterCapture {
            state.clipboard.suppressNextAlert()
            if let copiedText {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(copiedText, forType: .string)
            } else {
                service.paste(capture.image)
            }
        }
        if state.settings.captureSound {
            playCaptureSound()
        }
        NookHaptics.perform(enabled: state.settings.hapticFeedback)
        let controller = CaptureResultWindowController(state: state, capture: capture, copiedText: copiedText)
        controller.onClose = { [weak self] in self?.result = nil }
        result = controller
        controller.show()
    }

    private func playCaptureSound() {
        let path = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSSound(contentsOf: URL(fileURLWithPath: path), byReference: true)?.play()
    }

    private func present(_ error: Error) {
        state.receive(.capture(kind: "Failed"))
        let alert = NSAlert()
        alert.messageText = "Couldn’t capture the screen"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

final class CaptureOverlayWindowController: NSWindowController, NSWindowDelegate {
    enum OverlayMode { case area, window }
    private let screen: NSScreen
    private let mode: OverlayMode
    private let haptic: Bool
    private var areaHandler: ((CGRect) -> Void)?
    private var windowHandler: ((CGWindowID) -> Void)?

    init(screen: NSScreen, mode: OverlayMode, haptic: Bool = false) {
        self.screen = screen
        self.mode = mode
        self.haptic = haptic
        let window = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self
        window.contentView = mode == .area
            ? SelectionView(frame: screen.frame, haptic: haptic, onSelect: { [weak self] rect in
                guard let self else { return }
                let global = self.globalRect(rect)
                let handler = self.areaHandler
                self.close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { handler?(global) }
            })
            : WindowPickerView(frame: screen.frame, onSelect: { [weak self] id in
                guard let self else { return }
                let handler = self.windowHandler
                self.close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { handler?(id) }
            })
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    required init?(coder: NSCoder) { fatalError() }

    func selectArea(_ handler: @escaping (CGRect) -> Void) {
        areaHandler = handler
    }

    func selectWindow(_ handler: @escaping (CGWindowID) -> Void) {
        windowHandler = handler
    }

    private func globalRect(_ rect: CGRect) -> CGRect {
        // screencapture's -R uses the main display's top-left coordinate space.
        let screenFrame = screen.frame
        let main = NSScreen.screens.first?.frame ?? screenFrame
        let x = screenFrame.minX + rect.minX - main.minX
        let y = main.maxY - (screenFrame.minY + rect.maxY)
        return CGRect(x: x, y: y, width: rect.width, height: rect.height)
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

private final class SelectionView: NSView {
    let onSelect: (CGRect) -> Void
    private let haptic: Bool
    private var start: CGPoint?
    private var current: CGPoint?

    init(frame: CGRect, haptic: Bool = false, onSelect: @escaping (CGRect) -> Void) {
        self.onSelect = onSelect
        self.haptic = haptic
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        NookHaptics.perform(enabled: haptic)
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width > 8, rect.height > 8 else {
            start = nil; current = nil; needsDisplay = true; return
        }
        NookHaptics.perform(enabled: haptic)
        onSelect(rect)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { window?.close() }
    }

    private var selectionRect: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(x: min(start.x, current.x), y: min(start.y, current.y),
                      width: abs(current.x - start.x), height: abs(current.y - start.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.34).setFill()
        bounds.fill()
        if let rect = selectionRect {
            NSColor.clear.setFill()
            rect.fill(using: .copy)
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1.5
            path.stroke()
            let label = "\(Int(rect.width)) × \(Int(rect.height))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            let size = (label as NSString).size(withAttributes: attributes)
            let point = CGPoint(x: rect.minX, y: rect.maxY + 6)
            NSColor.black.withAlphaComponent(0.72).setFill()
            NSBezierPath(roundedRect: CGRect(x: point.x, y: point.y, width: size.width + 12, height: size.height + 6), xRadius: 5, yRadius: 5).fill()
            (label as NSString).draw(at: CGPoint(x: point.x + 6, y: point.y + 3), withAttributes: attributes)
        } else {
            let text = "Drag to capture  ·  Esc to cancel"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.75),
            ]
            let size = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY + 30), withAttributes: attributes)
        }
    }
}

private final class WindowPickerView: NSView {
    let onSelect: (CGWindowID) -> Void
    private var windows: [(id: CGWindowID, rect: CGRect, owner: String, title: String)] = []
    private var hovered: Int?

    init(frame: CGRect, onSelect: @escaping (CGWindowID) -> Void) {
        self.onSelect = onSelect
        super.init(frame: frame)
        wantsLayer = true
        loadWindows()
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways], owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    private func loadWindows() {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for item in list {
            guard let id = item[kCGWindowNumber as String] as? CGWindowID,
                  let layer = item[kCGWindowLayer as String] as? Int, layer == 0,
                  let owner = item[kCGWindowOwnerName as String] as? String,
                  owner != "Arrowslit",
                  let dict = item[kCGWindowBounds as String] as? [String: Any] else { continue }
            var rect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(dict as CFDictionary, &rect) else { continue }
            let title = item[kCGWindowName as String] as? String ?? ""
            windows.append((id, rect, owner, title))
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let ordered = windows.enumerated()
            .filter { $0.element.rect.contains(point) }
            .sorted { $0.element.rect.width * $0.element.rect.height < $1.element.rect.width * $1.element.rect.height }
        hovered = ordered.first?.offset
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard let hovered else { return }
        onSelect(windows[hovered].id)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()
        if let hovered {
            let window = windows[hovered]
            NSColor.white.setStroke()
            let path = NSBezierPath(rect: window.rect.insetBy(dx: 1, dy: 1))
            path.lineWidth = 2
            path.stroke()
            let label = window.title.isEmpty ? window.owner : "\(window.owner) — \(window.title)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            let size = (label as NSString).size(withAttributes: attributes)
            let point = CGPoint(x: window.rect.minX + 8, y: window.rect.maxY + 6)
            NSColor.black.withAlphaComponent(0.75).setFill()
            NSBezierPath(roundedRect: CGRect(x: point.x, y: point.y, width: size.width + 14, height: size.height + 7), xRadius: 6, yRadius: 6).fill()
            (label as NSString).draw(at: CGPoint(x: point.x + 7, y: point.y + 3), withAttributes: attributes)
        }
        let text = "Move over a window and click to capture  ·  Esc to cancel"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75),
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        (text as NSString).draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY + 30), withAttributes: attributes)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { window?.close() }
    }
}

private extension NSBezierPath {
    func fill(using operation: NSCompositingOperation) {
        NSGraphicsContext.current?.compositingOperation = operation
        fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
}
