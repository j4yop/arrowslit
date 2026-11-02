import AppKit
import SwiftUI

struct VorssaintCapturesPane: View {
    @Bindable var state: AppState
    @State private var captures: [URL] = []
    @State private var latest: NSImage?
    @State private var busy = false
    @State private var error: String?

    private var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/Arrowslit Captures", isDirectory: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PaneHeader("Recent captures") {
                HStack(spacing: 6) {
                    Button { capture(area: true) } label: {
                        Label("Capture area", systemImage: "viewfinder")
                    }
                    Button { capture(area: false) } label: {
                        Label("Screen", systemImage: "rectangle.dashed")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ArrowTheme.amber)
                .disabled(busy)
            }

            if let latest {
                HStack(alignment: .top, spacing: 10) {
                    Image(nsImage: latest)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Latest capture")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                        Text(folder.lastPathComponent)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.4))
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([captures.first ?? folder])
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                    }
                    .frame(width: 145, alignment: .leading)
                }
                .frame(maxHeight: 126)
            } else {
                VorssaintPageEmpty(
                    symbol: "camera.viewfinder",
                    title: "No captures yet",
                    detail: "Capture an area or the whole screen. Files stay on this Mac."
                )
                .frame(maxHeight: 120)
            }

            HStack(spacing: 6) {
                ForEach(captures.prefix(5), id: \.self) { url in
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        if let image = NSImage(contentsOf: url) {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 42, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        } else {
                            Image(systemName: "photo")
                                .frame(width: 42, height: 30)
                        }
                    }
                    .buttonStyle(NookPressStyle())
                    .help(url.lastPathComponent)
                }
                Spacer()
                if let error {
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundStyle(ArrowTheme.red)
                }
            }
        }
        .padding(.top, 2)
        .onAppear { reload() }
    }

    private func reload() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        captures = files
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
        latest = captures.first.flatMap(NSImage.init(contentsOf:))
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
