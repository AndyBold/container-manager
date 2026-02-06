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
                    // TODO: Open detailed stats
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
                        Chart(data) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("CPU %", point.cpuPercent)
                            )
                            .foregroundStyle(.green)
                            .interpolationMethod(.catmullRom)
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading, values: [0, 50, 100])
                        }
                        .frame(height: 60)
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
                        Chart(data) { point in
                            AreaMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Memory MB", point.memoryUsageMB)
                            )
                            .foregroundStyle(.orange.gradient.opacity(0.6))
                            .interpolationMethod(.catmullRom)
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 60)
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
                    Text(containerNetworkValue(for: container.name))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                }
                
                if let data = containerMonitor.statsCollector?.containerStats[container.name]?.dataPoints(for: timeRange), !data.isEmpty {
                    Chart {
                        ForEach(data) { point in
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("RX MB", point.networkRxMB)
                            )
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("TX MB", point.networkTxMB)
                            )
                            .foregroundStyle(.purple)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 60)
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

// MARK: - Preview

#Preview {
    StatsView()
        .environmentObject(ContainerSystemMonitor())
        .frame(width: 900, height: 600)
}
