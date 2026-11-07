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
    public private(set) var diskFree: Int64 = 0
    public private(set) var diskTotal: Int64 = 0
    public private(set) var networkIn: Double = 0
    public private(set) var networkOut: Double = 0
    public private(set) var hasReading = false
    public private(set) var isRunning = false
    /// Seconds between samples; changed from Settings.
    public var refreshInterval: TimeInterval = 2

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastCPU: CPUSample?
    @ObservationIgnored private var lastNetwork: (received: UInt64, sent: UInt64, at: Date)?
    @ObservationIgnored private var lastDiskCheck = Date.distantPast
    private static let pageSize = UInt64(getpagesize())

    public init() {}

    public var memoryShare: Double {
        memoryTotal > 0 ? min(1, Double(memoryUsed) / Double(memoryTotal)) : 0
    }

    public var diskShare: Double {
        diskTotal > 0 ? min(1, max(0, Double(diskTotal - diskFree) / Double(diskTotal))) : 0
    }

    public func start() {
        guard timer == nil else { return }
        isRunning = true
        lastNetwork = nil
        lastDiskCheck = .distantPast
        sample()
        let timer = Timer(timeInterval: max(1, refreshInterval), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func setRefreshInterval(_ value: TimeInterval) {
        refreshInterval = max(1, value)
        if isRunning {
            stop()
            start()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        lastCPU = nil
        lastNetwork = nil
        lastDiskCheck = .distantPast
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

        let now = Date()
        if let network = Self.readNetwork() {
            if let last = lastNetwork {
                let seconds = now.timeIntervalSince(last.at)
                networkIn = StatsMath.rate(from: last.received, to: network.received, seconds: seconds)
                networkOut = StatsMath.rate(from: last.sent, to: network.sent, seconds: seconds)
            }
            lastNetwork = (network.received, network.sent, now)
        }
        if now.timeIntervalSince(lastDiskCheck) > 60, let disk = Self.readDisk() {
            diskFree = disk.free
            diskTotal = disk.total
            lastDiskCheck = now
        }
    }

    private static func readNetwork() -> (received: UInt64, sent: UInt64)? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            let flags = Int32(entry.ifa_flags)
            guard StatsMath.countsTraffic(interface: String(cString: entry.ifa_name)),
                  entry.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let data = entry.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            received += UInt64(data.pointee.ifi_ibytes)
            sent += UInt64(data.pointee.ifi_obytes)
        }
        return (received, sent)
    }

    private static func readDisk() -> (free: Int64, total: Int64)? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity else { return nil }
        return (free, Int64(total))
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
