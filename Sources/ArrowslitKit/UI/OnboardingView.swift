import AppKit
import Combine
import ServiceManagement
import SwiftUI

enum TourDemo {
    case welcome, files, music, time, clipboard, agents, feedback, appearance, displays, permissions
}

struct TourPage {
    let title: String
    let subtitle: String
    let demo: TourDemo
    let primary: String
    let options: [TourOption]
}

struct TourOption: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let detail: String?
    let defaultValue: Bool

    init(_ id: String, _ symbol: String, _ title: String, detail: String? = nil, default value: Bool = true) {
        self.id = id
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.defaultValue = value
    }
}

/// Arrowslit's welcome tour. It uses the same quiet stage-and-caption rhythm
/// as the reference tour, but the palette, artwork and every page are
/// Arrowslit's own: warm black, amber and the tools from Settings.
struct OnboardingView: View {
    @Bindable var state: AppState
    let onFinish: (_ openedNotch: Bool) -> Void

    @State private var page = 0
    @State private var finished = false
    @State private var pointer = CGPoint(x: 0.5, y: 0.5)
    @State private var optionValues: [String: Bool] = [:]
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private let pages: [TourPage] = [
        TourPage(
            title: "Welcome to Arrowslit.",
            subtitle: "Quiet control for the notch. Music, timers, calendar, clipboard, files, AI agents and stats — all at the edge of your screen. Here’s a quick tour.",
            demo: .welcome,
            primary: "Take the tour",
            options: []
        ),
        TourPage(
            title: "Everything at the edge.",
            subtitle: "The Home launcher keeps your tools one click away. Drop files on the tray, and pin the features you reach for most.",
            demo: .files,
            primary: "Continue",
            options: [
                TourOption("tray", "tray.full.fill", "File Tray", default: true),
                TourOption("downloads", "arrow.down.circle.fill", "Downloads", default: false),
            ]
        ),
        TourPage(
            title: "Your music, one glance up.",
            subtitle: "See what’s playing in the notch, keep the call strip beside it, and jump back into the app without breaking focus.",
            demo: .music,
            primary: "Continue",
            options: [
                TourOption("nowPlaying", "music.note", "Now Playing", default: true),
                TourOption("calls", "phone.fill", "Calls & Microphone", default: true),
            ]
        ),
        TourPage(
            title: "Focus, without leaving the notch.",
            subtitle: "Start a timer, run a stopwatch, or keep the next meeting in view. Arrowslit keeps time and calendar close without another window.",
            demo: .time,
            primary: "Continue",
            options: [
                TourOption("timer", "timer", "Timer & Pomodoro", default: true),
                TourOption("calendar", "calendar", "Calendar", default: true),
            ]
        ),
        TourPage(
            title: "Copy it once. Keep it close.",
            subtitle: "Clipboard history stays in memory, pinned clips stay at the top, and Scratchpad holds the thought you don’t want to lose.",
            demo: .clipboard,
            primary: "Continue",
            options: [
                TourOption("clipboard", "doc.on.clipboard", "Clipboard history", default: true),
                TourOption("notes", "note.text", "Scratchpad", default: true),
            ]
        ),
        TourPage(
            title: "Your agents, in plain sight.",
            subtitle: "Follow Claude Code, Codex, OpenCode and Copilot usage, watch live turns, and answer permission requests without leaving the notch.",
            demo: .agents,
            primary: "Continue",
            options: [
                TourOption("agents", "sparkles", "AI Agents", default: true),
                TourOption("stats", "chart.bar.fill", "System stats", default: true),
            ]
        ),
        TourPage(
            title: "Feedback that stays out of the way.",
            subtitle: "Volume, brightness, downloads and calls appear in the notch for a moment, then step aside. Choose what stays and what passes through.",
            demo: .feedback,
            primary: "Continue",
            options: [
                TourOption("volume", "speaker.wave.2.fill", "Volume & brightness", default: true),
                TourOption("downloadsStrip", "arrow.down.circle.fill", "Download progress", default: true),
            ]
        ),
        TourPage(
            title: "Make it yours.",
            subtitle: "Tune the notch in Settings: pitch-black glass, size, motion, hover behaviour and what opens when you click.",
            demo: .appearance,
            primary: "Continue",
            options: [
                TourOption("pitchBlack", "circle.lefthalf.filled", "Pitch black", default: true),
                TourOption("liquid", "drop.fill", "Liquid animations", default: true),
            ]
        ),
        TourPage(
            title: "Every display gets an island.",
            subtitle: "Keep Arrowslit on the built-in display, follow the pointer, or show it on every screen. Lock-screen media works wherever you are.",
            demo: .displays,
            primary: "Continue",
            options: [
                TourOption("allDisplays", "display.2", "Show on all displays", default: false),
                TourOption("lockScreen", "lock.fill", "Show on Lock Screen", default: true),
            ]
        ),
        TourPage(
            title: "Almost there.",
            subtitle: "Each permission turns on a feature — grant it now or later in Settings. Choose whether Arrowslit opens when you log in.",
            demo: .permissions,
            primary: "Continue",
            options: []
        ),
    ]

