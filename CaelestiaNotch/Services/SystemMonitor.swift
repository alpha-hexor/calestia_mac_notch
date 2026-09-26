import Foundation
import Combine
import IOKit.ps
import Darwin

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var usedMemory: Double = 0
    @Published private(set) var totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
    @Published private(set) var diskUsed: Double = 0
    @Published private(set) var diskTotal: Double = 0
    @Published private(set) var battery: Int?
    @Published private(set) var isCharging = false
    @Published private(set) var uptime = ProcessInfo.processInfo.systemUptime
    let hardwareModel: String
    private var previousCPU: (active: UInt64, total: UInt64)?
    private var timer: Timer?
    private var tick = 0

    init() {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        hardwareModel = String(cString: bytes)
    }

    var memoryFraction: Double { totalMemory > 0 ? usedMemory / totalMemory : 0 }
    var diskFraction: Double { diskTotal > 0 ? diskUsed / diskTotal : 0 }
    var uptimeLabel: String {
        let minutes = Int(uptime) / 60
        if minutes >= 1440 { return "\(minutes / 1440)d \((minutes % 1440) / 60)h" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    func start() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    private func sample() {
        sampleCPU()
        sampleMemory()
        uptime = ProcessInfo.processInfo.systemUptime
        if tick % 15 == 0 { sampleDisk(); sampleBattery() }
        tick += 1
    }

    private func sampleCPU() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let ticks = info.cpu_ticks
        let active = UInt64(ticks.0) + UInt64(ticks.1) + UInt64(ticks.3)
        let total = active + UInt64(ticks.2)
        if let previousCPU, total > previousCPU.total, active >= previousCPU.active {
            cpuUsage = min(1, Double(active - previousCPU.active) / Double(total - previousCPU.total))
        }
        previousCPU = (active, total)
    }

    private func sampleMemory() {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        // Active + wired + compressor, excluding purgeable pages; not memory pressure.
        let pages = Double(info.active_count) + Double(info.wire_count) + Double(info.compressor_page_count) - Double(info.purgeable_count)
        usedMemory = min(totalMemory, max(0, pages * Double(vm_kernel_page_size)))
    }

    private func sampleDisk() {
        do {
            let values = try URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            diskTotal = Double(values.volumeTotalCapacity ?? 0)
            diskUsed = max(0, diskTotal - Double(values.volumeAvailableCapacity ?? 0))
        } catch { diskTotal = 0; diskUsed = 0 }
    }

    private func sampleBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return }
        battery = nil
        for source in sources {
            guard let values = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  values[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = values[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = values[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            battery = min(100, max(0, Int(Double(current) / Double(maximum) * 100)))
            isCharging = values[kIOPSIsChargingKey] as? Bool ?? false
            break
        }
    }
}
