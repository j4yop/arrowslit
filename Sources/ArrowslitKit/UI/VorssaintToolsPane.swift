import AppKit
import SwiftUI

/// Vorssaint's Tools rail: two rows of circular utilities across the island,
/// with a small label under each and no surrounding card.
struct VorssaintToolsPane: View {
    @Bindable var state: AppState
    @State private var hovering: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private struct Tool: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let action: () -> Void
    }

    private var tools: [Tool] {
        [
            Tool(id: "clipboard", symbol: "doc.on.clipboard", title: "Clipboard") {
                state.openVorssaint(.clipboard)
            },
            Tool(id: "files", symbol: "tray.full", title: "Files") {
                state.openVorssaint(.files)
            },
            Tool(id: "scratchpad", symbol: "note.text", title: "Scratchpad") {
                state.openVorssaint(.scratchpad)
            },
            Tool(id: "camera", symbol: "web.camera", title: "Camera preview") {
                state.openVorssaint(.camera)
            },
            Tool(id: "captures", symbol: "camera.viewfinder", title: "Screenshot") {
                state.openVorssaint(.captures)
            },
            Tool(id: "recording", symbol: "record.circle", title: "Screen recording") {
                state.openVorssaint(.captures)
            },
            Tool(id: "timer", symbol: "timer", title: "Timer") {
                state.openVorssaint(.timer)
            },
            Tool(id: "system", symbol: "gauge.with.dots.needle.33percent", title: "System") {
                state.openVorssaint(.system)
            },
            Tool(id: "calendar", symbol: "calendar", title: "Calendar") {
                state.openVorssaint(.calendar)
            },
            Tool(id: "notifications", symbol: "bell", title: "Notifications") {
                state.openVorssaint(.notifications)
            },
            Tool(id: "downloads", symbol: "arrow.down.circle", title: "Downloads") {
                state.openVorssaint(.downloads)
            },
            Tool(id: "cleanurl", symbol: "link", title: "Clean URL") {
                cleanURLAction()
            },
            Tool(id: "window", symbol: "rectangle.split.2x1", title: "Window layout") {
                state.collapse()
                state.onOpenSettings?()
            },
            Tool(id: "settings", symbol: "gearshape", title: "Settings") {
                state.collapse()
                state.onOpenSettings?()
            },
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(tools) { tool in
                Button(action: tool.action) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(hovering == tool.id ? 0.14 : 0.085))
                                .frame(width: 38, height: 38)
                            Image(systemName: tool.symbol)
                                .font(.system(size: 15, weight: .medium))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        Text(tool.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity, minHeight: 24, alignment: .top)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 82, alignment: .top)
                    .contentShape(Rectangle())
                }
                .buttonStyle(NookPressStyle(pressedScale: 0.95))
                .onHover { hovering = $0 ? tool.id : nil }
                .help(tool.title)
                .accessibilityLabel(tool.title)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 2)
    }

    private func cleanURLAction() {
        guard let raw = NSPasteboard.general.string(forType: .string),
              var components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        components.queryItems = components.queryItems?.filter { item in
            !["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
              "fbclid", "gclid", "igshid", "mc_cid", "mc_eid"].contains(item.name.lowercased())
        }
        if components.queryItems?.isEmpty == true { components.queryItems = nil }
        guard let cleaned = components.url?.absoluteString else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cleaned, forType: .string)
        NookHaptics.perform(enabled: state.settings.hapticFeedback)
    }
}