    init(state: AppState, onFinish: @escaping (_ openedNotch: Bool) -> Void) {
        self.state = state
        self.onFinish = onFinish
        var defaults: [String: Bool] = [:]
        for page in pages {
            for option in page.options { defaults[option.id] = option.defaultValue }
        }
        _optionValues = State(initialValue: defaults)
    }

    private var current: TourPage { pages[min(page, pages.count - 1)] }

    var body: some View {
        ZStack(alignment: .top) {
            ArrowslitBackdrop(pointer: pointer)

            VStack(spacing: 0) {
                if finished {
                    allSet
                } else {
                    tourContent
                }
            }

            topBar
        }
        .frame(width: 804, height: 756)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(ArrowTheme.amber.opacity(0.18), lineWidth: 0.5)
        }
        .background(Color.black)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                pointer = CGPoint(
                    x: min(1, max(0, location.x / 804)),
                    y: min(1, max(0, location.y / 756))
                )
            case .ended:
                pointer = CGPoint(x: 0.5, y: 0.5)
            }
        }
    }

    private var topBar: some View {
        HStack {
            if !finished && page > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { page -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .overlay(Circle().strokeBorder(ArrowTheme.amber.opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
            Spacer()
            Button {
                finish(openedNotch: false)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .frame(height: 58, alignment: .top)
    }

    private var tourContent: some View {
        VStack(spacing: 0) {
            if current.demo == .permissions {
                PermissionsStage(
                    launchAtLogin: $launchAtLogin,
                    error: $loginError
                )
                .frame(height: 510)
                .padding(.top, 20)
            } else {
                TourMacBook(state: state, page: current, finished: false)
                    .frame(width: 716, height: 494)
                    .padding(.top, 20)
            }

            PageDots(count: pages.count, index: page)
                .padding(.top, current.demo == .permissions ? 8 : 12)

            Text(current.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ArrowTheme.bone)
                .multilineTextAlignment(.center)
                .padding(.top, 5)

            Text(current.subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(ArrowTheme.bone.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(width: 600)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            if !current.options.isEmpty {
                VStack(spacing: 6) {
                    ForEach(current.options) { option in
                        TourOptionRow(option: option, isOn: binding(option.id))
                    }
                }
                .frame(width: 440)
                .padding(.top, 10)
            }

            Spacer(minLength: 6)

            Button(action: advance) {
                Text(current.primary)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 220, height: 36)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ArrowTheme.amber)
                    )
            }
            .buttonStyle(NookPressStyle())
            .padding(.top, 6)

            if page == 0 {
                Button("Skip tour") { finish(openedNotch: false) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.46))
                    .padding(.top, 6)
            }
            Spacer().frame(height: 12)
        }
    }

    private var allSet: some View {
        VStack(spacing: 0) {
            TourMacBook(state: state, page: current, finished: true)
                .frame(width: 716, height: 494)
                .padding(.top, 20)

            Spacer(minLength: 10)

            Text("You’re all set.")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ArrowTheme.bone)

            Text("Move your pointer to the top of your screen to open Arrowslit.")
                .font(.system(size: 12))
                .foregroundStyle(ArrowTheme.bone.opacity(0.68))
                .padding(.top, 5)

            Button {
                finish(openedNotch: true)
            } label: {
                Text("Start Arrowslit")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 220, height: 36)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ArrowTheme.amber)
                    )
            }
            .buttonStyle(NookPressStyle())
            .padding(.top, 14)
            Spacer().frame(height: 22)
        }
    }

    private func binding(_ id: String) -> Binding<Bool> {
        switch id {
        case "tray":
            tab(.tray)
        case "downloads":
            Binding(get: { state.settings.downloadsEnabled }, set: { state.setDownloadsEnabled($0) })
        case "nowPlaying":
            tab(.nowPlaying)
        case "calls":
            Binding(get: { state.settings.callsEnabled }, set: { state.setCallsEnabled($0) })
        case "timer":
            tab(.timer)
        case "calendar":
            tab(.calendar)
        case "clipboard":
            tab(.clipboard)
        case "notes":
            tab(.notes)
        case "agents":
            tab(.agents)
        case "stats":
            tab(.stats)
        case "volume":
            Binding(
                get: { state.live.isOn(.volume) },
                set: { state.live.set(.volume, $0) }
            )
        case "downloadsStrip":
            Binding(
                get: { state.live.isOn(NotchLiveSettings.Strip.download) },
                set: { state.live.set(NotchLiveSettings.Strip.download, $0) }
            )
        case "pitchBlack":
            Binding(
                get: { state.settings.appearance.pitchBlack },
                set: {
                    var appearance = state.settings.appearance
                    appearance.pitchBlack = $0
                    state.settings.appearance = appearance
                }
            )
        case "liquid":
            Binding(
                get: { state.settings.liquidAnimations },
                set: { state.setLiquidAnimations($0) }
            )
        case "allDisplays":
            Binding(
                get: { state.settings.displayChoice == .all },
                set: { state.settings.displayChoice = $0 ? .all : .automatic }
            )
        case "lockScreen":
            Binding(
                get: { state.settings.showOnLockScreen },
                set: { state.settings.showOnLockScreen = $0 }
            )
        default:
            Binding(
                get: { optionValues[id] ?? true },
                set: { optionValues[id] = $0 }
            )
        }
    }

    private func tab(_ tab: WorkbenchTab) -> Binding<Bool> {
        Binding(
            get: { state.settings.isTabEnabled(tab) },
            set: { state.setTabEnabled(tab, $0) }
        )
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { finished = true }
        }
    }

    private func finish(openedNotch: Bool) {
        UserDefaults.standard.set(true, forKey: "arrowslit.onboarding.completed")
        onFinish(openedNotch)
    }
}

