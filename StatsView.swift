//
//  StatsView.swift
//  container-manager
//
//  Real-time statistics and monitoring
//

import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @State private var selectedContainer: String?
    @State private var timeRange: TimeRange = .fifteenMinutes
    @State private var showingDetailedStats = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Container Statistics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .frame(width: 250)
            }
            .padding()
            
            Divider()
            
            if containerMonitor.containers.isEmpty {
                emptyState
            } else {
                statsContent
            }
        }
        .sheet(isPresented: $showingDetailedStats) {
            if let containerName = selectedContainer {
                DetailedStatsView(
                    containerName: containerName,
                    timeRange: $timeRange
                )
                .environmentObject(containerMonitor)
                .frame(minWidth: 800, minHeight: 600)
            }
        }
    }
    
    // MARK: - Stats Content
    
    private var statsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // System Overview
                systemOverviewSection
                
                // Per-container stats
                ForEach(runningContainers) { container in
                    containerStatsCard(for: container)
                        .id("\(container.id)-\(timeRange.rawValue)")
                }
            }
            .padding()
        }
    }
    
    private var runningContainers: [ContainerInfo] {
        containerMonitor.containers.filter { container in
            let status = container.status.lowercased()
            return status == "running" || status == "up" || status.contains("running")
        }
    }
    
    // MARK: - System Stats Computed Properties
    
    private var systemCPUValue: String {
        guard let stats = containerMonitor.statsCollector?.systemStats else {
            return "-"
        }
        return String(format: "%.1f%%", stats.averageCPU)
    }
    
    private var systemMemoryValue: String {
        guard let stats = containerMonitor.statsCollector?.systemStats else {
            return "-"
        }
        return String(format: "%.0f MB", stats.totalMemoryMB)
    }
    
    private var systemNetworkValue: String {
        guard let stats = containerMonitor.statsCollector?.systemStats else {
            return "-"
        }
        let totalMB = (stats.networkRxBytesPerSec + stats.networkTxBytesPerSec) / (1024 * 1024)
        return String(format: "%.2f MB/s", totalMB)
    }
    
    // MARK: - Formatters

    private func formatBytes(_ bytes: Double) -> String {
        let kb = bytes / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.1f KB", kb)
        } else {
            return String(format: "%.0f B", bytes)
        }
    }

    // MARK: - Container Stats Helpers

    private func containerCPUValue(for containerName: String) -> String {
        guard let history = containerMonitor.statsCollector?.containerStats[containerName],
              let latest = history.latestSnapshot() else {
            return "-"
        }
        return String(format: "%.1f%%", latest.cpuPercent)
    }
    
    private func containerMemoryValue(for containerName: String) -> String {
        guard let history = containerMonitor.statsCollector?.containerStats[containerName],
              let latest = history.latestSnapshot() else {
            return "-"
        }
        return String(format: "%.0f MB", latest.memoryUsageMB)
    }
    
    private func containerNetworkValue(for containerName: String) -> String {
        guard let history = containerMonitor.statsCollector?.containerStats[containerName] else {
            return "-"
        }
        let throughput = history.networkThroughput(for: timeRange)
        let totalMBps = (throughput.rx + throughput.tx) / (1024 * 1024)
        return String(format: "↓↑ %.2f MB/s", totalMBps)
    }
    
    // MARK: - System Overview
    
    private var systemOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Overview")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Containers",
                    value: "\(containerMonitor.containers.count)",
                    subtitle: "\(runningContainers.count) running",
                    icon: "shippingbox.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "CPU Usage",
                    value: systemCPUValue,
                    subtitle: "System wide",
                    icon: "cpu",
                    color: .green
                )
                
                StatCard(
                    title: "Memory",
                    value: systemMemoryValue,
                    subtitle: "Total used",
                    icon: "memorychip",
                    color: .orange
                )
                
                StatCard(
                    title: "Network",
                    value: systemNetworkValue,
                    subtitle: "Combined I/O",
                    icon: "network",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Container Stats Card
    
    @ViewBuilder
    private func containerStatsCard(for container: ContainerInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.name)
                        .font(.headline)
                    
                    if let image = container.image {
                        Text(image)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()

                Button("Details") {
                    selectedContainer = container.name
                    showingDetailedStats = true
                }
                .controlSize(.small)
            }
            
            // Charts
            HStack(spacing: 16) {
                // CPU Chart
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CPU")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(containerCPUValue(for: container.name))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    
                    if let data = containerMonitor.statsCollector?.containerStats[container.name]?.dataPoints(for: timeRange), !data.isEmpty {
                        CPUChart(data: data, timeRange: timeRange)
                    } else {
                        Rectangle()
                            .fill(Color.green.opacity(0.1))
                            .frame(height: 60)
                            .overlay(
                                Text("No data")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                
                // Memory Chart
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(containerMemoryValue(for: container.name))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    
                    if let data = containerMonitor.statsCollector?.containerStats[container.name]?.dataPoints(for: timeRange), !data.isEmpty {
                        MemoryChart(data: data, timeRange: timeRange)
                    } else {
                        Rectangle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(height: 60)
                            .overlay(
                                Text("No data")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
            }
            
            // Network I/O Chart
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Network I/O")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // Legend
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 6, height: 6)
                            Text("RX")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(.purple)
                                .frame(width: 12, height: 2)
                            Text("TX")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(containerNetworkValue(for: container.name))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                }

                if let data = containerMonitor.statsCollector?.containerStats[container.name]?.dataPoints(for: timeRange), !data.isEmpty {
                    NetworkIOChart(data: data, timeRange: timeRange)
                } else {
                    Rectangle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(height: 60)
                        .overlay(
                            Text("No data")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        )
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Statistics Available")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Start some containers to see statistics")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .imageScale(.large)
                
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Detailed Stats View

struct DetailedStatsView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @Environment(\.dismiss) var dismiss
    let containerName: String
    @Binding var timeRange: TimeRange

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detailed Statistics")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(containerName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .frame(width: 250)

                Button("Close") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // CPU Chart (Large)
                    chartSection(
                        title: "CPU Usage",
                        icon: "cpu",
                        color: .green
                    ) {
                        if let data = containerMonitor.statsCollector?.containerStats[containerName]?.dataPoints(for: timeRange), !data.isEmpty {
                            CPUChart(data: data, timeRange: timeRange, height: 200, showXAxis: true)
                        } else {
                            emptyChartPlaceholder
                        }
                    }
                    .id("cpu-section-\(timeRange.rawValue)")

                    // Memory Chart (Large)
                    chartSection(
                        title: "Memory Usage",
                        icon: "memorychip",
                        color: .orange
                    ) {
                        if let data = containerMonitor.statsCollector?.containerStats[containerName]?.dataPoints(for: timeRange), !data.isEmpty {
                            MemoryChart(data: data, timeRange: timeRange, height: 200, showXAxis: true)
                        } else {
                            emptyChartPlaceholder
                        }
                    }
                    .id("memory-section-\(timeRange.rawValue)")

                    // Network I/O Chart (Large)
                    chartSection(
                        title: "Network I/O",
                        icon: "network",
                        color: .purple
                    ) {
                        if let data = containerMonitor.statsCollector?.containerStats[containerName]?.dataPoints(for: timeRange), !data.isEmpty {
                            NetworkIOChart(data: data, timeRange: timeRange, height: 200, showXAxis: true)

                            // Legend
                            HStack(spacing: 24) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(.blue)
                                        .frame(width: 10, height: 10)
                                    Text("Received (RX)")
                                        .font(.caption)
                                }

                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.purple)
                                        .frame(width: 20, height: 3)
                                    Text("Transmitted (TX)")
                                        .font(.caption)
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            emptyChartPlaceholder
                        }
                    }
                    .id("network-section-\(timeRange.rawValue)")

                    // Block I/O Chart (Large)
                    chartSection(
                        title: "Block I/O",
                        icon: "internaldrive",
                        color: .cyan
                    ) {
                        if let data = containerMonitor.statsCollector?.containerStats[containerName]?.dataPoints(for: timeRange), !data.isEmpty {
                            BlockIOChart(data: data, timeRange: timeRange)

                            // Legend
                            HStack(spacing: 24) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(.cyan)
                                        .frame(width: 10, height: 10)
                                    Text("Read")
                                        .font(.caption)
                                }

                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(.pink)
                                        .frame(width: 20, height: 3)
                                    Text("Write")
                                        .font(.caption)
                                }
                            }
                            .padding(.top, 8)
                        } else {
                            emptyChartPlaceholder
                        }
                    }
                    .id("blockio-section-\(timeRange.rawValue)")

                    // Statistics Summary
                    if let history = containerMonitor.statsCollector?.containerStats[containerName] {
                        statsSummarySection(history: history)
                    }
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func chartSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .imageScale(.large)

                Text(title)
                    .font(.headline)

                Spacer()
            }

            content()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var emptyChartPlaceholder: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .frame(height: 200)
            .overlay(
                Text("No data available")
                    .foregroundStyle(.secondary)
            )
    }

    @ViewBuilder
    private func statsSummarySection(history: ContainerStatsHistory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics Summary")
                .font(.headline)

            HStack(spacing: 16) {
                summaryCard(
                    title: "Avg CPU",
                    value: String(format: "%.1f%%", history.averageCPU(for: timeRange)),
                    color: .green
                )

                summaryCard(
                    title: "Avg Memory",
                    value: String(format: "%.0f MB", history.averageMemory(for: timeRange)),
                    color: .orange
                )

                summaryCard(
                    title: "Peak Memory",
                    value: String(format: "%.0f MB", history.peakMemory(for: timeRange)),
                    color: .red
                )

                let throughput = history.networkThroughput(for: timeRange)
                summaryCard(
                    title: "Network",
                    value: "↓ \(formatBytes(throughput.rx))/s\n↑ \(formatBytes(throughput.tx))/s",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatBytes(_ bytes: Double) -> String {
        let kb = bytes / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.1f KB", kb)
        } else {
            return String(format: "%.0f B", bytes)
        }
    }
}

// MARK: - Reusable Chart Components

struct CPUChart: View {
    let data: [ContainerStatsSnapshot]
    let timeRange: TimeRange
    let height: CGFloat
    let showXAxis: Bool
    
    init(data: [ContainerStatsSnapshot], timeRange: TimeRange, height: CGFloat = 60, showXAxis: Bool = false) {
        self.data = data
        self.timeRange = timeRange
        self.height = height
        self.showXAxis = showXAxis
    }
    
    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("CPU %", point.cpuPercent)
            )
            .foregroundStyle(.green.gradient)
            .lineStyle(StrokeStyle(lineWidth: showXAxis ? 3 : 2))

            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("CPU %", point.cpuPercent)
            )
            .foregroundStyle(.green.gradient.opacity(showXAxis ? 0.15 : 0.1))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            if showXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) { value in
                    AxisValueLabel(format: .dateTime.hour().minute())
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            if showXAxis {
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)%")
                        }
                    }
                    AxisGridLine()
                }
            } else {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)%")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
        }
        .frame(height: height)
        .id("cpu-\(timeRange.rawValue)-\(showXAxis)")
    }
}

