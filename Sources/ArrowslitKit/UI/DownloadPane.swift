import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Downloads use Safari's blue.
private let downloadTint = Color(red: 0.04, green: 0.52, blue: 1)

/// Left of the camera in the compact notch.
struct DownloadCompactIcon: View {
    let fontSize: CGFloat

    var body: some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.system(size: fontSize + 1, weight: .semibold))
            .foregroundStyle(downloadTint)
            .accessibilityLabel("Downloading")
    }
}

/// Right of the camera: percent, or bytes when the total isn't known.
struct DownloadCompactValue: View {
    let summary: DownloadSummary
    let fontSize: CGFloat

    var body: some View {
        Text(label)
            .font(.system(size: fontSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(downloadTint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }

    private var label: String {
        if let fraction = summary.fraction {
            return "\(Int((fraction * 100).rounded(.down)))%"
        }
        let bytes = summary.items.reduce(Int64(0)) { $0 + $1.completed }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// The open download panel: file, progress, time left, reveal and stop.
struct DownloadPane: View {
    @Bindable var state: AppState

    private var summary: DownloadSummary { state.downloadProgress.summary }

    var body: some View {
        if let item = summary.items.first {
            HStack(spacing: 12) {
                Image(nsImage: Self.icon(for: item.name))
                    .resizable()
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(ArrowTheme.bone)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if summary.items.count > 1 {
                            Text("+\(summary.items.count - 1) more")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ArrowTheme.muted)
                                .fixedSize()
                        }
                    }
                    DownloadBar(fraction: item.fraction)
                        .frame(height: 4)
                    Text(detail(item))
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                downloadButton(symbol: "magnifyingglass", label: "Show in Finder") {
                    state.downloadProgress.reveal(item.id)
                }
                if state.downloadProgress.canCancel(item.id) {
                    downloadButton(symbol: "xmark", label: "Stop download") {
                        state.downloadProgress.cancel(item.id)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ArrowTheme.faint)
                Text("No downloads running")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detail(_ item: DownloadProgressItem) -> String {
        let bytes = DownloadFormat.bytes(item.completed, of: item.total)
        guard let left = item.secondsLeft else { return bytes }
        return bytes + " · " + DownloadFormat.timeLeft(left)
    }

    private func downloadButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(downloadTint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(NookPressStyle())
        .nookHitSlop()
        .help(label)
        .accessibilityLabel(label)
    }

    private static func icon(for name: String) -> NSImage {
        let ext = (name as NSString).pathExtension
        if let type = UTType(filenameExtension: ext) {
            return NSWorkspace.shared.icon(for: type)
        }
        return NSWorkspace.shared.icon(for: .data)
    }
}

private struct DownloadBar: View {
    let fraction: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                if let fraction {
                    Capsule()
                        .fill(downloadTint)
                        .frame(width: max(proxy.size.height, proxy.size.width * fraction))
                        .animation(.smooth(duration: 0.4), value: fraction)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                        Capsule()
                            .fill(downloadTint)
                            .frame(width: proxy.size.width * 0.3)
                            .offset(x: (proxy.size.width * 1.3) * phase - proxy.size.width * 0.3)
                    }
                    .clipShape(Capsule())
                }
            }
        }
        .accessibilityHidden(true)
    }
}