// MARK: - Arrowslit atmosphere

private struct ArrowslitBackdrop: View {
    let pointer: CGPoint
    @State private var breathe = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.021, blue: 0.019),
                        Color(red: 0.105, green: 0.070, blue: 0.043),
                        Color(red: 0.012, green: 0.010, blue: 0.009),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [ArrowTheme.amber.opacity(0.24), .clear],
                    center: UnitPoint(x: 0.78 + pointer.x * 0.04, y: 0.22 + pointer.y * 0.03),
                    startRadius: 10,
                    endRadius: 560
                )

                Circle()
                    .fill(ArrowTheme.amber.opacity(breathe ? 0.11 : 0.055))
                    .frame(width: 320, height: 320)
                    .blur(radius: 58)
                    .scaleEffect(breathe ? 1.18 : 0.9)
                    .position(x: 804 * 0.78, y: 756 * 0.42)
                    .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: breathe)

                RadialGradient(
                    colors: [Color(red: 0.65, green: 0.30, blue: 0.10).opacity(0.16), .clear],
                    center: UnitPoint(x: 0.18, y: 0.88),
                    startRadius: 20,
                    endRadius: 480
                )

                slitField(pointer: pointer)
                    .opacity(0.8)

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.50), Color.black.opacity(0.88)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    center: .center,
                    startRadius: 240,
                    endRadius: 650
                )

                grain
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .onAppear { breathe = true }
    }

    private func slitField(pointer: CGPoint) -> some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<11, id: \.self) { index in
                    let x = Double(index) / 10
                    Capsule(style: .continuous)
                        .fill(ArrowTheme.amber.opacity(index % 3 == 0 ? 0.10 : 0.045))
                        .frame(width: index % 4 == 0 ? 1.5 : 1, height: 90 + CGFloat((index * 47) % 180))
                        .blur(radius: index % 3 == 0 ? 0.4 : 0)
                        .position(
                            x: proxy.size.width * x + (pointer.x - 0.5) * CGFloat(index - 5) * 3,
                            y: proxy.size.height * (0.14 + CGFloat((index * 19) % 70) / 100)
                        )
                }

                SlitMark(height: 160, color: ArrowTheme.amber.opacity(0.035))
                    .scaleEffect(3)
                    .position(x: proxy.size.width * 0.74, y: proxy.size.height * 0.20)
            }
        }
    }

    private var grain: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 0xA770)
            for _ in 0..<900 {
                let x = Double.random(in: 0..<size.width, using: &generator)
                let y = Double.random(in: 0..<size.height, using: &generator)
                let alpha = Double.random(in: 0.008...0.022, using: &generator)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

private struct ArrowslitScreenArt: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.026, blue: 0.023),
                    Color(red: 0.15, green: 0.095, blue: 0.055),
                    Color(red: 0.015, green: 0.013, blue: 0.011),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [ArrowTheme.amber.opacity(0.28), .clear],
                center: UnitPoint(x: 0.70, y: 0.82),
                startRadius: 12,
                endRadius: 460
            )

            GeometryReader { proxy in
                // A quiet drafting grid and amber rings give the empty
                // space the same measured feel as the notch.
                Path { path in
                    let step: CGFloat = 42
                    stride(from: 0, through: proxy.size.width, by: step).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }
                    stride(from: 0, through: proxy.size.height, by: step).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.018), lineWidth: 0.5)

                Circle()
                    .stroke(ArrowTheme.amber.opacity(0.055), lineWidth: 1)
                    .frame(width: 620, height: 620)
                    .position(x: proxy.size.width * 0.72, y: proxy.size.height * 0.32)
                Circle()
                    .stroke(ArrowTheme.amber.opacity(0.035), lineWidth: 1)
                    .frame(width: 860, height: 860)
                    .position(x: proxy.size.width * 0.72, y: proxy.size.height * 0.32)

                ForEach(0..<7, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(ArrowTheme.amber.opacity(0.075))
                        .frame(width: 1, height: 70 + CGFloat((index * 53) % 150))
                        .position(
                            x: proxy.size.width * (0.12 + CGFloat(index) * 0.13),
                            y: proxy.size.height * 0.60
                        )
                }
                SlitMark(height: 130, color: ArrowTheme.amber.opacity(0.08))
                    .scaleEffect(3.2)
                    .position(x: proxy.size.width * 0.78, y: proxy.size.height * 0.24)

                LinearGradient(
                    colors: [.clear, ArrowTheme.amber.opacity(0.14), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.68)
            }
        }
    }
}

