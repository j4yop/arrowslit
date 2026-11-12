import AppKit
import SwiftUI

private enum ShotTool: String, CaseIterable, Identifiable {
    case select, arrow, line, rectangle, ellipse, freehand, text
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .freehand: "scribble"
        case .text: "textformat"
        }
    }
}

private struct ShotMark: Identifiable {
    let id = UUID()
    var tool: ShotTool
    var start: CGPoint
    var end: CGPoint
    var points: [CGPoint] = []
    var colorIndex: Int = 0
    var text = "Text"
}

private let shotColors: [Color] = [.white, .red, .yellow, .blue, .green, .orange]

struct ScreenshotEditorView: View {
    @Bindable var state: AppState
    let image: NSImage
    let onClose: () -> Void

    @State private var tool: ShotTool = .arrow
    @State private var colorIndex = 0
    @State private var marks: [ShotMark] = []
    @State private var current: ShotMark?
    @State private var message: String?

    private var haptics: Bool { state.settings.hapticFeedback }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            GeometryReader { proxy in
                let rect = imageRect(in: proxy.size)
                ZStack {
                    Color.black
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                    Canvas { context, _ in
                        for mark in marks { draw(mark, in: context, rect: rect) }
                        if let current { draw(current, in: context, rect: rect) }
                    }
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let point = imagePoint(value.location, rect: rect)
                                    if current == nil {
                                        current = ShotMark(tool: tool, start: imagePoint(value.startLocation, rect: rect), end: point, colorIndex: colorIndex)
                                    }
                                    current?.end = point
                                    current?.points.append(point)
                                }
                                .onEnded { value in
                                    guard var mark = current else { return }
                                    if mark.tool == .text {
                                        let point = imagePoint(value.location, rect: rect)
                                        mark.start = point
                                        mark.end = point
                                    }
                                    marks.append(mark)
                                    current = nil
                                    NookHaptics.perform(enabled: haptics)
                                }
                        )
                }
            }
            status
        }
        .frame(width: 820, height: 620)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onExitCommand(perform: onClose)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            toolbarButton("xmark", "Close", .plain) { onClose() }
            Text("Edit screenshot")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            ForEach(ShotTool.allCases) { item in
                toolbarButton(item.symbol, item.rawValue.capitalized, tool == item ? .selected : .plain) {
                    tool = item
                }
            }
            Divider().frame(height: 18).overlay(.white.opacity(0.15))
            ForEach(shotColors.indices, id: \.self) { index in
                Button {
                    colorIndex = index
                } label: {
                    Circle()
                        .fill(shotColors[index])
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white.opacity(colorIndex == index ? 0.9 : 0.15), lineWidth: colorIndex == index ? 1.5 : 0.5))
                }
                .buttonStyle(.plain)
            }
            Divider().frame(height: 18).overlay(.white.opacity(0.15))
            toolbarButton("arrow.uturn.backward", "Undo", .plain) {
                if !marks.isEmpty { marks.removeLast() }
            }
            toolbarButton("doc.on.doc", "Copy", .plain) { copy() }
            toolbarButton("square.and.arrow.down", "Save", .plain) { save() }
            toolbarButton("checkmark", "Done", .accent) { copyAndClose() }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color(white: 0.09))
    }

    private var status: some View {
        HStack {
            Text(message ?? "\(marks.count) annotation\(marks.count == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color(white: 0.07))
    }

    private enum ButtonKind { case plain, selected, accent }

    private func toolbarButton(_ symbol: String, _ help: String, _ kind: ButtonKind, action: @escaping () -> Void) -> some View {
        Button {
            action()
            NookHaptics.perform(enabled: haptics)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(kind == .selected ? .black : (kind == .accent ? .black : .white.opacity(0.7)))
                .frame(width: kind == .accent ? 42 : 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(kind == .selected ? Color.white : (kind == .accent ? ArrowTheme.amber : Color.white.opacity(0.08)))
                )
        }
        .buttonStyle(NookPressStyle())
        .help(help)
    }

    private func imageRect(in size: CGSize) -> CGRect {
        let scale = min(size.width / max(1, image.size.width), size.height / max(1, image.size.height))
        let width = image.size.width * scale
        let height = image.size.height * scale
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func imagePoint(_ point: CGPoint, rect: CGRect) -> CGPoint {
        guard rect.width > 0, rect.height > 0 else { return point }
        return CGPoint(
            x: (point.x - rect.minX) / rect.width * image.size.width,
            y: (point.y - rect.minY) / rect.height * image.size.height
        )
    }

    private func draw(_ mark: ShotMark, in context: GraphicsContext, rect: CGRect) {
        let color = shotColors[min(mark.colorIndex, shotColors.count - 1)]
        var path = Path()
        let a = CGPoint(x: rect.minX + mark.start.x * rect.width / max(1, image.size.width),
                        y: rect.minY + mark.start.y * rect.height / max(1, image.size.height))
        let b = CGPoint(x: rect.minX + mark.end.x * rect.width / max(1, image.size.width),
                        y: rect.minY + mark.end.y * rect.height / max(1, image.size.height))
        switch mark.tool {
        case .arrow:
            path.move(to: a); path.addLine(to: b)
            let angle = atan2(b.y - a.y, b.x - a.x)
            let head: CGFloat = 10
            path.move(to: b)
            path.addLine(to: CGPoint(x: b.x - head * cos(angle - .pi / 7), y: b.y - head * sin(angle - .pi / 7)))
            path.move(to: b)
            path.addLine(to: CGPoint(x: b.x - head * cos(angle + .pi / 7), y: b.y - head * sin(angle + .pi / 7)))
        case .line:
            path.move(to: a); path.addLine(to: b)
        case .rectangle:
            path.addRect(CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)))
        case .ellipse:
            path.addEllipse(in: CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y)))
        case .freehand:
            let points = mark.points.map { CGPoint(x: rect.minX + $0.x * rect.width / max(1, image.size.width),
                                                   y: rect.minY + $0.y * rect.height / max(1, image.size.height)) }
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        case .text:
            let text = Text(mark.text).font(.system(size: 16, weight: .semibold)).foregroundColor(color)
            context.draw(text, at: a, anchor: .topLeading)
            return
        case .select:
            return
        }
        context.stroke(path, with: .color(color), lineWidth: 3)
    }

    private func render() -> NSImage {
        let result = NSImage(size: image.size)
        result.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: image.size))
        for mark in marks {
            let color = NSColor(shotColors[min(mark.colorIndex, shotColors.count - 1)]).usingColorSpace(.deviceRGB) ?? .white
            color.setStroke()
            let a = CGPoint(x: mark.start.x, y: image.size.height - mark.start.y)
            let b = CGPoint(x: mark.end.x, y: image.size.height - mark.end.y)
            switch mark.tool {
            case .arrow, .line:
                let path = NSBezierPath()
                path.move(to: a); path.line(to: b)
                if mark.tool == .arrow {
                    let angle = atan2(b.y - a.y, b.x - a.x)
                    path.move(to: b)
                    path.line(to: CGPoint(x: b.x - 10 * cos(angle - .pi / 7), y: b.y - 10 * sin(angle - .pi / 7)))
                    path.move(to: b)
                    path.line(to: CGPoint(x: b.x - 10 * cos(angle + .pi / 7), y: b.y - 10 * sin(angle + .pi / 7)))
                }
                path.lineWidth = 3
                path.stroke()
            case .rectangle, .ellipse:
                let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
                let path = mark.tool == .rectangle ? NSBezierPath(rect: rect) : NSBezierPath(ovalIn: rect)
                path.lineWidth = 3
                path.stroke()
            case .freehand:
                let path = NSBezierPath()
                let points = mark.points.map { CGPoint(x: $0.x, y: image.size.height - $0.y) }
                guard let first = points.first else { break }
                path.move(to: first)
                for point in points.dropFirst() { path.line(to: point) }
                path.lineWidth = 3
                path.stroke()
            case .text:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: color,
                ]
                (mark.text as NSString).draw(at: a, withAttributes: attrs)
            case .select: break
            }
        }
        result.unlockFocus()
        return result
    }

    private func copy() {
        let board = NSPasteboard.general
        board.clearContents()
        board.writeObjects([render()])
        flash("Copied")
    }

    private func save() {
        let directory = state.settings.captureFolderURL
        do {
            _ = try CaptureService().save(render(), to: directory)
            flash("Saved to \(directory.lastPathComponent)")
        } catch {
            flash("Could not save")
        }
    }

    private func copyAndClose() {
        copy()
        onClose()
    }

    private func flash(_ text: String) {
        message = text
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if message == text { message = nil }
        }
    }
}

@MainActor
final class ScreenshotEditorWindowController: NSWindowController, NSWindowDelegate {
    private let state: AppState
    private let image: NSImage
    private var closeHandler: (() -> Void)?

    init(state: AppState, image: NSImage) {
        self.state = state
        self.image = image
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "Edit screenshot"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
        window.isOpaque = true
        window.center()
        window.delegate = self
        window.contentView = NSHostingView(rootView: ScreenshotEditorView(state: state, image: image) { [weak self] in
            self?.close()
        })
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        closeHandler?()
    }
}
