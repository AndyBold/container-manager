//
//  ContainerInspectorView.swift
//  container-manager
//
//  Inspector panel showing detailed container information
//

import SwiftUI

struct ContainerInspectorView: View {
    @Binding var container: ContainerInfo?
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @Environment(\.openWindow) private var openWindow
    @State private var containerDetails: ContainerDetails?
    @State private var isLoadingDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let container = container {
                containerInspector(for: container)
            } else {
                emptyInspector
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: container?.name) { _, newName in
            loadContainerDetails(for: newName)
        }
        .onAppear {
            loadContainerDetails(for: container?.name)
        }
    }
    
    // MARK: - Container Inspector
    
    @ViewBuilder
    private func containerInspector(for container: ContainerInfo) -> some View {
        // Header
        HStack {
            Text("Inspector")
                .font(.headline)
            Spacer()
            Button(action: { self.container = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        
        Divider()
        
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Overview Section
                InspectorSection(title: "Overview") {
                    InspectorRow(label: "Name", value: container.name, copyable: true)
                    InspectorRow(label: "Status", value: container.status.capitalized)
                    
                    if let image = container.image {
                        InspectorRow(label: "Image", value: image, copyable: true)
                    }
                    
                    if let created = container.created {
                        InspectorRow(label: "Created", value: created)
                    }
                }
                
                // Network Section
                if let ports = container.ports {
                    InspectorSection(title: "Network") {
                        InspectorRow(label: "Address", value: ports, copyable: true)
                    }
                }
                
                // Quick Actions
                InspectorSection(title: "Quick Actions") {
                    VStack(spacing: 8) {
                        Button(action: { openLogs(for: container) }) {
                            Label("View Logs", systemImage: "doc.text")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        
                        Button(action: { openTerminal(for: container) }) {
                            Label("Open Terminal", systemImage: "terminal")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .disabled(!container.status.lowercased().contains("running"))
                        
                        Button(action: { openFiles(for: container) }) {
                            Label("View Files", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .disabled(!container.status.lowercased().contains("running"))
                    }
                }
                
                // Resource Usage (live stats)
                InspectorSection(title: "Resource Usage") {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CPU")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(cpuValue(for: container.name))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Memory")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(memoryValue(for: container.name))
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            }
                            
                            Spacer()
                        }
                        
                        // Network stats
                        if let stats = containerMonitor.statsCollector?.containerStats[container.name]?.latestSnapshot() {
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Network RX")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.2f MB", stats.networkRxMB))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Network TX")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.2f MB", stats.networkTxMB))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                // Environment Variables
                if let details = containerDetails, !details.environmentVariables.isEmpty {
                    InspectorSection(title: "Environment Variables") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(details.environmentVariables.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text(value)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .lineLimit(3)
                                }
                                
                                if key != details.environmentVariables.sorted(by: { $0.key < $1.key }).last?.key {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                
                // Labels & Metadata
                if let details = containerDetails, !details.labels.isEmpty {
                    InspectorSection(title: "Labels") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(details.labels.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text(value)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .lineLimit(3)
                                }
                                
                                if key != details.labels.sorted(by: { $0.key < $1.key }).last?.key {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                
                // Command & Working Directory
                if let details = containerDetails {
                    InspectorSection(title: "Process Info") {
                        if let command = details.command {
                            InspectorRow(label: "Command", value: command, copyable: true)
                        }
                        if let workingDir = details.workingDir {
                            InspectorRow(label: "Work Dir", value: workingDir, copyable: true)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Empty Inspector
    
    private var emptyInspector: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("No Selection")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Select a container to view details")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Container Details Loading
    
    private func loadContainerDetails(for containerName: String?) {
        guard let containerName = containerName else {
            containerDetails = nil
            isLoadingDetails = false
            return
        }
        
        isLoadingDetails = true
        
        Task {
            let details = await containerMonitor.inspectContainer(containerName)
            
            await MainActor.run {
                self.containerDetails = details
                self.isLoadingDetails = false
            }
        }
    }
    
    // MARK: - Stats Helpers
    
    private func cpuValue(for containerName: String) -> String {
        guard let history = containerMonitor.statsCollector?.containerStats[containerName],
              let latest = history.latestSnapshot() else {
            return "-"
        }
        return String(format: "%.1f%%", latest.cpuPercent)
    }
    
    private func memoryValue(for containerName: String) -> String {
        guard let history = containerMonitor.statsCollector?.containerStats[containerName],
              let latest = history.latestSnapshot() else {
            return "-"
        }
        return String(format: "%.0f MB", latest.memoryUsageMB)
    }
    
    // MARK: - Quick Actions
    
    private func openLogs(for container: ContainerInfo) {
        openWindow(id: "logs", value: container.name)
    }
    
    private func openTerminal(for container: ContainerInfo) {
        openWindow(id: "terminal", value: container.name)
    }
    
    private func openFiles(for container: ContainerInfo) {
        // TODO: Implement file browser functionality
        // This would require creating a ContainerFileBrowserView and WindowGroup
        print("View Files not yet implemented for container: \(container.name)")
    }
}

// MARK: - Inspector Section

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - Inspector Row

struct InspectorRow: View {
    let label: String
    let value: String
    var copyable: Bool = false
    
    @State private var showCopied = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(3)
            
            Spacer(minLength: 0)
            
            if copyable {
                Button(action: copyValue) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(showCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
        }
    }
    
    private func copyValue() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        
        showCopied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }
}

// MARK: - Preview

#Preview("With Container") {
    ContainerInspectorView(
        container: .constant(
            ContainerInfo(
                name: "my-web-server",
                status: "running",
                image: "nginx:latest",
                ports: "192.168.64.5:8080",
                created: "2 hours ago"
            )
        )
    )
    .frame(width: 300, height: 600)
}

#Preview("Empty") {
    ContainerInspectorView(container: .constant(nil))
        .frame(width: 300, height: 600)
}