// MARK: - MacBook

private struct TourMacBook: View {
    @Bindable var state: AppState
    let page: TourPage
    var finished = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                ArrowslitScreenArt()
                    .frame(width: 700, height: 456)

                if page.demo == .music || page.demo == .appearance {
                    FauxMenuBar()
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                }

                TourNotch()
                    .padding(.top, -1)

                if finished {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: ArrowTheme.amber.opacity(0.25), radius: 18, y: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    demo
                }
            }
            .frame(width: 700, height: 456)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(Color.black)
            )

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.48), Color(white: 0.28), Color(white: 0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 700, height: 9)
                .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
        }
        .shadow(color: .black.opacity(0.5), radius: 24, y: 14)
    }

    @ViewBuilder private var demo: some View {
        switch page.demo {
        case .welcome:
            WelcomeDemo()
        case .files:
            FilesDemo()
        case .music:
            MusicDemo()
        case .time:
            TimeDemo()
        case .clipboard:
            ClipboardDemo()
        case .agents:
            AgentsDemo()
        case .feedback:
            FeedbackDemo()
        case .appearance:
            AppearanceDemo()
        case .displays:
            DisplaysDemo()
        case .permissions:
            EmptyView()
        }
    }
}

private struct TourNotch: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.black)
            .frame(width: 182, height: 26)
            .overlay(alignment: .trailing) {
                Circle()
                    .fill(ArrowTheme.amber.opacity(0.28))
                    .frame(width: 4, height: 4)
                    .padding(.trailing, 42)
            }
    }
}

private struct FauxMenuBar: View {
    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Tue 9:41 AM")
                .font(.system(size: 9, weight: .medium, design: .rounded))
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(ArrowTheme.bone.opacity(0.72))
    }
}

// MARK: - Demos

private struct WelcomeDemo: View {
    @State private var glow = false

