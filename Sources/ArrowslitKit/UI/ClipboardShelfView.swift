import AppKit
import SwiftUI

struct ClipboardShelfView: View {
    @Bindable var state: AppState
    let onClose: () -> Void
    @State private var query = ""
    @State private var searching = false
    @State private var hoveringID: UUID?
    @FocusState private var searchFocused: Bool

    private var entries: [ClipboardEntry] {
        query.isEmpty ? state.clipboard.entries : state.clipboard.matching(query)
    }

    private var haptics: Bool { state.settings.hapticFeedback }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .frame(height: 56)
            if entries.isEmpty {
                empty
            } else {
                shelf
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                ArrowVisualEffect(material: .hudWindow)
                Color.arrowPanelTint
            }
        }
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 24,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 24,
            style: .continuous
        ))
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24,
                style: .continuous
            )
            .strokeBorder(Color.arrowStroke, lineWidth: 0.5)
        }
        .onExitCommand {
            if searching {
                query = ""
                searching = false
                searchFocused = false
            } else {
                onClose()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.frontmostApplication?.icon
                ?? NSImage(named: NSImage.applicationIconName)
                ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Spacer(minLength: 0)

            if searching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.arrowSecondaryText)
                    TextField("Search clips", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.arrowText)
                        .focused($searchFocused)
                        .frame(width: 210)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            query = ""
                            searching = false
                            searchFocused = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.arrowSecondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 11)
                .frame(height: 32)
                .background(Color.arrowPill, in: Capsule())
            } else {
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { searching = true }
                        searchFocused = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.arrowSecondaryText)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(NookPressStyle())
                    .help("Search clips")

                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Clipboard")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.arrowText.opacity(0.82))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.arrowPill, in: Capsule())

                    Button {
                        NookHaptics.perform(enabled: haptics)
                        state.expand(.clipboard)
                        onClose()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.arrowSecondaryText)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(NookPressStyle())
                    .help("Open the clipboard page")
                }
            }

            Spacer(minLength: 0)

            Menu {
                Button("Clipboard Settings…") {
                    state.onOpenSettings?()
                    onClose()
                }
                Divider()
                Button("Clear except pinned") {
                    state.clipboard.clear()
                    NookHaptics.perform(enabled: haptics)
                }
                .disabled(state.clipboard.entries.allSatisfy(\.isPinned))
                Button("Clear history", role: .destructive) {
                    state.clipboard.clearIncludingPinned()
                    NookHaptics.perform(enabled: haptics)
                }
                .disabled(state.clipboard.entries.isEmpty)
                Divider()
                Button("Close Shelf") { onClose() }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(Color.arrowSecondaryText)
                .frame(width: 34, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 34)
        }
    }

    private var shelf: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 16) {
                ForEach(entries) { entry in
                    ClipboardShelfCard(
                        state: state,
                        entry: entry,
                        haptics: haptics,
                        hovering: hoveringID == entry.id,
                        copied: state.clipboard.lastCopiedID == entry.id,
                        onHover: { hovering in
                            hoveringID = hovering ? entry.id : (hoveringID == entry.id ? nil : hoveringID)
                        },
                        onOpenSettings: {
                            state.onOpenSettings?()
                            onClose()
                        },
                        onClose: onClose
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.arrowTertiaryText)
            Text("Nothing copied yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.arrowSecondaryText)
            Text("Text, images and files you copy will wait here.")
                .font(.system(size: 11))
                .foregroundStyle(Color.arrowTertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardShelfCard: View {
    @Bindable var state: AppState
    let entry: ClipboardEntry
    let haptics: Bool
    let hovering: Bool
    let copied: Bool
    let onHover: (Bool) -> Void
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    @State private var image: NSImage?
    @State private var imageMissing = false
    @State private var message: String?

    private let cardWidth: CGFloat = 232
    private let cardHeight: CGFloat = 204

    var body: some View {
        VStack(spacing: 7) {
            header
            content
            footer
        }
        .padding(10)
        .frame(width: cardWidth, height: cardHeight)
        .background {
            if entry.kind == .image {
                Checkerboard()
            } else {
                Color.arrowShelfCard
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    entry.kind == .image ? Color.arrowImageFrame.opacity(hovering || copied ? 1 : 0.8) : Color.arrowStroke,
                    lineWidth: entry.kind == .image ? (hovering || copied ? 2 : 1.2) : 0.5
                )
        }
        .shadow(
            color: copied ? Color.arrowGlow.opacity(0.38) : (hovering ? .black.opacity(0.35) : .clear),
            radius: copied ? 14 : 9,
            y: 3
        )
        .scaleEffect(hovering ? 1.012 : 1)
        .animation(.easeOut(duration: 0.16), value: hovering)
        .animation(.easeOut(duration: 0.2), value: copied)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onHover(perform: onHover)
        .onTapGesture { copy() }
        .onDrag {
            NookHaptics.perform(enabled: haptics)
            return dragProvider()
        }
        .task(id: entry.id) {
            guard entry.kind == .image else { return }
            image = state.clipboard.image(for: entry)
            imageMissing = image == nil
        }
        .help(entry.kind == .image ? "Click to copy the image" : "Click to copy")
        .accessibilityLabel("Copy \(entry.kind.title)")
    }

    private var header: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                sourceIcon
                Text(entry.kind.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text("·")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.28))
                Text(age(entry.copiedAt))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.46))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Capsule().fill(Color.white))
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

            Spacer(minLength: 0)

            Menu {
                Button("Copy") { copy() }
                if entry.kind == .image {
                    Button("Edit Image…") { editImage() }
                    Button("Extract Text") { extractText() }
                }
                Button("Save to Downloads") { save() }
                Divider()
                Button(entry.isPinned ? "Unpin" : "Pin") { togglePin() }
                Button("Delete", role: .destructive) { delete() }
                Divider()
                Button("Clipboard Settings…", action: onOpenSettings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white))
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28)
        }
    }

    private var sourceIcon: some View {
        Group {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == entry.appName }),
               let icon = app.icon {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Image(systemName: entry.kind.symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.5))
            }
        }
        .frame(width: 16, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    @ViewBuilder private var content: some View {
        switch entry.kind {
        case .text:
            Text(entry.text)
                .font(.system(size: 14))
                .foregroundStyle(Color.arrowText)
                .lineLimit(5)
                .lineSpacing(1)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .url:
            Image(systemName: "link")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.arrowTertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .image:
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 26, weight: .medium))
                        Text(imageMissing ? "Image unavailable" : "")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color.arrowTertiaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .file:
            VStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(Color.arrowText.opacity(0.9))
                Text(FileManager.default.fileExists(atPath: entry.filePath ?? "") ? "" : "File unavailable")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.arrowTertiaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .clip:
            ZStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.arrowTertiaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var footer: some View {
        if let message {
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.arrowSecondaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 14)
        } else {
            footerContent
        }
    }

    @ViewBuilder private var footerContent: some View {
        switch entry.kind {
        case .text:
            Text("\(entry.characterCount.formatted()) characters")
                .font(.system(size: 11))
                .foregroundStyle(Color.arrowShelfMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 14)
        case .url:
            Text(entry.text)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.arrowSecondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 14)
        case .image:
            Text(dimensions)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 20)
                .background(Capsule().fill(Color.black.opacity(0.62)))
                .frame(maxWidth: .infinity)
                .frame(height: 18)
        case .file:
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.text)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.arrowSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(fileExtension)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Color.arrowTertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 22)
        case .clip:
            Text("Preview unavailable")
                .font(.system(size: 11))
                .foregroundStyle(Color.arrowShelfMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 14)
        }
    }

    private var dimensions: String {
        guard let width = entry.imageWidth, let height = entry.imageHeight else { return "Image" }
        return "\(width) × \(height)"
    }

    private var fileExtension: String {
        guard let path = entry.filePath else { return "FILE" }
        let ext = URL(fileURLWithPath: path).pathExtension
        return ext.isEmpty ? "FILE" : ext.uppercased()
    }

    private func copy() {
        state.clipboard.copy(entry)
        NookHaptics.perform(enabled: haptics)
    }

    private func togglePin() {
        state.clipboard.togglePin(entry)
        NookHaptics.perform(enabled: haptics)
    }

    private func delete() {
        state.clipboard.remove(entry.id)
        NookHaptics.perform(enabled: haptics)
    }

    private func editImage() {
        guard let image = state.clipboard.image(for: entry) else { return }
        ScreenshotEditorWindowController(state: state, image: image).show()
        onClose()
    }

    private func extractText() {
        guard let image = state.clipboard.image(for: entry) else { return }
        do {
            let text = try CaptureService().recognizeText(in: image)
            guard !text.isEmpty else {
                flash("No text found")
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            flash("Text copied")
            NookHaptics.perform(enabled: haptics)
        } catch {
            flash("Couldn’t read text")
        }
    }

    private func save() {
        let directory = state.settings.downloadsFolderURL
        do {
            switch entry.kind {
            case .image:
                guard let image = state.clipboard.image(for: entry) else { return }
                _ = try CaptureService().save(image, to: directory)
            case .file:
                guard let path = entry.filePath else { return }
                let destination = directory.appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: destination)
            case .text, .url, .clip:
                let name = "Clip-\(Int(Date().timeIntervalSince1970)).txt"
                try entry.text.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
            }
            flash("Saved")
            NookHaptics.perform(enabled: haptics)
        } catch {
            flash("Couldn’t save")
        }
    }

    private func flash(_ text: String) {
        message = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if message == text { message = nil }
        }
    }

    private func dragProvider() -> NSItemProvider {
        switch entry.kind {
        case .image:
            if let image = state.clipboard.image(for: entry) {
                return NSItemProvider(object: image)
            }
            return NSItemProvider(object: entry.previewText as NSString)
        case .file:
            if let path = entry.filePath, let provider = NSItemProvider(contentsOf: URL(fileURLWithPath: path)) {
                return provider
            }
            return NSItemProvider(object: entry.text as NSString)
        case .text, .url, .clip:
            return NSItemProvider(object: entry.text as NSString)
        }
    }

    private func age(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds) sec ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return hours == 1 ? "1 hr ago" : "\(hours) hr ago" }
        let days = hours / 24
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }
}

