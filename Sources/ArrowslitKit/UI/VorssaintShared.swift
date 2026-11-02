import SwiftUI

/// Shared card and button chrome for the Vorssaint-style pages.
struct VorssaintCard<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }
    }
}

struct VorssaintActionTile: View {
    let symbol: String
    let title: String
    var detail: String? = nil
    var tint: Color = .white
    var active = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(active ? tint.opacity(0.9) : .white.opacity(0.42))
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(hovering ? 0.11 : 0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(active ? tint.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 0.75)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
        .onHover { hovering = $0 }
        .help(title)
        .accessibilityLabel(title)
    }
}

struct VorssaintPageEmpty: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.38))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A compact, animated companion face. It is intentionally a small SwiftUI
/// character rather than a second 1,300-line Core Animation rig: it still
/// blinks, changes mood, reacts to a click and purrs through the trackpad.
struct VorssaintCompanion: View {
    @Binding var enabled: Bool
    @State private var mood: Mood = .idle
    @State private var blinking = false
    @State private var breathing = false
    @State private var lastPet = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Mood: String, CaseIterable {
        case idle, happy, wink, love, sleepy, surprised, thinking
        var eyes: String {
            switch self {
            case .idle: "•   •"
            case .happy: "⌣   ⌣"
            case .wink: "•   ⌣"
            case .love: "♥   ♥"
            case .sleepy: "–   –"
            case .surprised: "○   ○"
            case .thinking: "•   –"
            }
        }
    }

    var body: some View {
        Button {
            guard enabled else { return }
            lastPet = Date()
            mood = [.happy, .wink, .love, .surprised].randomElement() ?? .happy
            NookHaptics.perform(enabled: true)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Soonest.duration))
                if Date().timeIntervalSince(lastPet) > 1 { mood = .idle }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1, green: 0.86, blue: 0.74),
                                         Color(red: 0.95, green: 0.54, blue: 0.68)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 42)
                    Text(mood.eyes)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.18, green: 0.10, blue: 0.12))
                        .opacity(blinking ? 0.25 : 1)
                    Circle()
                        .fill(.white.opacity(0.65))
                        .frame(width: 5, height: 3)
                        .offset(x: -13, y: -8)
                }
                .scaleEffect(breathing && !reduceMotion ? 1.025 : 1)
                Text("Companion")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.94))
        .help(enabled ? "Click to pet the companion" : "Install Companion in Settings")
        .accessibilityLabel("Companion. Click to pet.")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
            scheduleBlink()
        }
        .onDisappear { blinking = false }
    }

    private func scheduleBlink() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.5 + Double.random(in: 0...2)))
                blinking = true
                try? await Task.sleep(for: .seconds(0.12))
                blinking = false
            }
        }
    }

    private enum Soonest {
        static let duration: TimeInterval = 1.4
    }
}