    var body: some View {
        VStack(spacing: 8) {
            SlitMark(height: 58, color: ArrowTheme.amber)
                .scaleEffect(2.2)
                .shadow(color: ArrowTheme.amber.opacity(glow ? 0.55 : 0.25), radius: glow ? 25 : 12)
            Text("ARROWSLIT")
                .font(.system(size: 14, weight: .black))
                .tracking(5)
                .foregroundStyle(ArrowTheme.bone)
            Text("QUIET CONTROL")
                .font(.system(size: 7.5, weight: .semibold))
                .tracking(3)
                .foregroundStyle(ArrowTheme.amber.opacity(0.7))
        }
        .offset(y: 180)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

private struct FilesDemo: View {
    @State private var float = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(ArrowTheme.amber)
                Text("File Tray")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Spacer()
                Text("3 files · Pinned")
                    .font(.system(size: 9))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.4))
            }

            HStack(spacing: 10) {
                file("Design.pdf", "doc.richtext", Color(red: 0.84, green: 0.42, blue: 0.22))
                file("Shot.png", "photo", Color(red: 0.55, green: 0.42, blue: 0.26))
                file("Notes.md", "text.alignleft", Color(red: 0.78, green: 0.60, blue: 0.30))
                file("Build.dmg", "shippingbox", Color(red: 0.42, green: 0.30, blue: 0.20))
            }

            HStack(spacing: 7) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .semibold))
                Text("Drop files here")
                    .font(.system(size: 10))
                Spacer()
                Text("AirDrop")
                    .font(.system(size: 9, weight: .semibold))
                Image(systemName: "wifi")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(ArrowTheme.bone.opacity(0.55))
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        ArrowTheme.amber.opacity(0.28),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .padding(15)
        .frame(width: 430)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.14), lineWidth: 0.5))
        )
        .offset(y: 46)
    }

    private func file(_ name: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.82))
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.9))
            }
            .frame(width: 52, height: 52)
            Text(name)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(ArrowTheme.bone.opacity(0.66))
                .lineLimit(1)
        }
        .frame(width: 82)
        .offset(y: float ? -2 : 1)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: float)
        .onAppear { float = true }
    }
}

private struct MusicDemo: View {
    @State private var progress: CGFloat = 0.42

    var body: some View {
        VStack(spacing: 10) {
            player

            VStack(spacing: 5) {
                lyric("I'm blinded by the lights", active: true)
                lyric("No, I can't sleep until I feel your touch", active: false)
                lyric("I said, ooh, I'm drowning in the night", active: false)
            }
            .padding(.top, 4)

            HStack(spacing: 5) {
                ForEach(0..<18, id: \.self) { index in
                    Capsule()
                        .fill(ArrowTheme.amber.opacity(0.25 + Double(index % 4) * 0.14))
                        .frame(width: 3, height: CGFloat(5 + (index * 7) % 17))
                }
            }
            .frame(height: 22, alignment: .bottom)
            .padding(.top, 2)
        }
        .offset(y: 36)
    }

    private var player: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.92, green: 0.42, blue: 0.12), Color(red: 0.20, green: 0.10, blue: 0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .fill(.black.opacity(0.45))
                        .frame(width: 34, height: 34)
                    Capsule().fill(ArrowTheme.bone.opacity(0.8)).frame(width: 20, height: 2)
                }
                .frame(width: 54, height: 54)
                .shadow(color: ArrowTheme.amber.opacity(0.25), radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Low Beam")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                    Text("Instrumental")
                        .font(.system(size: 9.5))
                        .foregroundStyle(ArrowTheme.bone.opacity(0.45))
                }
                Spacer()
                Image(systemName: "airpods")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber.opacity(0.8))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(ArrowTheme.bone.opacity(0.14))
                    Capsule().fill(ArrowTheme.amber).frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 3)

            HStack(spacing: 48) {
                Image(systemName: "backward.fill")
                Image(systemName: "pause.fill")
                Image(systemName: "forward.fill")
                Image(systemName: "quote.bubble")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ArrowTheme.bone.opacity(0.88))
        }
        .padding(13)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.12), lineWidth: 0.5))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: false)) {
                progress = 0.92
            }
        }
    }

    private func lyric(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 9, weight: active ? .semibold : .regular))
            .foregroundStyle(active ? ArrowTheme.amber : ArrowTheme.bone.opacity(0.28))
    }
}

private struct TimeDemo: View {
    private let ticks = Array(0..<34)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Timer")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) {
                        Capsule().fill(ArrowTheme.amber).frame(height: 2)
                    }
                Text("Pomodoro")
                Text("Stopwatch")
                Spacer()
                Text("Start")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 24)
                    .background(Capsule().fill(ArrowTheme.amber))
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(ArrowTheme.bone.opacity(0.55))

            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 1) {
                    ForEach(ticks, id: \.self) { index in
                        Capsule()
                            .fill(index % 5 == 0 ? ArrowTheme.amber : ArrowTheme.amber.opacity(0.22))
                            .frame(width: 2, height: index % 5 == 0 ? 26 : 14)
                    }
                }
                .frame(height: 28)
                .clipped()

                Text("25:00")
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.amber)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(ArrowTheme.amber)
                Text("Design review · 10:45 PM")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.72))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.35))
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(14)
        .frame(width: 450)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.12), lineWidth: 0.5))
        )
        .offset(y: 90)
    }
}

