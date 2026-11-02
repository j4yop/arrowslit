import SwiftUI

struct VorssaintToolsPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PaneHeader("Tools")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                tool("doc.on.clipboard", "Clipboard", "History and search", .white) {
                    state.openVorssaint(.clipboard)
                }
                tool("tray.full", "Files", "Shelf and drops", .white) {
                    state.openVorssaint(.files)
                }
                tool("note.text", "Scratchpad", "Notes and Markdown", .white) {
                    state.openVorssaint(.scratchpad)
                }
                tool("web.camera", "Camera", "Mirror preview", .white) {
                    state.openVorssaint(.camera)
                }
                tool("camera.viewfinder", "Captures", "Screenshot tools", .white) {
                    state.openVorssaint(.captures)
                }
                tool("timer", "Timer", "Countdown and focus", ArrowTheme.amber) {
                    state.openVorssaint(.timer)
                }
                tool("gauge.with.dots.needle.33percent", "System", "CPU, memory, disk", ArrowTheme.green) {
                    state.openVorssaint(.system)
                }
                tool("gearshape", "Settings", "All preferences", .white) {
                    state.collapse()
                    state.onOpenSettings?()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 2)
    }

    private func tool(_ symbol: String, _ title: String, _ detail: String, _ tint: Color,
                      action: @escaping () -> Void) -> some View {
        VorssaintActionTile(symbol: symbol, title: title, detail: detail, tint: tint, action: action)
            .frame(height: 72)
    }
}
