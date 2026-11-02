import SwiftUI

/// The measured Vorssaint palette. The panel is smoked glass, so the cards
/// and tiles are a light film over it rather than fixed grey: over the dark
/// wallpaper in the recordings they measure #1a1a1a and #1b1b1b, while on a
/// bright desktop the same film picks up the blur behind the panel.
enum VorssaintTheme {
    static let panel = Color.black
    static let card = Color.white.opacity(0.105)
    static let cardHover = Color.white.opacity(0.155)
    static let tile = Color.white.opacity(0.095)
    static let menu = Color.white.opacity(0.16)
    static let stroke = Color.white.opacity(0.075)
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.34)
    static let orange = Color(red: 252 / 255, green: 146 / 255, blue: 11 / 255)
    static let pink = Color(red: 255 / 255, green: 45 / 255, blue: 85 / 255)
    static let red = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)
    static let green = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    static let blue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let purple = Color(red: 191 / 255, green: 90 / 255, blue: 242 / 255)
    static let yellow = Color(red: 255 / 255, green: 214 / 255, blue: 10 / 255)
}

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
                    .fill(VorssaintTheme.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(VorssaintTheme.stroke, lineWidth: 0.5)
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
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(active ? tint.opacity(0.9) : .white.opacity(0.42))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(hovering ? VorssaintTheme.cardHover : VorssaintTheme.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(active ? tint.opacity(0.45) : VorssaintTheme.stroke, lineWidth: 0.75)
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
