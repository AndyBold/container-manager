//
//  ContentView.swift
//  container-manager
//
//  Created by Andrew Bold on 30/12/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @State private var showStopConfirmation = false
    @State private var hasShownInitialPrompt = false
    
    private var runningContainers: [ContainerInfo] {
        containerMonitor.containers.filter { container in
            let status = container.status.lowercased()
            return status == "running" || status == "up" || status.contains("running")
        }
    }
    
    private var stoppedContainers: [ContainerInfo] {
        containerMonitor.containers.filter { container in
            let status = container.status.lowercased()
            return status == "stopped" || status == "exited" || status.contains("exit")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(containerMonitor.status.color)
                    .imageScale(.large)
                
                VStack(alignment: .leading) {
                    Text("Container System")
                        .font(.headline)
                    Text(containerMonitor.status.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Prompt banner when stopped
            if containerMonitor.status == .stopped && !hasShownInitialPrompt {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Service is not running")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 8) {
                        Button("Start Service") {
                            hasShownInitialPrompt = true
                            containerMonitor.startContainerService()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(containerMonitor.isOperating)
                        
                        Button("Dismiss") {
                            hasShownInitialPrompt = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                
                Divider()
            }
            
            // Container list or empty state
            if !containerMonitor.containers.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Running containers section
                        if !runningContainers.isEmpty {
                            HStack {
                                Text("Running")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("\(runningContainers.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            
                            ForEach(runningContainers) { container in
                                ContainerRowView(container: container)
                                    .environmentObject(containerMonitor)
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                
                                if container.id != runningContainers.last?.id {
                                    Divider()
                                        .padding(.leading, 32)
                                }
                            }
                        }
                        
                        // Stopped containers section
                        if !stoppedContainers.isEmpty {
                            if !runningContainers.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                            
                            HStack {
                                Text("Stopped")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("\(stoppedContainers.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            
                            ForEach(stoppedContainers) { container in
                                ContainerRowView(container: container)
                                    .environmentObject(containerMonitor)
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                
                                if container.id != stoppedContainers.last?.id {
                                    Divider()
                                        .padding(.leading, 32)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 350)
            } else if containerMonitor.status == .running {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    
                    Text("No containers found")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    Text("Containers will appear here when available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if containerMonitor.status == .stopped {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    
                    Text("Container service is not running")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    Button("Start Service") {
                        containerMonitor.startContainerService()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(containerMonitor.isOperating)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if containerMonitor.status == .error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                    
                    Text("Error checking container status")
                        .font(.body)
                        .foregroundStyle(.red)
                    
                    Text("Check that container tool is installed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        containerMonitor.checkContainerStatus()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            
            Divider()
            
            // Footer with actions
            VStack(spacing: 4) {
                HStack {
                    Text("Last updated: \(containerMonitor.lastUpdated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                
                HStack {
                    Button("Refresh") {
                        containerMonitor.checkContainerStatus()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(containerMonitor.isOperating)
                    
                    Spacer()
                    
                    // Service control button
                    if containerMonitor.status == .running {
                        if showStopConfirmation {
                            HStack(spacing: 4) {
                                Button("Confirm Stop", role: .destructive) {
                                    showStopConfirmation = false
                                    containerMonitor.stopContainerService()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .controlSize(.small)
                                .disabled(containerMonitor.isOperating)
                                
                                Button("Cancel") {
                                    showStopConfirmation = false
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            Button("Stop Service") {
                                showStopConfirmation = true
                            }
                            .disabled(containerMonitor.isOperating)
                        }
                    } else if containerMonitor.status == .stopped {
                        Button("Start Service") {
                            containerMonitor.startContainerService()
                        }
                        .disabled(containerMonitor.isOperating)
                    }
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: .command)
                }
            }
            .padding()
        }
        .frame(width: 300)
        .onChange(of: containerMonitor.status) { oldValue, newValue in
            // Reset prompt state when service stops
            if newValue == .stopped && oldValue == .running {
                hasShownInitialPrompt = false
                showStopConfirmation = false
            }
        }
    }
}

// MARK: - Container Row View

struct ContainerRowView: View {
    let container: ContainerInfo
    @State private var isExpanded = false
    @State private var showingRemoveConfirmation = false
    @State private var isPerformingAction = false
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    
    private var isRunning: Bool {
        let status = container.status.lowercased()
        return status == "running" || status == "up" || status.contains("running")
    }
    
    private var statusColor: Color {
        switch container.status.lowercased() {
        case let status where status == "running" || status == "up" || status.contains("running"):
            return .green
        case let status where status == "exited" || status == "stopped" || status.contains("exit"):
            return .red
        case "paused":
            return .orange
        case "restarting":
            return .yellow
        default:
            return .secondary
        }
    }
    
    private var statusIcon: String {
        switch container.status.lowercased() {
        case let status where status == "running" || status == "up" || status.contains("running"):
            return "checkmark.circle.fill"
        case let status where status == "exited" || status == "stopped" || status.contains("exit"):
            return "stop.circle.fill"
        case "paused":
            return "pause.circle.fill"
        case "restarting":
            return "arrow.clockwise.circle.fill"
        default:
            return "circle.fill"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(alignment: .top, spacing: 8) {
                    // Status indicator
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .imageScale(.medium)
                        .frame(width: 20)
                    
                    // Container info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(container.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.primary)
                        
                        if !container.status.isEmpty {
                            Text(container.status.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .padding(.vertical, 4)
                    
                    if let image = container.image {
                        DetailRow(icon: "shippingbox", label: "Image", value: image)
                    }
                    
                    if let ports = container.ports, !ports.isEmpty {
                        DetailRow(icon: "network", label: "Ports", value: ports)
                    }
                    
                    if let created = container.created {
                        DetailRow(icon: "clock", label: "Created", value: created)
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Actions
                    HStack(spacing: 8) {
                        Button("Copy Name") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(container.name, forType: .string)
                        }
                        .controlSize(.small)
                        .disabled(isPerformingAction)
                        
                        Spacer()
                        
                        if isPerformingAction {
                            ProgressView()
                                .scaleEffect(0.7)
                                .controlSize(.small)
                        }
                        
                        Menu {
                            Button("Inspect") {
                                // TODO: Open inspector window
                            }
                            .disabled(true)
                            
                            Button("View Logs") {
                                // TODO: Open logs window
                            }
                            .disabled(true)
                            
                            Divider()
                            
                            if isRunning {
                                Button("Stop") {
                                    performAction {
                                        await containerMonitor.stopContainer(named: container.name)
                                    }
                                }
                                .disabled(isPerformingAction)
                                
                                Button("Restart") {
                                    performAction {
                                        await containerMonitor.restartContainer(named: container.name)
                                    }
                                }
                                .disabled(isPerformingAction)
                            } else {
                                Button("Start") {
                                    performAction {
                                        await containerMonitor.startContainer(named: container.name)
                                    }
                                }
                                .disabled(isPerformingAction)
                            }
                            
                            Divider()
                            
                            Button("Remove", role: .destructive) {
                                showingRemoveConfirmation = true
                            }
                            .disabled(isPerformingAction)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .controlSize(.small)
                        .disabled(isPerformingAction)
                    }
                    
                    // Remove confirmation dialog
                    if showingRemoveConfirmation {
                        VStack(spacing: 8) {
                            Divider()
                                .padding(.vertical, 4)
                            
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                
                                Text("Remove \(container.name)?")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            HStack(spacing: 8) {
                                Button("Cancel", role: .cancel) {
                                    showingRemoveConfirmation = false
                                }
                                .controlSize(.small)
                                
                                Button("Remove", role: .destructive) {
                                    showingRemoveConfirmation = false
                                    performAction {
                                        await containerMonitor.removeContainer(named: container.name)
                                    }
                                }
                                .controlSize(.small)
                                .disabled(isPerformingAction)
                            }
                        }
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 4)
            }
        }
        .onChange(of: showingRemoveConfirmation) { oldValue, newValue in
            // Mark as operating when showing confirmation to prevent refreshes
            containerMonitor.isOperating = newValue
        }
    }
    
    private func performAction(_ action: @escaping () async -> Bool) {
        isPerformingAction = true
        containerMonitor.isOperating = true
        Task {
            let success = await action()
            await MainActor.run {
                isPerformingAction = false
                containerMonitor.isOperating = false
                if !success {
                    // Could show an error alert here
                    NSSound.beep()
                }
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 14)
                .font(.caption)
            
            Text(label + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .truncationMode(.middle)
            
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ContainerSystemMonitor())
}

#Preview("Container Row - Running") {
    VStack {
        ContainerRowView(container: ContainerInfo(
            name: "my-web-server",
            status: "running",
            image: "nginx:latest",
            ports: "192.168.64.5",
            created: "2 hours ago"
        ))
        .environmentObject(ContainerSystemMonitor())
        Divider()
        ContainerRowView(container: ContainerInfo(
            name: "database-postgres-15",
            status: "running",
            image: "postgres:15",
            ports: "192.168.64.6",
            created: "1 day ago"
        ))
        .environmentObject(ContainerSystemMonitor())
    }
    .padding()
    .frame(width: 300)
}

#Preview("Container Row - Stopped") {
    VStack {
        ContainerRowView(container: ContainerInfo(
            name: "redis-cache",
            status: "stopped",
            image: "redis:alpine"
        ))
        .environmentObject(ContainerSystemMonitor())
        Divider()
        ContainerRowView(container: ContainerInfo(
            name: "old-container",
            status: "exited",
            image: "ubuntu:latest"
        ))
        .environmentObject(ContainerSystemMonitor())
    }
    .padding()
    .frame(width: 300)
}

#Preview("Mixed Containers") {
    ScrollView {
        VStack(spacing: 0) {
            // Running section
            HStack {
                Text("Running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            ContainerRowView(container: ContainerInfo(
                name: "keycloak",
                status: "running",
                image: "quay.io/keycloak/keycloak:latest",
                ports: "192.168.64.5"
            ))
            .environmentObject(ContainerSystemMonitor())
            .padding(.horizontal)
            .padding(.vertical, 6)
            
            Divider().padding(.leading, 32)
            
            ContainerRowView(container: ContainerInfo(
                name: "nginx",
                status: "running",
                image: "docker.io/library/nginx:trixie",
                ports: "192.168.64.7"
            ))
            .environmentObject(ContainerSystemMonitor())
            .padding(.horizontal)
            .padding(.vertical, 6)
            
            Divider().padding(.vertical, 4)
            
            // Stopped section
            HStack {
                Text("Stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            
            ContainerRowView(container: ContainerInfo(
                name: "redis-old",
                status: "stopped",
                image: "redis:alpine"
            ))
            .environmentObject(ContainerSystemMonitor())
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
    .frame(width: 300, height: 400)
}