struct MemoryChart: View {
    let data: [ContainerStatsSnapshot]
    let timeRange: TimeRange
    let height: CGFloat
    let showXAxis: Bool
    
    init(data: [ContainerStatsSnapshot], timeRange: TimeRange, height: CGFloat = 60, showXAxis: Bool = false) {
        self.data = data
        self.timeRange = timeRange
        self.height = height
        self.showXAxis = showXAxis
    }
    
    var body: some View {
        Chart(data) { point in
            AreaMark(
                x: .value("Time", point.timestamp),
                y: .value("Memory MB", point.memoryUsageMB)
            )
            .foregroundStyle(.orange.gradient.opacity(0.3))

            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Memory MB", point.memoryUsageMB)
            )
            .foregroundStyle(.orange)
            .lineStyle(StrokeStyle(lineWidth: showXAxis ? 3 : 2))
        }
        .chartXAxis {
            if showXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) { value in
                    AxisValueLabel(format: .dateTime.hour().minute())
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        if showXAxis {
                            Text("\(Int(doubleValue)) MB")
                        } else {
                            Text("\(Int(doubleValue))")
                                .font(.caption2)
                        }
                    }
                }
                AxisGridLine()
            }
        }
        .frame(height: height)
        .id("memory-\(timeRange.rawValue)-\(showXAxis)")
    }
}

