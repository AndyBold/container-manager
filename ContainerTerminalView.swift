//
//  ContainerTerminalView.swift
//  container-manager
//
//  Interactive terminal for container exec sessions
//

import SwiftUI
import Foundation

// MARK: - Terminal Support Types
// These should ideally come from ContainerTerminal.swift - ensure that file is included in your target

struct ContainerTerminalView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let containerName: String
    
    @State private var session: InteractiveExecSession?
    @State private var output: String = ""
    @State private var commandInput: String = ""
    @State private var commandHistory = CommandHistory()
    @State private var isRunning = false
    @State private var selectedShell = "/bin/sh"
    @State private var availableShells: [String] = []
    @State private var isLoadingShells = false
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(alignment: .center) {
                Text("Terminal: \(containerName)")
                    .font(.headline)
                
                Spacer()
                
                // Shell selector
                if !availableShells.isEmpty {
                    Picker("Shell", selection: $selectedShell) {
                        ForEach(availableShells, id: \.self) { shell in
                            Text(shell).tag(shell)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                    .disabled(isRunning)
                }
                
                // Connect/Disconnect
                Button(action: toggleConnection) {
                    Label(isRunning ? "Disconnect" : "Connect", 
                          systemImage: isRunning ? "xmark.circle.fill" : "play.circle.fill")
                }
                .disabled(isLoadingShells)
                
                // Clear
                Button(action: clearOutput) {
                    Label("Clear", systemImage: "trash")
                }
                
                // Copy all
                Button(action: copyAll) {
                    Label("Copy All", systemImage: "doc.on.doc")
                }
                .disabled(output.isEmpty)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(output.isEmpty ? "Terminal ready. Connect to start." : output)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("bottom")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: output) { oldValue, newValue in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Command input
            HStack(spacing: 8) {
                Text(isRunning ? "❯" : "◯")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isRunning ? .green : .secondary)
                
                TextField("Enter command...", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isInputFocused)
                    .disabled(!isRunning)
                    .onSubmit {
                        sendCommand()
                    }
                
                Button(action: sendCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .disabled(!isRunning || commandInput.isEmpty)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onAppear {
            loadShells()
            isInputFocused = true
        }
        .onDisappear {
            disconnect()
        }
        .onKeyPress(.upArrow) {
            navigateHistory(direction: .up)
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateHistory(direction: .down)
            return .handled
        }
    }
    
    // MARK: - Actions
    
    private func loadShells() {
        isLoadingShells = true
        
        Task {
            let shells = await containerMonitor.detectAvailableShells(containerName: containerName)
            
            await MainActor.run {
                if let shells = shells, !shells.isEmpty {
                    availableShells = shells
                    selectedShell = shells.first ?? "/bin/sh"
                } else {
                    availableShells = ["/bin/sh"]
                    selectedShell = "/bin/sh"
                }
                isLoadingShells = false
            }
        }
    }
    
    private func toggleConnection() {
        if isRunning {
            disconnect()
        } else {
            connect()
        }
    }
    
    private func connect() {
        Task {
            let newSession = await containerMonitor.startInteractiveExec(
                containerName: containerName,
                shell: selectedShell
            )
            
            await MainActor.run {
                session = newSession
                
                if newSession != nil {
                    isRunning = true
                    output += "Connected to \(containerName) (\(selectedShell))\n\n"
                    
                    // Start monitoring output
                    startOutputMonitoring()
                } else {
                    output += "Error: Failed to connect to container\n"
                }
            }
        }
    }
    
    private func disconnect() {
        Task {
            await session?.terminate()
            
            await MainActor.run {
                isRunning = false
                session = nil
                output += "\n\nDisconnected from \(containerName)\n"
            }
        }
    }
    
    private func sendCommand() {
        guard !commandInput.isEmpty, let session = session else { return }
        
        let command = commandInput
        commandHistory.add(command)
        
        // Display command in output
        output += "❯ \(command)\n"
        
        Task {
            let success = await session.sendInput(command + "\n")
            
            if !success {
                await MainActor.run {
                    output += "Error: Failed to send command\n"
                }
            }
        }
        
        commandInput = ""
        commandHistory.resetNavigation()
    }
    
    private func startOutputMonitoring() {
        Task {
            while isRunning, let session = session {
                let sessionRunning = await session.isRunning
                
                if !sessionRunning {
                    await MainActor.run {
                        isRunning = false
                        output += "\n\nSession terminated\n"
                    }
                    break
                }
                
                // Get recent output
                if let newOutput = await session.getRecentOutput() {
                    await MainActor.run {
                        output += newOutput
                    }
                }
                
                // Wait a bit before checking again
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
    
    private func navigateHistory(direction: HistoryDirection) {
        switch direction {
        case .up:
            if let command = commandHistory.previous() {
                commandInput = command
            }
        case .down:
            if let command = commandHistory.next() {
                commandInput = command
            } else {
                commandInput = ""
            }
        }
    }
    
    private func clearOutput() {
        output = ""
        
        Task {
            await session?.clearOutput()
        }
    }
    
    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }
    
    // MARK: - Types
    
    enum HistoryDirection {
        case up, down
    }
}

// MARK: - Preview

#Preview("Terminal View") {
    ContainerTerminalView(containerName: "nginx")
        .environmentObject(ContainerSystemMonitor())
        .frame(width: 800, height: 600)
}
