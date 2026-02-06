//
//  ContainerInspectorView.swift
//  container-manager
//
//  Inspector panel showing detailed container information
//

import SwiftUI

struct ContainerInspectorView: View {
    @Binding var container: ContainerInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            if let container = container {
                containerInspector(for: container)
            } else {
                emptyInspector
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
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
                        Button(action: {}) {
                            Label("View Logs", systemImage: "doc.text")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        
                        Button(action: {}) {
                            Label("Open Terminal", systemImage: "terminal")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        
                        Button(action: {}) {
                            Label("View Files", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                    }
                }
                
                // Resource Usage (placeholder)
                InspectorSection(title: "Resource Usage") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CPU")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("-")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Memory")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("-")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
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
