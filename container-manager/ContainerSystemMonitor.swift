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
        
        // Set up periodic monitoring (every 10 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Skip polling if user is performing an action
            if !self.isOperating {
                self.checkContainerStatus()
            }
        }
    }
    
    func checkContainerStatus() {
        // Don't check if we're currently performing an operation
        guard !isOperating else { return }
        
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
            process.arguments = ["-c", "\(containerPath) ls -a"]
            
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
                await MainActor.run {
                    status = .stopped
                    containers = []
                    lastUpdated = Date()
                }
            }
        } catch {
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
    
    // MARK: - Container Operations
    
    func stopContainer(named name: String) async -> Bool {
        return await performContainerOperation(command: "stop", containerName: name)
    }
    
    func startContainer(named name: String) async -> Bool {
        return await performContainerOperation(command: "start", containerName: name)
    }
    
    func restartContainer(named name: String) async -> Bool {
        return await performContainerOperation(command: "restart", containerName: name)
    }
    
    func removeContainer(named name: String) async -> Bool {
        // Try different remove commands depending on the container tool
        // Apple container tool uses "delete"
        var success = await performContainerOperation(command: "delete", containerName: name, additionalArgs: [])
        
        if !success {
            // Try "rm" without force flag (for stopped containers)
            success = await performContainerOperation(command: "rm", containerName: name, additionalArgs: [])
        }
        
        if !success {
            // Fall back to "rm -f" (force remove, for running containers)
            success = await performContainerOperation(command: "rm", containerName: name, additionalArgs: ["-f"])
        }
        
        return success
    }
    
    private func performContainerOperation(command: String, containerName: String, additionalArgs: [String] = []) async -> Bool {
        guard let containerPath else {
            return false
        }
        
        await MainActor.run {
            isOperating = true
        }
        
        var success = false
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            // Build command arguments
            var commandArgs = [containerPath, command]
            commandArgs.append(contentsOf: additionalArgs)
            commandArgs.append(containerName)
            
            let fullCommand = commandArgs.joined(separator: " ")
            process.arguments = ["-c", fullCommand]
            
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
            
            success = process.terminationStatus == 0
            
            // Wait a moment for the operation to complete
            try await Task.sleep(for: .seconds(1))
            
            // Refresh container list
            await checkAppleContainerStatus()
        } catch {
            success = false
        }
        
        await MainActor.run {
            isOperating = false
        }
        
        return success
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
                    let image = item["image"] as? String
                    let ports = item["ports"] as? String
                    let created = item["created"] as? String
                    newContainers.append(ContainerInfo(
                        name: name,
                        status: state,
                        image: image,
                        ports: ports,
                        created: created
                    ))
                }
            }
        } else {
            // Parse plain text format
            // First, find the header line to determine column indices
            var headerIndices: [String: Int] = [:]
            var dataLines: [String] = []
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                if trimmed.isEmpty {
                    continue
                }
                
                // Check if this is a header line
                if trimmed.uppercased().hasPrefix("ID") || 
                   trimmed.uppercased().hasPrefix("NAME") || 
                   trimmed.uppercased().hasPrefix("CONTAINER") {
                    // Parse header to find column positions
                    let headers = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    for (index, header) in headers.enumerated() {
                        headerIndices[header.uppercased()] = index
                    }
                    continue
                }
                
                // Skip separator lines
                if trimmed.hasPrefix("---") {
                    continue
                }
                
                // This is a data line
                dataLines.append(trimmed)
            }
            
            // If we found headers, use them to extract data
            if !headerIndices.isEmpty {
                for line in dataLines {
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    
                    if components.isEmpty {
                        continue
                    }
                    
                    // Extract fields based on header positions
                    let nameIndex = headerIndices["ID"] ?? headerIndices["NAME"] ?? headerIndices["CONTAINER"] ?? 0
                    let imageIndex = headerIndices["IMAGE"] ?? 1
                    let stateIndex = headerIndices["STATE"] ?? headerIndices["STATUS"] ?? 4
                    let addrIndex = headerIndices["ADDR"] ?? headerIndices["ADDRESS"] ?? nil
                    
                    let name = components.count > nameIndex ? components[nameIndex] : ""
                    let status = components.count > stateIndex ? components[stateIndex] : "unknown"
                    let image = components.count > imageIndex ? components[imageIndex] : nil
                    let address = addrIndex.flatMap { components.count > $0 ? components[$0] : nil }
                    
                    if !name.isEmpty {
                        newContainers.append(ContainerInfo(
                            name: name,
                            status: status,
                            image: image,
                            ports: address, // Use address as ports for now
                            created: nil
                        ))
                    }
                }
            } else {
                // Fallback: assume default format if no headers found
                for line in dataLines {
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    
                    if !components.isEmpty {
                        let name = components[0]
                        let status = components.count > 4 ? components[4] : "unknown"
                        let image = components.count > 1 ? components[1] : nil
                        
                        newContainers.append(ContainerInfo(
                            name: name,
                            status: status,
                            image: image
                        ))
                    }
                }
            }
        }
        
        // Only update if the container list actually changed
        // This prevents unnecessary UI redraws that could close dialogs
        if !containersAreEqual(containers, newContainers) {
            containers = newContainers
        }
    }
    
    // Helper function to compare container lists
    private func containersAreEqual(_ lhs: [ContainerInfo], _ rhs: [ContainerInfo]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        
        // Compare containers by name (order independent)
        let lhsDict = Dictionary(uniqueKeysWithValues: lhs.map { ($0.name, $0) })
        let rhsDict = Dictionary(uniqueKeysWithValues: rhs.map { ($0.name, $0) })
        
        guard lhsDict.keys == rhsDict.keys else { return false }
        
        for key in lhsDict.keys {
            if lhsDict[key] != rhsDict[key] {
                return false
            }
        }
        
        return true
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct ContainerInfo: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let status: String
    let image: String?
    let ports: String?
    let created: String?
    
    init(name: String, status: String, image: String? = nil, ports: String? = nil, created: String? = nil) {
        self.name = name
        self.status = status
        self.image = image
        self.ports = ports
        self.created = created
    }
    
    // Custom equality that ignores the UUID
    static func == (lhs: ContainerInfo, rhs: ContainerInfo) -> Bool {
        return lhs.name == rhs.name &&
               lhs.status == rhs.status &&
               lhs.image == rhs.image &&
               lhs.ports == rhs.ports &&
               lhs.created == rhs.created
    }
}
