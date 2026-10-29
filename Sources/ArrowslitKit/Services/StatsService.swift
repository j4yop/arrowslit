import Darwin
import Foundation
import Observation

@MainActor
@Observable
public final class StatsService {
    public private(set) var cpu: Double = 0
    public private(set) var memoryUsed: UInt64 = 0
    public private(set) var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    public private(set) var pressure: UsageLevel = .normal
    public private(set) var hasReading = false
    public private(set) var isRunning = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastCPU: CPUSample?
    private static let pageSize = UInt64(getpagesize())

    public init() {}

    public var memoryShare: Double {
        memoryTotal > 0 ? min(1, Double(memoryUsed) / Double(memoryTotal)) : 0
    }

    public func start() {
        guard timer == nil else { return }
        isRunning = true
        sample()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        lastCPU = nil
        hasReading = false
    }

    private func sample() {
        if let sample = Self.readCPU() {
            if let lastCPU {
                cpu = StatsMath.cpuUsage(from: lastCPU, to: sample)
                hasReading = true
            }
            lastCPU = sample
        }
        if let used = Self.readMemory() {
            memoryUsed = used
        }
        pressure = StatsMath.pressure(Self.readPressure())
    }

    private static func readCPU() -> CPUSample? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUSample(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    private static func readMemory() -> UInt64? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let internalPages = UInt64(info.internal_page_count)
        let purgeable = min(internalPages, UInt64(info.purgeable_count))
        let app = internalPages - purgeable
        return (app + UInt64(info.wire_count) + UInt64(info.compressor_page_count)) * pageSize
    }

    private static func readPressure() -> Int32 {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            return 1
        }
        return level
    }
}