struct NetworkIOChart: View {
    let data: [ContainerStatsSnapshot]
    let timeRange: TimeRange
    let height: CGFloat
    let showXAxis: Bool
    
    init(data: [ContainerStatsSnapshot], timeRange: TimeRange, height: CGFloat = 60, showXAxis: Bool = false) {
        self.data = data
        self.timeRange = timeRange
        self.height = height
        self.showXAxis = showXAxis
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let kb = bytes / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.1f KB", kb)
        } else {
            return String(format: "%.0f B", bytes)
        }
    }
    
    var body: some View {
        Chart {
            ForEach(data) { point in
                // RX (Download)
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value(showXAxis ? "Bytes" : "MB", showXAxis ? Double(point.networkRxBytes) : point.networkRxMB)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: showXAxis ? 3 : 2))

                AreaMark(
                    x: .value("Time", point.timestamp),
                    y: .value(showXAxis ? "Bytes" : "MB", showXAxis ? Double(point.networkRxBytes) : point.networkRxMB)
                )
                .foregroundStyle(.blue.gradient.opacity(showXAxis ? 0.15 : 0.1))

                // TX (Upload)
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value(showXAxis ? "Bytes" : "MB", showXAxis ? Double(point.networkTxBytes) : point.networkTxMB)
                )
                .foregroundStyle(.purple)
                .lineStyle(StrokeStyle(lineWidth: showXAxis ? 3 : 2, dash: showXAxis ? [8, 4] : [5, 3]))
            }
        }
        .chartXAxis {
            if showXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) { value in
                    AxisValueLabel(format: .dateTime.hour().minute())
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        if showXAxis {
                            Text(formatBytes(doubleValue))
                        } else {
                            Text(formatBytes(doubleValue * 1024 * 1024))
                                .font(.caption2)
                        }
                    }
                }
                AxisGridLine()
            }
        }
        .frame(height: height)
        .id("network-\(timeRange.rawValue)-\(showXAxis)")
    }
}

