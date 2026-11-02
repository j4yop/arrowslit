import AppKit
import SwiftUI

/// A native minute ruler: drag, click, wheel, arrows, Home/End, VoiceOver and
/// a haptic on every changed minute. The visible ticks and the orange pointer
/// sit over a transparent NSSlider, so the interaction stays native.
struct VorssaintTimerRuler: View {
    @Binding var minutes: Int
    var range: ClosedRange<Int> = 1...180
    var onChange: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let fraction = Double(minutes - range.lowerBound) / Double(range.upperBound - range.lowerBound)
            let pointerX = max(7, min(width - 7, width * fraction))
            ZStack(alignment: .leading) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(Array(range.lowerBound...range.upperBound), id: \.self) { minute in
                            let major = minute == range.lowerBound || minute % 5 == 0
                            Rectangle()
                                .fill(.white.opacity(major ? 0.5 : 0.16))
                                .frame(width: 1, height: major ? 18 : 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .top) {
                                    if major, minute % 15 == 0 || minute == range.lowerBound {
                                        Text("\(minute)")
                                            .font(.system(size: 8, weight: .medium, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(.white.opacity(0.42))
                                            .fixedSize()
                                            .offset(y: -14)
                                    }
                                }
                        }
                    }
                    .frame(height: 22)
                }
                .padding(.horizontal, 3)
                .padding(.bottom, 4)

                Rectangle()
                    .fill(ArrowTheme.amber.opacity(0.35))
                    .frame(width: 1, height: 30)
                    .offset(x: pointerX, y: 14)
                Image(systemName: "triangle.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ArrowTheme.amber)
                    .rotationEffect(.degrees(180))
                    .offset(x: pointerX - 4, y: 4)
            }
            .overlay {
                RulerSlider(
                    value: Binding(
                        get: { Double(minutes) },
                        set: { newValue in
                            let rounded = Int(newValue.rounded())
                            guard rounded != minutes else { return }
                            minutes = min(max(rounded, range.lowerBound), range.upperBound)
                            onChange?()
                        }
                    ),
                    range: Double(range.lowerBound)...Double(range.upperBound)
                )
                .opacity(0.02)
            }
        }
        .frame(height: 54)
        .accessibilityElement()
        .accessibilityLabel("Timer minutes")
        .accessibilityValue("\(minutes) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = min(range.upperBound, minutes + 1)
            case .decrement: minutes = max(range.lowerBound, minutes - 1)
            @unknown default: break
            }
            onChange?()
        }
    }
}

private struct RulerSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>

    func makeNSView(context: Context) -> RulerSliderControl {
        let control = RulerSliderControl()
        control.minValue = range.lowerBound
        control.maxValue = range.upperBound
        control.doubleValue = value
        control.isContinuous = true
        control.target = context.coordinator
        control.action = #selector(Coordinator.changed(_:))
        return control
    }

    func updateNSView(_ nsView: RulerSliderControl, context: Context) {
        if nsView.doubleValue != value { nsView.doubleValue = value }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: RulerSlider
        init(_ parent: RulerSlider) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) {
            parent.value = sender.doubleValue.rounded()
        }
    }
}

private final class RulerSliderControl: NSSlider {
    override func scrollWheel(with event: NSEvent) {
        let step: Double = event.hasPreciseScrollingDeltas ? 0.25 : 1
        let delta = event.scrollingDeltaY > 0 ? step : -step
        doubleValue = min(max(doubleValue + delta, minValue), maxValue)
        sendAction(action, to: target)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: doubleValue = max(minValue, doubleValue - 1)
        case 124: doubleValue = min(maxValue, doubleValue + 1)
        case 115: doubleValue = minValue
        case 119: doubleValue = maxValue
        default:
            super.keyDown(with: event)
            return
        }
        sendAction(action, to: target)
    }

}
