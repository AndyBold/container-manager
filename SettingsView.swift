//
//  SettingsView.swift
//  container-manager
//
//  Application settings and preferences
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("autoStartService") private var autoStartService = false
    @AppStorage("refreshInterval") private var refreshInterval = 10.0
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("containerToolPath") private var containerToolPath = ""
    @AppStorage("defaultViewMode") private var defaultViewMode = "list"
    @AppStorage("showInspectorPanel") private var showInspectorPanel = true
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("showLoadingIndicators") private var showLoadingIndicators = true
    @AppStorage("compactMode") private var compactMode = false
    @AppStorage("showEmptyStateIllustrations") private var showEmptyStateIllustrations = true
    @AppStorage("verboseLogging") private var verboseLogging = false
    
    @State private var toolPathError: String?
    @State private var showingSyncConfirmation = false
    
    // System accessibility settings
    private var systemReduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    
    private var systemReduceTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
    
    private var systemIncreaseContrast: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Auto-start container service", isOn: $autoStartService)
                    .toggleStyle(.switch)
                    .tint(.green)
                    .help("Automatically start the container service when the app launches")
                
                Toggle("Show notifications", isOn: $showNotifications)
                    .toggleStyle(.switch)
                    .tint(.green)
                    .help("Show notifications for container events")
                
                HStack(alignment: .center) {
                    Text("Refresh interval")
                    Spacer()
                    TextField("", value: $refreshInterval, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: refreshInterval) { _, newValue in
                            // Clamp to valid range (2-300 seconds)
                            refreshInterval = max(2, min(300, newValue))
                        }
                    Text("seconds")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 55)
                }
                .help("How often to check container status (2-300 seconds)")
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
                
                if let error = toolPathError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Leave empty to auto-detect")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Appearance") {
                Picker("View mode", selection: $defaultViewMode) {
                    Text("List").tag("list")
                    Text("Grid").tag("grid")
                }
                .help("Default view mode for container lists")

                Toggle("Show inspector panel", isOn: $showInspectorPanel)
                    .toggleStyle(.switch)
                    .tint(.green)
                    .help("Show the inspector panel by default")

                Toggle("Compact mode", isOn: $compactMode)
                    .toggleStyle(.switch)
                    .tint(.green)
                    .help("Use denser layouts with reduced spacing")
            }

            Section("Visual Effects") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("These settings work together with macOS Accessibility preferences.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Button(action: openAccessibilitySettings) {
                            Text("Open Accessibility Settings")
                                .font(.caption)
                        }
                        .buttonStyle(.link)
                        
                        Button(action: syncWithSystemSettings) {
                            Label("Sync with System", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Align app preferences with current macOS accessibility settings")
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                
                Toggle("Enable animations", isOn: $enableAnimations)
                    .toggleStyle(.switch)
                    .tint(.green)
                    .help("Enable smooth transitions and animations throughout the app")

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Reduce motion", isOn: $reduceMotion)
                        .toggleStyle(.switch)
                        .tint(.green)
                        .help("Minimize motion effects for accessibility")
                        .disabled(!enableAnimations || systemReduceMotion)
                    
                    if systemReduceMotion {
                        Label("System accessibility setting active", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Show loading indicators", isOn: $showLoadingIndicators)
                    .toggleStyle(.switch)
                    .tint(.green)
                    .help("Display progress indicators during operations")

                Toggle("Show empty state illustrations", isOn: $showEmptyStateIllustrations)
                    .toggleStyle(.switch)
                    .tint(.green)
                    .help("Display helpful illustrations when lists are empty")
                
                if systemReduceTransparency || systemIncreaseContrast {
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Additional macOS Accessibility Settings Active:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        if systemReduceTransparency {
                            Label("Reduce transparency", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if systemIncreaseContrast {
                            Label("Increase contrast", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Section("Advanced") {
                Toggle("Enable verbose logging", isOn: $verboseLogging)
                    .toggleStyle(.switch)
                    .tint(.green)
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
        .alert("Preferences Synced", isPresented: $showingSyncConfirmation) {
            Button("OK") { }
        } message: {
            Text("App visual preferences have been aligned with macOS accessibility settings.")
        }
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
                let path = url.path
                
                // Validate the tool
                validateContainerTool(at: path) { isValid, error in
                    if isValid {
                        containerToolPath = path
                        toolPathError = nil
                    } else {
                        toolPathError = error ?? "Invalid container tool"
                    }
                }
            }
        }
    }
    
    private func validateContainerTool(at path: String, completion: @escaping (Bool, String?) -> Void) {
        // Check if file exists and is executable
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            completion(false, "File does not exist")
            return
        }
        
        guard fileManager.isExecutableFile(atPath: path) else {
            completion(false, "File is not executable")
            return
        }
        
        // Try to run the tool with --version to verify it works
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                completion(true, nil)
            } else {
                completion(false, "Tool returned error code \(process.terminationStatus)")
            }
        } catch {
            completion(false, "Failed to execute tool: \(error.localizedDescription)")
        }
    }
    
    private func resetSettings() {
        autoStartService = false
        refreshInterval = 10.0
        showNotifications = true
        containerToolPath = ""
        defaultViewMode = "list"
        showInspectorPanel = true
        enableAnimations = true
        reduceMotion = false
        showLoadingIndicators = true
        compactMode = false
        showEmptyStateIllustrations = true
        verboseLogging = false
    }
    
    private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    private func openAccessibilitySettings() {
        // Open System Settings to Accessibility > Display
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func syncWithSystemSettings() {
        // Sync app preferences to match macOS accessibility settings
        var changesMade = false
        
        // Sync reduce motion
        if systemReduceMotion && !reduceMotion {
            reduceMotion = true
            changesMade = true
        }
        
        // If no system accessibility settings are active, we don't need to change anything
        // The app settings are already independent
        
        // Show confirmation
        if changesMade || systemReduceTransparency || systemIncreaseContrast {
            showingSyncConfirmation = true
        } else {
            // Nothing to sync - already aligned
            NSSound.beep()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .frame(width: 700, height: 600)
}