struct BlockIOChart: View {
    let data: [ContainerStatsSnapshot]
    let timeRange: TimeRange
    let height: CGFloat
    
    init(data: [ContainerStatsSnapshot], timeRange: TimeRange, height: CGFloat = 200) {
        self.data = data
        self.timeRange = timeRange
        self.height = height
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let kb = bytes / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.1f KB", kb)
        } else {
            return String(format: "%.0f B", bytes)
        }
    }
    
    var body: some View {
        Chart {
            ForEach(data) { point in
                // Read
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Bytes", point.blockReadBytes)
                )
                .foregroundStyle(.cyan)
                .lineStyle(StrokeStyle(lineWidth: 3))

                // Write
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Bytes", point.blockWriteBytes)
                )
                .foregroundStyle(.pink)
                .lineStyle(StrokeStyle(lineWidth: 3, dash: [8, 4]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 8)) { value in
                AxisValueLabel(format: .dateTime.hour().minute())
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatBytes(doubleValue))
                    }
                }
                AxisGridLine()
            }
        }
        .frame(height: height)
        .id("blockio-\(timeRange.rawValue)")
    }
}

// MARK: - Preview

#Preview {
    StatsView()
        .environmentObject(ContainerSystemMonitor())
        .frame(width: 900, height: 600)
}