private struct ClipboardDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .foregroundStyle(ArrowTheme.amber)
                Text("Clipboard")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Spacer()
                Image(systemName: "square.grid.2x2")
                Image(systemName: "gearshape")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(ArrowTheme.bone.opacity(0.4))

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.4))
                Text("Search clips")
                    .font(.system(size: 9.5))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.38))
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.white.opacity(0.07), in: Capsule(style: .continuous))

            HStack(spacing: 9) {
                pinned("Pinned secret note", "ChatGPT · 0m ago")
                VStack(spacing: 6) {
                    clip("Design tokens for the notch", "Figma")
                    clip("swift test --build-system native", "Terminal")
                }
            }

            HStack(spacing: 7) {
                Image(systemName: "note.text")
                    .foregroundStyle(ArrowTheme.amber)
                Text("Scratchpad")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.7))
                Spacer()
                Text("Pinned")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber.opacity(0.75))
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(14)
        .frame(width: 430)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.black.opacity(0.80))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.12), lineWidth: 0.5))
        )
        .offset(y: 58)
    }

    private func pinned(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Image(systemName: "pin.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(ArrowTheme.amber)
            }
            Spacer()
            Text(subtitle)
                .font(.system(size: 7.5))
                .foregroundStyle(ArrowTheme.bone.opacity(0.4))
        }
        .padding(9)
        .frame(width: 190, height: 66, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func clip(_ title: String, _ app: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 9))
                .foregroundStyle(ArrowTheme.amber.opacity(0.8))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.8))
                    .lineLimit(1)
                Text(app)
                    .font(.system(size: 7))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.32))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: 220, height: 30)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AgentsDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .foregroundStyle(ArrowTheme.amber)
                Text("AI Agents")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Spacer()
                Text("Today")
                    .font(.system(size: 8.5))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.4))
            }

            HStack(spacing: 8) {
                card("Codex", "86% left", "30d · 28d 2h", tint: Color(red: 0.49, green: 0.60, blue: 1.0), bar: 0.86)
                card("OpenCode", "$3.86", "927M · 99% cache", tint: Color(red: 0.06, green: 0.73, blue: 0.51), bar: nil)
            }
            HStack(spacing: 8) {
                card("Spending", "≥ $3.86", "API value · 927M tokens", tint: ArrowTheme.amber, bar: 0.64)
                liveCard
            }
        }
        .padding(14)
        .frame(width: 450)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.12), lineWidth: 0.5))
        )
        .offset(y: 58)
    }

    private func card(_ title: String, _ value: String, _ detail: String, tint: Color, bar: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text(title)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.85))
                Spacer()
            }
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(ArrowTheme.bone)
            Text(detail)
                .font(.system(size: 7.5))
                .foregroundStyle(ArrowTheme.bone.opacity(0.36))
                .lineLimit(1)
            if let bar {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.10))
                        Capsule().fill(tint.opacity(0.8)).frame(width: proxy.size.width * bar)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(9)
        .frame(width: 210, height: 82, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var liveCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle().fill(ArrowTheme.green).frame(width: 5, height: 5)
                Text("Now")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.85))
                Spacer()
            }
            Text("OpenCode")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
            Text("local session · 29K written · $0.20")
                .font(.system(size: 7))
                .foregroundStyle(ArrowTheme.bone.opacity(0.36))
                .lineLimit(1)
            HStack(spacing: 3) {
                ForEach([3, 6, 4, 9, 7, 11, 8], id: \.self) { value in
                    Capsule().fill(ArrowTheme.green.opacity(0.65)).frame(width: 3, height: CGFloat(value))
                }
            }
            .frame(height: 14, alignment: .bottom)
        }
        .padding(9)
        .frame(width: 210, height: 82, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct FeedbackDemo: View {
    var body: some View {
        VStack(spacing: 7) {
            hud("speaker.wave.2.fill", "Volume", "62%", ArrowTheme.amber) {
                Capsule().fill(.white.opacity(0.14)).frame(width: 92, height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(ArrowTheme.amber).frame(width: 58, height: 3)
                    }
            }
            hud("arrow.down.circle.fill", "Download", "72%", ArrowTheme.amber) {
                Capsule().fill(.white.opacity(0.14)).frame(width: 92, height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(ArrowTheme.amber).frame(width: 66, height: 3)
                    }
            }
            hud("phone.fill", "Call", "12:48", ArrowTheme.green) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(ArrowTheme.red)
            }
            hud("calendar", "Calendar", "10:45 PM", ArrowTheme.amber) {
                Text("in 24 min")
                    .font(.system(size: 8))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.4))
            }
            Text("They step aside when the moment passes.")
                .font(.system(size: 8.5))
                .foregroundStyle(ArrowTheme.bone.opacity(0.34))
                .padding(.top, 4)
        }
        .offset(y: 46)
    }

    private func hud<Accessory: View>(_ symbol: String, _ title: String, _ value: String, _ tint: Color, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(ArrowTheme.bone.opacity(0.8))
            if title == "Volume" { accessory() }
            Spacer(minLength: 8)
            if title != "Volume" { accessory() }
            Text(value)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(ArrowTheme.bone.opacity(0.55))
        }
        .padding(.horizontal, 11)
        .frame(width: 300, height: 30)
        .background(Color.black.opacity(0.78), in: Capsule(style: .continuous))
        .overlay(Capsule().strokeBorder(ArrowTheme.amber.opacity(0.08), lineWidth: 0.5))
    }
}

