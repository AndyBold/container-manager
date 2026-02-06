//
//  SettingsView.swift
//  container-manager
//
//  Application settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("autoStartService") private var autoStartService = false
    @AppStorage("refreshInterval") private var refreshInterval = 10.0
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("containerToolPath") private var containerToolPath = ""
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Auto-start container service", isOn: $autoStartService)
                    .help("Automatically start the container service when the app launches")
                
                Toggle("Show notifications", isOn: $showNotifications)
                    .help("Show notifications for container events")
                
                HStack {
                    Text("Refresh interval")
                    Spacer()
                    TextField("Seconds", value: $refreshInterval, format: .number)
                        .frame(width: 60)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                }
                .help("How often to check container status")
            }
            
            Section("Container Tool") {
                HStack {
                    TextField("Path to container executable", text: $containerToolPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse...") {
                        selectContainerPath()
                    }
                }
                .help("Path to the container command-line tool")
                
                Text("Leave empty to auto-detect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Appearance") {
                Picker("View mode", selection: .constant("list")) {
                    Text("List").tag("list")
                    Text("Grid").tag("grid")
                }
                .help("Default view mode for container lists")
                
                Toggle("Show inspector panel", isOn: .constant(true))
                    .help("Show the inspector panel by default")
            }
            
            Section("Advanced") {
                Toggle("Enable verbose logging", isOn: .constant(false))
                    .help("Write detailed logs for debugging")
                
                Button("Reset to Defaults") {
                    resetSettings()
                }
                .foregroundStyle(.red)
            }
            
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Container Manager")
                            .font(.headline)
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("About") {
                        showAbout()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .padding()
    }
    
    // MARK: - Actions
    
    private func selectContainerPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the container executable"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                containerToolPath = url.path
            }
        }
    }
    
    private func resetSettings() {
        autoStartService = false
        refreshInterval = 10.0
        showNotifications = true
        containerToolPath = ""
    }
    
    private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .frame(width: 700, height: 600)
}
