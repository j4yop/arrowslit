import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Vorssaint's Downloads page. Until a browser folder is chosen it shows the
/// folder prompt from the recording; afterwards it lists that folder's newest
/// files and any download still in progress.
struct VorssaintDownloadsPane: View {
    @Bindable var state: AppState
    @AppStorage("arrowslit.downloads.folder") private var folderPath = ""
    @State private var files: [URL] = []
    @State private var choosing = false

    private var summary: DownloadSummary { state.downloadProgress.summary }

    var body: some View {
        Group {
            if folderPath.isEmpty {
                prompt
            } else {
                list
            }
        }
        .padding(.top, 2)
        .onAppear { reload() }
    }

    private var prompt: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)
            Text("Choose the folder where your browser saves downloads.\nOnly that folder is watched.")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 400)
            Button {
                chooseFolder()
            } label: {
                Text("Choose Folder…")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .contentShape(Capsule())
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.95))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Text(folderName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
                Spacer()
                Button("Change Folder…") { chooseFolder() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VorssaintTheme.orange)
            }
            .frame(height: 18)

            if let item = summary.items.first {
                activeDownload(item)
            }

            if files.isEmpty && summary.items.isEmpty {
                VorssaintPageEmpty(symbol: "arrow.down.circle", title: "No downloads yet",
                                   detail: "Files that arrive in this folder appear here.")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(files.prefix(12), id: \.self) { url in
                            fileRow(url)
                        }
                    }
                }
            }
        }
    }

    private func activeDownload(_ item: DownloadProgressItem) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: fileIcon(item.name))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                ProgressView(value: item.fraction ?? 0)
                    .progressViewStyle(.linear)
                    .tint(VorssaintTheme.blue)
                Text(DownloadFormat.bytes(item.completed, of: item.total))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)))
    }

    private func fileRow(_ url: URL) -> some View {
        HStack(spacing: 9) {
            Image(nsImage: fileIcon(url.lastPathComponent))
                .resizable()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail(url))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(.horizontal, 9)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
        .contentShape(Rectangle())
        .onTapGesture { NSWorkspace.shared.open(url) }
    }

    private var folderName: String {
        URL(fileURLWithPath: folderPath).lastPathComponent
    }

    private func detail(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        return "\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)) · \(date.formatted(.relative(presentation: .named)))"
    }

    private func fileIcon(_ name: String) -> NSImage {
        if let type = UTType(filenameExtension: (name as NSString).pathExtension) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose the folder where your browser saves downloads."
        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
            reload()
        }
    }

    private func reload() {
        guard !folderPath.isEmpty else { files = []; return }
        let url = URL(fileURLWithPath: folderPath)
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        files = contents.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
    }
}