private struct AppearanceDemo: View {
    @State private var pitchBlack = true
    @State private var theme = 0
    @State private var size = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Appearance")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Spacer()
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.4))
            }

            HStack {
                Text("Theme").font(.system(size: 9.5)).foregroundStyle(ArrowTheme.bone.opacity(0.7))
                Spacer()
                segmented(["Black", "Glass"], selection: $theme)
            }

            HStack {
                Text("Pitch black").font(.system(size: 9.5)).foregroundStyle(ArrowTheme.bone.opacity(0.7))
                Spacer()
                Capsule()
                    .fill(pitchBlack ? ArrowTheme.amber : Color.white.opacity(0.14))
                    .frame(width: 34, height: 18)
                    .overlay(alignment: pitchBlack ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 14, height: 14).padding(2)
                    }
                    .onTapGesture { pitchBlack.toggle() }
            }

            HStack {
                Text("Size").font(.system(size: 9.5)).foregroundStyle(ArrowTheme.bone.opacity(0.7))
                Spacer()
                segmented(["S", "M", "L"], selection: $size)
            }

            HStack {
                Text("Width").font(.system(size: 9.5)).foregroundStyle(ArrowTheme.bone.opacity(0.7))
                Spacer()
                Capsule().fill(.white.opacity(0.14)).frame(width: 90, height: 3)
                    .overlay(alignment: .leading) { Capsule().fill(ArrowTheme.amber).frame(width: 62, height: 3) }
                Text("200 pt").font(.system(size: 8).monospacedDigit()).foregroundStyle(ArrowTheme.bone.opacity(0.4))
            }

            HStack {
                Text("Glass").font(.system(size: 9.5)).foregroundStyle(ArrowTheme.bone.opacity(0.7))
                Spacer()
                Capsule().fill(ArrowTheme.amber.opacity(0.2)).frame(width: 90, height: 3)
                    .overlay(alignment: .leading) { Capsule().fill(ArrowTheme.amber).frame(width: 45, height: 3) }
                Text("50%").font(.system(size: 8).monospacedDigit()).foregroundStyle(ArrowTheme.bone.opacity(0.4))
            }
        }
        .padding(13)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.84))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.12), lineWidth: 0.5))
        )
        .offset(y: 54)
    }

    private func segmented(_ items: [String], selection: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { index in
                Text(items[index])
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(selection.wrappedValue == index ? .black : ArrowTheme.bone.opacity(0.5))
                    .frame(width: items[index].count > 1 ? 46 : 24, height: 20)
                    .background(
                        selection.wrappedValue == index ? ArrowTheme.amber : Color.white.opacity(0.06),
                        in: Capsule()
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection.wrappedValue = index }
            }
        }
    }
}

private struct DisplaysDemo: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                display("Built-in", notch: true)
                display("External", notch: false)
            }
            HStack(spacing: 5) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 9, weight: .semibold))
                Text("Follow the pointer")
                    .font(.system(size: 8.5, weight: .medium))
            }
            .foregroundStyle(ArrowTheme.amber.opacity(0.7))
        }
        .offset(y: 145)
    }

    private func display(_ title: String, notch: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .overlay {
                        LinearGradient(
                            colors: [ArrowTheme.amber.opacity(0.10), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .frame(width: 190, height: 96)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.16), lineWidth: 0.5))

                Capsule()
                    .fill(.black)
                    .frame(width: notch ? 70 : 58, height: notch ? 9 : 8)
                    .padding(.top, 0)

                SlitMark(height: 18, color: ArrowTheme.amber.opacity(0.55))
                    .offset(y: 42)
            }
            Text(title)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(ArrowTheme.bone.opacity(0.5))
        }
    }
}

// MARK: - Shared

private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { item in
                Capsule(style: .continuous)
                    .fill(item == index ? ArrowTheme.amber : ArrowTheme.bone.opacity(0.22))
                    .frame(width: item == index ? 22 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: index)
    }
}

