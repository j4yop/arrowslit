import Foundation

/// Pure tape-ruler maths shared by the view and tests. The ruler is a tape of minutes that
/// slides under a fixed pointer; dragging left pulls later minutes under the pointer.
public enum RulerMath {
    public static let timerRange = 1...60
    public static let focusRange = 5...60
    public static let stopwatchRange = 0...60

    public static func clamp(_ value: Double, to range: ClosedRange<Int>) -> Double {
        min(max(value, Double(range.lowerBound)), Double(range.upperBound))
    }

    /// The whole minute under the pointer after a drag translation.
    public static func minute(
        from value: Int,
        translation: Double,
        spacing: Double,
        range: ClosedRange<Int>
    ) -> Int {
        let next = clamp(Double(value) - translation / spacing, to: range)
        return min(max(Int(next.rounded()), range.lowerBound), range.upperBound)
    }

    /// The minute under a click, relative to the pointer at `center`.
    public static func tappedMinute(
        at x: Double,
        center: Double,
        current: Int,
        spacing: Double,
        range: ClosedRange<Int>
    ) -> Int {
        let next = clamp(Double(current) + (x - center) / spacing, to: range)
        return min(max(Int(next.rounded()), range.lowerBound), range.upperBound)
    }

    /// Inclusive range of minute indices that can be visible in a viewport.
    public static func visibleRange(
        value: Double,
        width: Double,
        spacing: Double,
        range: ClosedRange<Int>
    ) -> ClosedRange<Int>? {
        let visible = Int((width / spacing / 2).rounded(.up)) + 1
        let first = max(range.lowerBound, Int(value.rounded(.down)) - visible)
        let last = min(range.upperBound, Int(value.rounded(.up)) + visible)
        return first <= last ? first...last : nil
    }
}
