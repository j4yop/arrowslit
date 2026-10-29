import SwiftUI
import UniformTypeIdentifiers

struct TrayPane: View {
    @Bindable var state: AppState
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("FILES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ArrowTheme.faint)
                    Text("A shelf of references. Originals are never copied or deleted.")
                        .font(.system(size: 11))
                        .foregroundStyle(ArrowTheme.muted)
                }
                Spacer()
                if !state.tray.items.isEmpty {
                    Button("Clear") { state.tray.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }

            if state.tray.items.isEmpty {
                empty
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                        spacing: 12
                    ) {
                        ForEach(state.tray.items) { item in
                            TrayCell(state: state, item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)
            }

            HStack {
                Button {
                    addFiles()
                } label: {
                    Label("Add files", systemImage: "plus")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(ArrowTheme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Capsule().fill(ArrowTheme.amber))
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(state.tray.items.count) of \(TrayStore.capacity)")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(ArrowTheme.faint)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    if let url = await provider.fileURL() { urls.append(url) }
                }
                state.tray.add(urls)
            }
            return true
        }
    }

    private var empty: some View {
        VStack(spacing: 9) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(isTargeted ? ArrowTheme.amber : ArrowTheme.faint)
            Text(isTargeted ? "Drop to keep a reference" : "Drop files here")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isTargeted ? ArrowTheme.amber : ArrowTheme.muted)
            Text("The tray clears when Arrowslit quits.")
                .font(.system(size: 10))
                .foregroundStyle(ArrowTheme.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isTargeted ? ArrowTheme.amber.opacity(0.08) : Color.white.opacity(0.025))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isTargeted ? ArrowTheme.amber.opacity(0.8) : Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK {
            state.tray.add(panel.urls)
        }
    }
}

private struct TrayCell: View {
    @Bindable var state: AppState
    let item: TrayItem
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: state.tray.icon(for: item))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 42)
            Text(item.name)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(ArrowTheme.bone.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.075 : 0.035))
        )
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button { state.tray.remove(item.id) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(ArrowTheme.bone)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.black.opacity(0.7)))
                }
                .buttonStyle(.plain)
                .padding(3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { state.tray.open(item) }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Open") { state.tray.open(item) }
            Button("Show in Finder") { state.tray.reveal(item) }
            Divider()
            Button("Remove") { state.tray.remove(item.id) }
        }
        .help(item.name)
    }
}

@MainActor
private extension NSItemProvider {
    func fileURL() async -> URL? {
        await withCheckedContinuation { continuation in
            _ = loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: url)
            }
        }
    }
}