private struct TourOptionRow: View {
    let option: TourOption
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: option.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber.opacity(0.9))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(option.title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.bone.opacity(0.9))
                    if let detail = option.detail {
                        Text(detail)
                            .font(.system(size: 8))
                            .foregroundStyle(ArrowTheme.bone.opacity(0.38))
                    }
                }
                Spacer(minLength: 8)
                Circle()
                    .fill(isOn ? ArrowTheme.amber : Color.white.opacity(0.10))
                    .frame(width: 15, height: 15)
                    .overlay {
                        if isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black.opacity(0.75))
                        }
                    }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(isOn ? 0.14 : 0.05), lineWidth: 0.5))
            )
        }
        .buttonStyle(NookPressStyle())
    }
}

// MARK: - Permissions

private struct PermissionsStage: View {
    @Binding var launchAtLogin: Bool
    @Binding var error: String?
    @State private var permissions = PermissionsCenter()

    private let columns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(ArrowTheme.amber.opacity(0.14))
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Permissions")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                    Text("Turn on what you want now. Everything can be changed later.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(ArrowTheme.bone.opacity(0.5))
                }

                Spacer(minLength: 8)

                Button {
                    Task { await permissions.requestAll() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(permissions.isRequesting ? "Requesting…" : "Grant All")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(ArrowTheme.bone)
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(Capsule().fill(ArrowTheme.amber.opacity(0.18)))
                    .overlay(Capsule().strokeBorder(ArrowTheme.amber.opacity(0.25), lineWidth: 0.5))
                }
                .buttonStyle(NookPressStyle())
                .disabled(permissions.isRequesting)
            }
            .padding(.horizontal, 12)
            .frame(width: 700, height: 70)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.10), lineWidth: 0.5))

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(PermissionKind.allCases) { kind in
                    permissionRow(kind)
                }
            }
            .frame(width: 700)

            Toggle(isOn: $launchAtLogin) {
                HStack(spacing: 10) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber.opacity(0.9))
                        .frame(width: 18)
                    Text("Start Arrowslit at login")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.bone.opacity(0.9))
                    Spacer()
                }
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(ArrowTheme.amber)
            .padding(.horizontal, 12)
            .frame(width: 700, height: 38)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onChange(of: launchAtLogin) { _, value in
                do {
                    if value { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                    error = nil
                } catch {
                    self.error = error.localizedDescription
                    launchAtLogin.toggle()
                }
            }

            if let message = permissions.automationMessage {
                Text(message)
                    .font(.system(size: 8.5))
                    .foregroundStyle(ArrowTheme.amber.opacity(0.8))
                    .lineLimit(2)
                    .frame(width: 700, alignment: .leading)
            }

            if let error {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(ArrowTheme.red)
                    .frame(width: 700, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("You can change these later in Settings › General › Permissions.")
                    .font(.system(size: 8.5))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.35))
                Spacer()
                Button("Open Privacy & Security") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security")!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(ArrowTheme.bone.opacity(0.55))
            }
            .frame(width: 700)
        }
        .frame(maxWidth: .infinity)
        .task { await permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await permissions.refresh() }
        }
    }

    private func permissionRow(_ kind: PermissionKind) -> some View {
        let status = permissions.status(for: kind)
        return HStack(spacing: 8) {
            Image(systemName: kind.symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(ArrowTheme.amber.opacity(0.82))
                .frame(width: 17)

            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.92))
                Text(kind.detail)
                    .font(.system(size: 8))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer(minLength: 3)

            statusButton(kind, status: status)
        }
        .padding(.horizontal, 9)
        .frame(height: 54)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(ArrowTheme.amber.opacity(0.05), lineWidth: 0.5))
    }

    @ViewBuilder private func statusButton(_ kind: PermissionKind, status: PermissionStatus) -> some View {
        if status.isGranted {
            Label("Granted", systemImage: "checkmark")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(ArrowTheme.green)
                .labelStyle(.titleAndIcon)
        } else {
            Button(status == .denied || status == .restricted || status == .limited ? "Settings" : "Grant") {
                if status == .denied || status == .restricted || status == .limited {
                    permissions.openSettings(for: kind)
                } else {
                    Task { await permissions.request(kind) }
                }
            }
            .buttonStyle(NookPressStyle())
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(ArrowTheme.bone.opacity(0.86))
            .padding(.horizontal, 8)
            .frame(height: 21)
            .background(Capsule().fill(ArrowTheme.amber.opacity(0.16)))
        }
    }
}
