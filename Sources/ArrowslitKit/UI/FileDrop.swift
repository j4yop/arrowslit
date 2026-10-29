import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
extension NSItemProvider {
    /// Resolves a Finder drag into a file URL. Finder offers file URLs as data,
    /// while some apps offer them as URL objects, so try both shapes.
    func arrowslitFileURL() async -> URL? {
        let types = [UTType.fileURL.identifier, UTType.url.identifier]
        for type in types where hasItemConformingToTypeIdentifier(type) {
            if let item = try? await loadItem(forTypeIdentifier: type, options: nil) {
                if let url = item as? URL, url.isFileURL { return url }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   url.isFileURL {
                    return url
                }
            }
            if let data = try? await loadDataRepresentation(forTypeIdentifier: type),
               let url = URL(dataRepresentation: data, relativeTo: nil),
               url.isFileURL {
                return url
            }
        }
        return nil
    }
}

@MainActor
enum FileDrop {
    static func urls(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers {
            if let url = await provider.arrowslitFileURL() {
                urls.append(url)
            }
        }
        return urls
    }
}

/// The blue Files Tray / AirDrop sheet that appears while a file is dragged
/// anywhere over the open nook.
struct NookDropOverlay: View {
    let point: CGPoint
    let split: CGFloat

    private var overAirDrop: Bool { point.x >= split }

    var body: some View {
        GeometryReader { geometry in
            let airWidth = (geometry.size.width - 10) * 0.4
            HStack(spacing: 10) {
                zone(
                    title: overAirDrop ? "Keep in Tray" : "Files Tray",
                    detail: "Drop to keep a reference",
                    symbol: "tray.and.arrow.down.fill",
                    active: !overAirDrop,
                    filled: false
                )
                .frame(width: geometry.size.width - 10 - airWidth)

                zone(
                    title: overAirDrop ? "Send with AirDrop" : "AirDrop",
                    detail: "Drop to send",
                    symbol: "wifi",
                    active: overAirDrop,
                    filled: true
                )
                .frame(width: airWidth)
            }
        }
        .padding(10)
        .allowsHitTesting(false)
    }

    private func zone(
        title: String,
        detail: String,
        symbol: String,
        active: Bool,
        filled: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 0.28, green: 0.62, blue: 1))
            Spacer(minLength: 4)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(filled ? .white : Color(red: 0.35, green: 0.66, blue: 1))
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(filled ? .white.opacity(0.6) : Color(red: 0.35, green: 0.66, blue: 1).opacity(0.65))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(filled ? Color(red: 0.06, green: 0.22, blue: 0.36) : Color(red: 0.02, green: 0.07, blue: 0.16))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color(red: 0.20, green: 0.55, blue: 1).opacity(active ? 1 : 0.55),
                    style: filled ? StrokeStyle(lineWidth: 1.5) : StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                )
        }
        .scaleEffect(active ? 1.015 : 1)
        .animation(.easeOut(duration: 0.12), value: active)
    }
}

/// One drop target for the whole nook. The pointer's x position picks the
/// Files Tray or AirDrop half, so the two halves cannot disagree about a drop.
struct NookDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    @Binding var point: CGPoint
    let split: CGFloat
    let onFiles: ([NSItemProvider]) -> Void
    let onAirDrop: ([NSItemProvider]) -> Void

    func dropEntered(info: DropInfo) {
        MainActor.assumeIsolated {
            point = info.location
            isTargeted = true
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        MainActor.assumeIsolated { point = info.location }
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        MainActor.assumeIsolated { isTargeted = false }
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL, .url])
        MainActor.assumeIsolated {
            isTargeted = false
            if info.location.x < split {
                onFiles(providers)
            } else {
                onAirDrop(providers)
            }
        }
        return true
    }
}
