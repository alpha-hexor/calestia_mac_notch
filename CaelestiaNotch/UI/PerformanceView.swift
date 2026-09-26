import SwiftUI

struct PerformanceView: View {
    @ObservedObject var system: SystemMonitor

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                MetricGauge(fraction: system.cpuUsage, value: "\(Int(system.cpuUsage * 100))%", title: "CPU usage",
                            symbol: "cpu", detail: "\(ProcessInfo.processInfo.activeProcessorCount) logical cores", color: Palette.accent)
                MetricGauge(fraction: system.memoryFraction, value: gibibytes(system.usedMemory), title: "Memory used",
                            symbol: "memorychip", detail: "of \(gibibytes(system.totalMemory)) GiB", color: Palette.muted)
                MetricGauge(fraction: system.diskFraction, value: system.diskTotal > 0 ? "\(Int(system.diskFraction * 100))%" : "—", title: "Storage used",
                            symbol: "internaldrive", detail: system.diskTotal > 0 ? "\(gibibytes(system.diskTotal - system.diskUsed)) GiB available" : "Storage unavailable", color: Palette.olive)
            }
            HStack(spacing: 6) {
                Circle().fill(Palette.olive).frame(width: 5, height: 5)
                Text("LIVE METRICS").tracking(1.4)
                Text("·  CPU & memory every 2s  ·  storage every 30s")
            }.font(.system(size: 9)).foregroundStyle(Palette.muted)
        }
    }

    private func gibibytes(_ bytes: Double) -> String { String(format: "%.1f", bytes / 1_073_741_824) }
}

private struct MetricGauge: View {
    let fraction: Double
    let value: String
    let title: String
    let symbol: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().trim(from: 0, to: 0.82).stroke(Palette.peach.opacity(0.65), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(122.4))
                Circle().trim(from: 0, to: max(0.003, min(1, fraction)) * 0.82)
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(122.4))
                    .animation(.easeInOut(duration: 0.8), value: fraction)
                VStack(spacing: 6) {
                    Image(systemName: symbol).font(.system(size: 17, weight: .light)).foregroundStyle(color)
                    Text(value).font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit()
                    Text(title).font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }.frame(width: 164, height: 164)
            Text(detail).font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
