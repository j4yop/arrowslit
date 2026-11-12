import AppKit
import SwiftUI

/// Droppy-style floating capture card. The screenshot is the card; controls fade in on hover,
/// exactly like the reference. Copy, Save, Pin, Annotate, OCR and Close live around the image.
struct CaptureResultView: View {
    @Bindable var state: AppState
    let capture: CaptureService.Result
    var copiedText: String?

    let onClose: () -> Void

    @State private var appeared = false
    @State private var closing = false
    @State private var hovering = false
    @State private var controlsVisible = true
    @State private var status: String?
    @State private var hideTask: Task<Void, Never>?
    @State private var statusTask: Task<Void, Never>?

    private let cardWidth: CGFloat = 182
    private let cardHeight: CGFloat = 170
    private let margin: CGFloat = 12

    private var haptics: Bool { state.settings.hapticFeedback }

    var body: some View {
        ZStack {
            card
                .scaleEffect(appeared ? (closing ? 0.94 : 1) : 0.9)
                .opacity(appeared ? (closing ? 0 : 1) : 0)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        }
        .padding(margin)
        .frame(width: cardWidth + margin * 2, height: cardHeight + margin * 2)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                appeared = true
            }
            scheduleControlsHide(after: state.settings.captureAutoHideControls ? 2.8 : nil)
        }
        .onExitCommand(perform: dismiss)
    }

    private var card: some View {
        ZStack {
            Image(nsImage: capture.image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: cardWidth, height: cardHeight)
                .clipped()

            Color(red: 0.035, green: 0.075, blue: 0.135)
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: controlsVisible)

            if controlsVisible || status != nil {
                controls
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.86), lineWidth: 1.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onHover { inside in
            hovering = inside
            if inside {
                revealControls()
            } else {
                scheduleControlsHide(after: state.settings.captureAutoHideControls ? 0.9 : nil)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                circle("xmark", help: "Close") { dismiss() }
                Spacer(minLength: 0)
                circle("pin.fill", help: "Pin screenshot") { pin() }
            }

            Spacer(minLength: 0)

            VStack(spacing: 7) {
                if let status {
                    HStack(spacing: 5) {
                        Image(systemName: statusSymbol)
                            .font(.system(size: 10, weight: .bold))
                        Text(status)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(width: 100, height: 24)
                    .background(Capsule().fill(Color.white))
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
                } else {
                    pill("Copy", help: "Copy screenshot") { copy() }
                    pill("Save", help: "Save screenshot") { save() }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                circle("pencil", help: "Annotate") { edit() }
                Spacer(minLength: 0)
                circle("text.viewfinder", help: "Extract text") { ocr() }
            }
        }
        .padding(10)
        .frame(width: cardWidth, height: cardHeight)
    }

    private func circle(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        CaptureCircleButton(symbol: symbol, help: help, action: action)
    }

    private func pill(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        CapturePillButton(title: title, help: help, action: action)
    }

    // MARK: - Actions

    private func copy() {
        state.clipboard.suppressNextAlert()
        let board = NSPasteboard.general
        board.clearContents()
        if capture.mode == .text, let text = copiedText, !text.isEmpty {
            board.setString(text, forType: .string)
        } else {
            board.writeObjects([capture.image])
        }
        NookHaptics.perform(enabled: haptics)
        flash("Copied", closeAfter: 0.7)
    }

    private func save() {
        do {
            _ = try CaptureService().save(capture.image, to: state.settings.captureFolderURL)
            NookHaptics.perform(enabled: haptics)
            flash("Saved", closeAfter: 0.8)
        } catch {
            flash("Couldn't save", closeAfter: 1.0)
        }
    }

    private func pin() {
        NookHaptics.perform(enabled: haptics)
        dismiss()
        PinnedScreenshotWindowController.shared.show(image: capture.image, near: capture.screenRect)
    }

    private func edit() {
        NookHaptics.perform(enabled: haptics)
        dismiss()
        ScreenshotEditorWindowController(state: state, image: capture.image).show()
    }

    private func ocr() {
        do {
            let text = try CaptureService().recognizeText(in: capture.image)
            guard !text.isEmpty else {
                flash("No text found", closeAfter: nil)
                return
            }
            let board = NSPasteboard.general
            board.clearContents()
            board.setString(text, forType: .string)
            NookHaptics.perform(enabled: haptics)
            flash("Text copied", closeAfter: nil)
        } catch {
            flash("No text found", closeAfter: nil)
        }
    }

    private var statusSymbol: String {
        if status?.hasPrefix("No") == true || status?.hasPrefix("Couldn't") == true {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark"
    }

    private func flash(_ text: String, closeAfter: TimeInterval?) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) { status = text }
        statusTask?.cancel()
        statusTask = Task {
            try? await Task.sleep(for: .seconds(1.15))
            guard !Task.isCancelled else { return }
            if let closeAfter {
                try? await Task.sleep(for: .seconds(max(0, closeAfter - 0.45)))
                guard !Task.isCancelled else { return }
                dismiss()
            } else {
                withAnimation(.easeOut(duration: 0.18)) { status = nil }
                revealControls()
            }
        }
    }

    private func dismiss() {
        guard !closing else { return }
        hideTask?.cancel()
        statusTask?.cancel()
        withAnimation(.easeIn(duration: 0.16)) { closing = true }
        Task {
            try? await Task.sleep(for: .milliseconds(170))
            onClose()
        }
    }

    private func revealControls() {
        hideTask?.cancel()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            controlsVisible = true
        }
    }

    private func scheduleControlsHide(after delay: TimeInterval?) {
        hideTask?.cancel()
        guard state.settings.captureAutoHideControls, let delay else { return }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, !hovering, status == nil else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                controlsVisible = false
            }
        }
    }
}

