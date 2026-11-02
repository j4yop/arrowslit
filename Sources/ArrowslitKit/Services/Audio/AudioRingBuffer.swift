import Darwin
import Foundation

final class AudioRingBuffer: @unchecked Sendable {
    private let capacityFrames: Int
    private let storage: UnsafeMutablePointer<Float>
    /// [0] = next frame to read (consumer), [1] = next frame to write
    /// (producer), [2] = the bits of the current sample rate.
    private let positions: UnsafeMutablePointer<Int64>

    /// `startingFramePosition` exists for tests that exercise long-running streams.
    init(sampleRate: Double = 44_100, capacityFrames: Int = 1 << 16, startingFramePosition: Int64 = 0) {
        var cap = 1
        while cap < capacityFrames { cap <<= 1 }
        self.capacityFrames = cap
        storage = .allocate(capacity: cap * 2)
        storage.initialize(repeating: 0, count: cap * 2)
        positions = .allocate(capacity: 3)
        positions.initialize(repeating: startingFramePosition, count: 2)
        (positions + 2).initialize(to: Int64(bitPattern: (sampleRate > 0 ? sampleRate : 44_100).bitPattern))
    }

    /// The rate the producer writes at. The device can renegotiate it under a
    /// running tap (a headset switching to a call), so the reader looks it up
    /// on every read instead of keeping the value from build time.
    var sampleRate: Double {
        get { Double(bitPattern: UInt64(bitPattern: OSAtomicAdd64Barrier(0, positions + 2))) }
        set {
            guard newValue > 0, newValue.isFinite else { return }
            let replacement = Int64(bitPattern: newValue.bitPattern)
            while true {
                let current = OSAtomicAdd64Barrier(0, positions + 2)
                if OSAtomicCompareAndSwap64Barrier(current, replacement, positions + 2) { return }
            }
        }
    }

    deinit {
        storage.deallocate()
        positions.deallocate()
    }

    private var head: UnsafeMutablePointer<Int64> { positions }
    private var tail: UnsafeMutablePointer<Int64> { positions + 1 }

    /// Producer: Called from Core Audio realtime IO thread. Zero allocations, no locks.
    /// `frames` holds `channels` interleaved samples per frame: a mono source
    /// plays on both sides, and only the first two of more channels are kept.
    func write(frames: UnsafePointer<Float>, frameCount: Int, channels: Int = 2, gain: Float) {
        guard channels > 0 else { return }
        let t = OSAtomicAdd64Barrier(0, tail)
        let h = OSAtomicAdd64Barrier(0, head)
        let used = min(capacityFrames, max(0, Int(t - h)))
        let count = min(frameCount, capacityFrames - used)
        guard count > 0 else { return }

        let mask = Int64(capacityFrames - 1)
        let right = min(1, channels - 1)
        for i in 0..<count {
            let slot = Int((t + Int64(i)) & mask) * 2
            let frame = i * channels
            storage[slot] = frames[frame] * gain
            storage[slot + 1] = frames[frame + right] * gain
        }
        _ = OSAtomicAdd64Barrier(Int64(count), tail)
    }

    /// How far the producer has written. Safe to read from any thread: it
    /// only records a position for the consumer to skip to later.
    var writePosition: Int64 { OSAtomicAdd64Barrier(0, tail) }

    /// Consumer (the feed queue) only: frames written and not yet read.
    var availableFrames: Int {
        let h = OSAtomicAdd64Barrier(0, head)
        let t = OSAtomicAdd64Barrier(0, tail)
        return max(0, Int(t - h))
    }

    /// Consumer (the feed queue) only: moves the read position forward to
    /// `position`, never past what has been written, never backwards.
    func skip(to position: Int64) {
        let h = OSAtomicAdd64Barrier(0, head)
        let target = min(position, OSAtomicAdd64Barrier(0, tail))
        if target > h { _ = OSAtomicAdd64Barrier(target - h, head) }
    }

    /// Consumer: Called from the AirPlay streaming feed queue.
    @discardableResult
    func read(into destination: UnsafeMutablePointer<Float>, frameCount: Int) -> Int {
        let h = OSAtomicAdd64Barrier(0, head)
        let t = OSAtomicAdd64Barrier(0, tail)
        let count = min(frameCount, max(0, Int(t - h)))

        let mask = Int64(capacityFrames - 1)
        for i in 0..<count {
            let slot = Int((h + Int64(i)) & mask) * 2
            destination[i * 2] = storage[slot]
            destination[i * 2 + 1] = storage[slot + 1]
        }
        if count < frameCount {
            (destination + count * 2).update(repeating: 0, count: (frameCount - count) * 2)
        }
        if count > 0 {
            _ = OSAtomicAdd64Barrier(Int64(count), head)
        }
        return count
    }
}
