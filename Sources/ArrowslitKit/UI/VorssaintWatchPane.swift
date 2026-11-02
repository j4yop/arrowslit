import AppKit
import CoreGraphics
import Foundation
import Observation
import SwiftUI
import Vision

enum VorssaintWatchCondition: String, CaseIterable, Identifiable {
    case changes
    case settles
    case contains

    var id: String { rawValue }
    var title: String {
        switch self {
        case .changes: "When it changes"
        case .settles: "When it stops changing"
        case .contains: "When it shows"
        }
    }
}

@MainActor
@Observable
final class VorssaintScreenWatch {
    var isWatching = false
    var text = ""
    var message: String?
    var error: String?
    var condition: VorssaintWatchCondition = .changes
    var target = ""

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var baseline = ""
    @ObservationIgnored private var changedAt: Date?
    @ObservationIgnored private var reading = false

    func start() {
        guard !isWatching else { return }
        if !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()
        }
        error = nil
        message = nil
        baseline = ""
        changedAt = nil
        isWatching = true
        read()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.read() }
        }
        timer.tolerance = 0.4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        isWatching = false
        timer?.invalidate()
        timer = nil
    }

    private func read() {
        guard isWatching, !reading else { return }
        reading = true
        let image = CGDisplayCreateImage(CGMainDisplayID())
        guard let image else {
            reading = false
            error = "Screen Recording permission is needed to read the display."
            stop()
            return
        }
        let request = VNRecognizeTextRequest { [weak self] request, error in
            let lines = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string } ?? []
            let text = lines.joined(separator: "\n")
            DispatchQueue.main.async {
                guard let self else { return }
                self.reading = false
                if let error {
                    self.error = error.localizedDescription
                    return
                }
                self.consume(text)
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        request.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        DispatchQueue.global(qos: .utility).async {
            try? VNImageRequestHandler(cgImage: image).perform([request])
        }
    }

    private func consume(_ next: String) {
        text = next
        let normalized = next
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        switch condition {
        case .changes:
            guard !baseline.isEmpty else { baseline = normalized; return }
            guard normalized != baseline else { changedAt = nil; return }
            if changedAt == nil { changedAt = Date(); return }
            if Date().timeIntervalSince(changedAt ?? Date()) >= 3 {
                message = "The screen changed."
                stop()
            }
        case .settles:
            if baseline.isEmpty { baseline = normalized; return }
            if normalized != baseline {
                baseline = normalized
                changedAt = Date()
            } else if let changedAt, Date().timeIntervalSince(changedAt) >= 30 {
                message = "The screen stopped changing."
                stop()
            }
        case .contains:
            let wanted = target
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !wanted.isEmpty else { return }
            if normalized.contains(wanted) {
                message = "The screen shows “\(target)”."
                stop()
            }
        }
    }
}

@MainActor
struct VorssaintWatchPane: View {
    @Bindable var state: AppState
    @State private var watch = VorssaintScreenWatch()

    var body: some View {
        Group {
            if !watch.isWatching && watch.text.isEmpty && watch.message == nil {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.085))
                            .frame(width: 64, height: 64)
                        Image(systemName: "eye")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Text("Choose any part of a window, like a progress bar, a build status or a score. The island reads it for you and tells you when it changes.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 400)
                    Button("Choose Area") {
                        watch.start()
                        NookHaptics.perform(enabled: state.settings.hapticFeedback)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    if let error = watch.error {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundStyle(VorssaintTheme.red)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                watchControls
            }
        }
        .padding(.top, 2)
        .onDisappear { watch.stop() }
    }

    private var watchControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(watch.isWatching ? "Watching the screen" : "Last reading")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(watch.isWatching ? VorssaintTheme.green : .white.opacity(0.55))
                Spacer()
                Button(watch.isWatching ? "Stop" : "Watch screen") {
                    if watch.isWatching { watch.stop() } else { watch.start() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(watch.isWatching ? VorssaintTheme.red : VorssaintTheme.orange)
            }

            HStack(alignment: .top, spacing: 10) {
                VorssaintCard(padding: 11) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What to watch")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                        Picker("Condition", selection: $watch.condition) {
                            ForEach(VorssaintWatchCondition.allCases) { condition in
                                Text(condition.title).tag(condition)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        if watch.condition == .contains {
                            TextField("Text, like Done", text: $watch.target)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10.5))
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.07)))
                        }
                        Text("Watches the main display and reads its text on this Mac. Screen Recording is required.")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.38))
                            .fixedSize(horizontal: false, vertical: true)
                        if let message = watch.message {
                            Text(message)
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(VorssaintTheme.green)
                        }
                        if let error = watch.error {
                            Text(error)
                                .font(.system(size: 9.5))
                                .foregroundStyle(VorssaintTheme.red)
                        }
                    }
                }
                .frame(width: 210)

                VorssaintCard(padding: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(watch.isWatching ? "Live reading" : "Last reading")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                        ScrollView {
                            Text(watch.text.isEmpty ? "Nothing read yet." : watch.text)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}