private struct CaptureCircleButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white))
                .scaleEffect(hovering ? 1.1 : 1)
                .shadow(color: .black.opacity(hovering ? 0.3 : 0.12), radius: hovering ? 6 : 2, y: 1)
        }
        .buttonStyle(NookPressStyle())
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: hovering)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct CapturePillButton: View {
    let title: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.84))
                .frame(width: 80, height: 24)
                .background(Capsule().fill(Color.white))
                .scaleEffect(hovering ? 1.04 : 1)
                .shadow(color: .black.opacity(hovering ? 0.28 : 0.12), radius: hovering ? 6 : 2, y: 1)
        }
        .buttonStyle(NookPressStyle())
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: hovering)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Window

@MainActor
final class CaptureResultWindowController {
    private let state: AppState
    private let capture: CaptureService.Result
    private let copiedText: String?
    private var window: NSWindow?
    var onClose: (() -> Void)?

    private let contentSize = NSSize(width: 206, height: 194)

    init(state: AppState, capture: CaptureService.Result, copiedText: String?) {
        self.state = state
        self.capture = capture
        self.copiedText = copiedText
    }

    func show() {
        guard let screen = ScreenReader.screen(for: state.settings.displayChoice) ?? NSScreen.main else { return }
        let panel = FloatingShotWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = FirstMouseHostingView(rootView: CaptureResultView(
            state: state,
            capture: capture,
            copiedText: copiedText
        ) { [weak self] in
            self?.close()
        })

        let cardOrigin = origin(for: screen)
        let panelOrigin = NSPoint(x: cardOrigin.x - 12, y: cardOrigin.y - 12)
        panel.setFrame(NSRect(origin: panelOrigin, size: contentSize), display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        window = panel
    }

    func close() {
        window?.orderOut(nil)
        window = nil
        onClose?()
    }

    private func origin(for screen: NSScreen) -> NSPoint {
        let width: CGFloat = 182
        let height: CGFloat = 170

        if let rect = capture.screenRect {
            let main = NSScreen.screens.first?.frame ?? screen.frame
            let appKit = NSRect(
                x: main.minX + rect.minX,
                y: main.maxY - rect.maxY,
                width: rect.width,
                height: rect.height
            )
            let target = NSScreen.screens.first(where: { $0.frame.intersects(appKit) }) ?? screen
            let visible = target.visibleFrame
            var x = appKit.maxX - width - 14
            var y = appKit.minY + 14
            if appKit.width < width + 24 {
                x = appKit.midX - width / 2
            }
            if appKit.height < height + 24 {
                y = appKit.midY - height / 2
            }
            return NSPoint(
                x: min(max(x, visible.minX + 12), visible.maxX - width - 12),
                y: min(max(y, visible.minY + 12), visible.maxY - height - 12)
            )
        }

        let visible = screen.visibleFrame
        return NSPoint(
            x: visible.maxX - width - 22,
            y: visible.minY + 22
        )
    }
}

// MARK: - Pinned screenshots

@MainActor
final class PinnedScreenshotWindowController {
    static let shared = PinnedScreenshotWindowController()

    private var windows: [NSWindow] = []
    private init() {}

    func show(image: NSImage, near rect: CGRect?) {
        guard let screen = NSScreen.main else { return }
        let maxSize = NSSize(width: 560, height: 440)
        let scale = min(1, min(maxSize.width / max(1, image.size.width), maxSize.height / max(1, image.size.height)))
        let size = NSSize(
            width: max(120, image.size.width * scale),
            height: max(90, image.size.height * scale)
        )

        let panel = FloatingShotWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = PinnedScreenshotView(image: image) { [weak self, weak panel] in
            panel?.orderOut(nil)
            if let panel { self?.windows.removeAll { $0 === panel } }
        }
        panel.contentView = FirstMouseHostingView(rootView: view)

        var origin = NSPoint(
            x: screen.visibleFrame.maxX - size.width - 24,
            y: screen.visibleFrame.minY + 24
        )
        if let rect {
            let main = NSScreen.screens.first?.frame ?? screen.frame
            let appKit = NSRect(
                x: main.minX + rect.minX,
                y: main.maxY - rect.maxY,
                width: rect.width,
                height: rect.height
            )
            origin = NSPoint(
                x: min(max(appKit.midX - size.width / 2, screen.visibleFrame.minX + 12), screen.visibleFrame.maxX - size.width - 12),
                y: min(max(appKit.midY - size.height / 2, screen.visibleFrame.minY + 12), screen.visibleFrame.maxY - size.height - 12)
            )
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        windows.append(panel)
    }
}

private struct PinnedScreenshotView: View {
    let image: NSImage
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .overlay(alignment: .topTrailing) {
                if hovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.black.opacity(0.62)))
                    }
                    .buttonStyle(NookPressStyle())
                    .padding(9)
                    .transition(.opacity)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.white.opacity(hovering ? 0.28 : 0.14), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            .onHover { inside in
                withAnimation(.easeOut(duration: 0.15)) { hovering = inside }
            }
            .help("Drag to move · click × to close")
    }
}


/// Floating screenshot windows accept the first click without an activation click first, so the
/// Copy/Save/Pin controls work immediately after a capture.
private final class FloatingShotWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