private struct Checkerboard: View {
    var square: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / square))
            let rows = Int(ceil(size.height / square))
            for row in 0..<rows {
                for column in 0..<columns {
                    let rect = CGRect(
                        x: CGFloat(column) * square,
                        y: CGFloat(row) * square,
                        width: square,
                        height: square
                    )
                    context.fill(
                        Path(rect),
                        with: .color((row + column).isMultiple(of: 2) ? .arrowCheckerLight : .arrowCheckerDark)
                    )
                }
            }
        }
        .background(Color.arrowCheckerDark)
    }
}

@MainActor
final class ClipboardShelfWindowController {
    private let state: AppState
    private var window: NSPanel?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        close()
        guard let screen = ScreenReader.screen(for: state.settings.displayChoice) ?? NSScreen.main else { return }
        let width = max(600, screen.frame.width - 24)
        let height: CGFloat = 340
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.minY,
            width: width,
            height: height
        )
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .statusBar
        panel.contentView = NSHostingView(rootView: ClipboardShelfView(state: state) { [weak self] in
            self?.close()
        })
        let start = NSRect(x: frame.origin.x, y: frame.origin.y - 46, width: frame.width, height: frame.height)
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.26
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
        NookHaptics.perform(enabled: state.settings.hapticFeedback)
        window = panel
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
