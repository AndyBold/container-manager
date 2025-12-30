//
//  ContainerSystemMonitor.swift
//  container-manager
//
//  Created by Andrew Bold on 30/12/2025.
//

import SwiftUI
import Combine
import Foundation

enum ContainerSystemStatus {
    case running
    case stopped
    case error
    
    var color: Color {
        switch self {
        case .running:
            return .green
        case .stopped:
            return .primary
        case .error:
            return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .stopped:
            return "Stopped"
        case .error:
            return "Error"
        }
    }
}

class ContainerSystemMonitor: ObservableObject {
    @Published var status: ContainerSystemStatus = .stopped
    @Published var containers: [ContainerInfo] = []
    @Published var lastUpdated: Date = Date()
    @Published var isOperating: Bool = false // Track if start/stop operation is in progress
    
    private var timer: Timer?
    private var containerPath: String?
    
    init() {
        findContainerPath()
        startMonitoring()
    }
    
    private func findContainerPath() {
        let containerPaths = [
            "/usr/local/bin/container",
            "/opt/homebrew/bin/container",
            "/usr/bin/container",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin/container").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/container").path
        ]
        
        for path in containerPaths {
            if FileManager.default.fileExists(atPath: path) {
                containerPath = path
                break
            }
        }
    }
    
    func startMonitoring() {
        // Initial check
        checkContainerStatus()
        
        // Set up periodic monitoring (every 5 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkContainerStatus()
        }
    }
    
    func checkContainerStatus() {
        Task {
            await checkAppleContainerStatus()
        }
    }
    
    private func checkAppleContainerStatus() async {
        guard let containerPath else {
            await MainActor.run {
                status = .stopped
                containers = []
                lastUpdated = Date()
            }
            return
        }
        
        do {
            // Use shell to execute container command with proper environment
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", "\(containerPath) list"]
            
            // Set up environment with standard paths
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    await MainActor.run {
                        self.parseContainerOutput(output)
                        self.status = .running
                        self.lastUpdated = Date()
                    }
                }
            } else {
                // Container command failed
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                    print("Container command error: \(errorOutput)")
                }
                
                await MainActor.run {
                    status = .stopped
                    containers = []
                    lastUpdated = Date()
                }
            }
        } catch {
            print("Error running container command: \(error)")
            await MainActor.run {
                status = .error
                containers = []
                lastUpdated = Date()
            }
        }
    }
    
    func startContainerService() {
        Task {
            await performServiceOperation(command: "start")
        }
    }
    
    func stopContainerService() {
        Task {
            await performServiceOperation(command: "stop")
        }
    }
    
    private func performServiceOperation(command: String) async {
        guard let containerPath else {
            return
        }
        
        await MainActor.run {
            isOperating = true
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            // Use launchctl to manage the container service
            // The service name varies but typically includes com.apple.containermanagerd
            let launchctlCommand: String
            if command == "start" {
                // Try to bootstrap/start the service
                // For Apple's container tool, we need to use: container system start
                launchctlCommand = "\(containerPath) system \(command)"
            } else {
                // For stop
                launchctlCommand = "\(containerPath) system \(command)"
            }
            
            process.arguments = ["-c", launchctlCommand]
            
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            process.waitUntilExit()
            
            // Wait a moment for service to start/stop
            try await Task.sleep(for: .seconds(2))
            
            // Check status again
            await checkAppleContainerStatus()
        } catch {
            // Silently handle errors
        }
        
        await MainActor.run {
            isOperating = false
        }
    }
    
    @MainActor
    private func parseContainerOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        var newContainers: [ContainerInfo] = []
        
        // The Apple Container tool output format may vary
        // Try to parse JSON format first (if supported)
        if let jsonData = output.data(using: .utf8),
           let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
            // Parse JSON format
            for item in jsonArray {
                if let name = item["name"] as? String {
                    let state = item["state"] as? String ?? "unknown"
                    newContainers.append(ContainerInfo(name: name, status: state))
                }
            }
        } else {
            // Parse plain text format
            // Skip header lines and parse container entries
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("NAME") || trimmed.hasPrefix("---") {
                    continue
                }
                
                // Split by whitespace and extract relevant info
                let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if !components.isEmpty {
                    let name = components[0]
                    let status = components.count > 1 ? components[1] : "running"
                    newContainers.append(ContainerInfo(name: name, status: status))
                }
            }
        }
        
        containers = newContainers
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct ContainerInfo: Identifiable {
    let id = UUID()
    let name: String
    let status: String
}
