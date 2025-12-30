//
//  ContainerSystemMonitor.swift
//  container-manager
//
//  Created by Andrew Bold on 30/12/2025.
//

import SwiftUI
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

@MainActor
class ContainerSystemMonitor: ObservableObject {
    @Published var status: ContainerSystemStatus = .stopped
    @Published var containers: [ContainerInfo] = []
    @Published var lastUpdated: Date = Date()
    
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        // Initial check
        checkContainerStatus()
        
        // Set up periodic monitoring (every 5 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkContainerStatus()
            }
        }
    }
    
    func checkContainerStatus() {
        Task {
            do {
                // Check if containermanagerd is running
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
                process.arguments = ["-x", "containermanagerd"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    // Process found - system is running
                    status = .running
                    // Fetch container list
                    await fetchContainerList()
                } else {
                    // Process not found - system is stopped
                    status = .stopped
                    containers = []
                }
                
                lastUpdated = Date()
            } catch {
                status = .error
                containers = []
                lastUpdated = Date()
            }
        }
    }
    
    func fetchContainerList() async {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/systemextensionsctl")
            process.arguments = ["list"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseContainerList(output)
            }
        } catch {
            // If we can't get the list, just keep existing containers
            print("Error fetching container list: \(error)")
        }
    }
    
    private func parseContainerList(_ output: String) {
        // Parse the output and update containers array
        // This is a placeholder - adjust based on actual output format
        let lines = output.components(separatedBy: .newlines)
        var newContainers: [ContainerInfo] = []
        
        for line in lines {
            if !line.isEmpty && !line.contains("---") && !line.contains("enabled") {
                // Basic parsing - adjust based on actual format
                newContainers.append(ContainerInfo(name: line.trimmingCharacters(in: .whitespaces)))
            }
        }
        
        if !newContainers.isEmpty {
            containers = newContainers
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct ContainerInfo: Identifiable {
    let id = UUID()
    let name: String
}
