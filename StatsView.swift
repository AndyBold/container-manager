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
    @State private var timeRange: TimeRange = .last15Minutes
    
    enum TimeRange: String, CaseIterable {
        case last5Minutes = "5m"
        case last15Minutes = "15m"
        case last30Minutes = "30m"
        case last1Hour = "1h"
        case last6Hours = "6h"
    }
    
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
                    value: "-",
                    subtitle: "System wide",
                    icon: "cpu",
                    color: .green
                )
                
                StatCard(
                    title: "Memory",
                    value: "-",
                    subtitle: "Total used",
                    icon: "memorychip",
                    color: .orange
                )
                
                StatCard(
                    title: "Network",
                    value: "-",
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
            
            // Placeholder charts
            HStack(spacing: 16) {
                // CPU Chart
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("CPU")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("-")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Rectangle()
                        .fill(Color.green.opacity(0.2))
                        .frame(height: 60)
                        .overlay(
                            Text("Live stats coming soon")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        )
                }
                
                // Memory Chart
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Memory")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("-")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Rectangle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(height: 60)
                        .overlay(
                            Text("Live stats coming soon")
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
