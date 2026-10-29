import Foundation

public struct CPUSample: Equatable, Sendable {
    public var user: UInt64
    public var system: UInt64
    public var idle: UInt64
    public var nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public enum UsageLevel: Equatable, Sendable {
    case normal
    case busy
    case high
}

public enum StatsMath {
    public static func cpuUsage(from old: CPUSample, to new: CPUSample) -> Double {
        func delta(_ a: UInt64, _ b: UInt64) -> Double {
            b >= a ? Double(b - a) : 0
        }
        let busy = delta(old.user, new.user) + delta(old.system, new.system) + delta(old.nice, new.nice)
        let total = busy + delta(old.idle, new.idle)
        guard total > 0 else { return 0 }
        return min(1, busy / total)
    }

    public static func percent(_ share: Double) -> String {
        "\(Int((min(max(share, 0), 1) * 100).rounded()))%"
    }

    public static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(min(value, UInt64(Int64.max))), countStyle: .memory)
    }

    public static func level(_ share: Double) -> UsageLevel {
        switch share {
        case ..<0.70: .normal
        case ..<0.90: .busy
        default: .high
        }
    }

    public static func pressure(_ kernelLevel: Int32) -> UsageLevel {
        switch kernelLevel {
        case 4...: .high
        case 2...: .busy
        default: .normal
        }
    }
}
