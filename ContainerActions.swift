//
//  ContainerActions.swift
//  container-manager
//
//  Reusable container action components
//

import SwiftUI

// MARK: - Container Actions Menu

struct ContainerActionsMenu: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let container: ContainerInfo
    
    @State private var isPerformingAction = false
    
    private var isRunning: Bool {
        let status = container.status.lowercased()
        return status == "running" || status == "up" || status.contains("running")
    }
    
    var body: some View {
        Menu {
            ContainerContextMenu(container: container)
                .environmentObject(containerMonitor)
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
        }
        .menuStyle(.borderlessButton)
        .disabled(containerMonitor.isOperating)
    }
}

// MARK: - Container Context Menu

struct ContainerContextMenu: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    @Environment(\.openWindow) private var openWindow
    let container: ContainerInfo
    
    @State private var showRemoveConfirmation = false
    
    private var isRunning: Bool {
        let status = container.status.lowercased()
        return status == "running" || status == "up" || status.contains("running")
    }
    
    var body: some View {
        Group {
            // Primary actions
            Button(action: { openLogs() }) {
                Label("View Logs", systemImage: "doc.text")
            }
            
            Button(action: { openInspector() }) {
                Label("Inspect", systemImage: "info.circle")
            }
            
            Button(action: { openTerminal() }) {
                Label("Open Terminal", systemImage: "terminal")
            }
            .disabled(!isRunning)
            
            Divider()
            
            // State management
            if isRunning {
                Button(action: { performAction { await containerMonitor.stopContainer(named: container.name) } }) {
                    Label("Stop", systemImage: "stop.fill")
                }
                
                Button(action: { performAction { await containerMonitor.restartContainer(named: container.name) } }) {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                
                Button(action: { pauseContainer() }) {
                    Label("Pause", systemImage: "pause.fill")
                }
            } else {
                Button(action: { performAction { await containerMonitor.startContainer(named: container.name) } }) {
                    Label("Start", systemImage: "play.fill")
                }
            }
            
            Divider()
            
            // Copy actions
            Menu("Copy") {
                Button("Copy Name") {
                    copyToClipboard(container.name)
                }
                
                if let image = container.image {
                    Button("Copy Image") {
                        copyToClipboard(image)
                    }
                }
                
                Button("Copy ID") {
                    copyToClipboard(container.name) // TODO: Use actual ID when available
                }
            }
            
            Divider()
            
            // Destructive actions
            Button(role: .destructive, action: { showRemoveConfirmation = true }) {
                Label("Remove Container", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Remove Container",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove \(container.name)", role: .destructive) {
                performAction {
                    await containerMonitor.removeContainer(named: container.name)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the container. This action cannot be undone.")
        }
    }
    
    // MARK: - Actions
    
    private func performAction(_ action: @escaping () async -> Bool) {
        Task {
            await containerMonitor.performContainerAction {
                let success = await action()
                if !success {
                    await MainActor.run {
                        NSSound.beep()
                    }
                }
            }
        }
    }
    
    private func openLogs() {
        // Open logs window using SwiftUI's openWindow
        openWindow(value: container.name)
    }
    
    private func openInspector() {
        // TODO: Open inspector window
        NotificationCenter.default.post(
            name: .openContainerInspector,
            object: nil,
            userInfo: ["containerName": container.name]
        )
    }
    
    private func openTerminal() {
        // Open terminal window
        // Since we can't use openWindow with id for now, use notification
        NotificationCenter.default.post(
            name: .openContainerTerminal,
            object: nil,
            userInfo: ["containerName": container.name]
        )
    }
    
    private func pauseContainer() {
        // TODO: Implement pause
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openContainerLogs = Notification.Name("openContainerLogs")
    static let openContainerInspector = Notification.Name("openContainerInspector")
    static let openContainerTerminal = Notification.Name("openContainerTerminal")
}

// MARK: - Extension for Container Monitor

extension ContainerSystemMonitor {
    /// Perform a container action with proper state management
    func performContainerAction(_ action: @escaping () async -> Void) async {
        await MainActor.run {
            isOperating = true
        }
        
        await action()
        
        // Wait a moment for the operation to complete
        try? await Task.sleep(for: .seconds(1))
        
        // Refresh status
        await checkAppleContainerStatus()
        
        await MainActor.run {
            isOperating = false
        }
    }
}
