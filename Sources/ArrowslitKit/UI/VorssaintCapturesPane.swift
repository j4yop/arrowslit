import AppKit
import SwiftUI

/// Vorssaint's Recent captures: a two-by-two grid of screenshots and
/// recordings, each with its thumbnail, age and restore/open actions.
struct VorssaintCapturesPane: View {
    @Bindable var state: AppState
    @State private var captures: [URL] = []
    @State private var busy = false
    @State private var error: String?

    private var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/Arrowslit Captures", isDirectory: true)
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Text("\(captures.count) capture\(captures.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer()
                Button {
                    capture(area: true)
                } label: {
                    Label("Capture area", systemImage: "viewfinder")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VorssaintTheme.orange)
                }
                .buttonStyle(.plain)
                Button {
                    capture(area: false)
                } label: {
                    Label("Screen", systemImage: "rectangle.dashed")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
            .frame(height: 18)
            .disabled(busy)

            if captures.isEmpty {
                VorssaintPageEmpty(
                    symbol: "camera.viewfinder",
                    title: "No captures yet",
                    detail: "Capture an area or the whole screen. Files stay on this Mac."
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                              spacing: 8) {
                        ForEach(captures.prefix(8), id: \.self) { url in
                            card(url)
                        }
                    }
                }
            }
        }
        .padding(.top, 1)
        .onAppear { reload() }
    }

    private func card(_ url: URL) -> some View {
        let image = NSImage(contentsOf: url)
        let title = url.pathExtension.lowercased() == "mov" ? "Recording" : "Screenshot"
        return HStack(spacing: 9) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(colors: [VorssaintTheme.pink, VorssaintTheme.purple],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(width: 84, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                Text(age(url))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text("Restore")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.82))
                            .padding(.horizontal, 11)
                            .frame(height: 22)
                            .background(Capsule().fill(.white.opacity(0.92)))
                    }
                    .buttonStyle(NookPressStyle(pressedScale: 0.95))
                    Button {
                        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                        reload()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.white.opacity(0.09)))
                    }
                    .buttonStyle(NookPressStyle(pressedScale: 0.95))
                    .help("Move to Trash")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func age(_ url: URL) -> String {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func reload() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        captures = files
            .filter { ["png", "jpg", "jpeg", "mov", "mp4"].contains($0.pathExtension.lowercased()) }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
    }

    private func capture(area: Bool) {
        guard !busy else { return }
        busy = true
        error = nil
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(date: .numeric, time: .standard)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let name = "Arrowslit \(stamp).png"
        let url = folder.appendingPathComponent(name)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = area ? ["-i", "-x", url.path] : ["-x", url.path]
        process.terminationHandler = { proc in
            DispatchQueue.main.async {
                busy = false
                if proc.terminationStatus == 0 {
                    reload()
                    NookHaptics.perform(enabled: state.settings.hapticFeedback)
                } else {
                    error = "Capture cancelled"
                }
            }
        }
        do {
            try process.run()
        } catch {
            busy = false
            self.error = "Could not start screencapture"
        }
    }
}
