//
//  ContainerSystemMonitor.swift
//  container-manager
//
//  Created by Andrew Bold on 30/12/2025.
//

import SwiftUI
import Combine
import Foundation

// MARK: - Time Range

enum TimeRange: String, CaseIterable {
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case sixHours = "6h"
    
    var seconds: TimeInterval {
        switch self {
        case .fiveMinutes: return 5 * 60
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .sixHours: return 6 * 60 * 60
        }
    }
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Container Stats Snapshot

struct ContainerStatsSnapshot: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let containerName: String
    let cpuPercent: Double
    let memoryUsageBytes: UInt64
    let memoryLimitBytes: UInt64
    let networkRxBytes: UInt64
    let networkTxBytes: UInt64
    let blockReadBytes: UInt64
    let blockWriteBytes: UInt64
    
    // MARK: - Computed Properties
    
    var memoryUsageMB: Double {
        return Double(memoryUsageBytes) / (1024 * 1024)
    }
    
    var memoryLimitMB: Double {
        return Double(memoryLimitBytes) / (1024 * 1024)
    }
    
    var memoryPercent: Double {
        guard memoryLimitBytes > 0 else { return 0 }
        return (Double(memoryUsageBytes) / Double(memoryLimitBytes)) * 100
    }
    
    var networkRxMB: Double {
        return Double(networkRxBytes) / (1024 * 1024)
    }
    
    var networkTxMB: Double {
        return Double(networkTxBytes) / (1024 * 1024)
    }
}

// MARK: - Container Stats History

struct ContainerStatsHistory {
    let containerName: String
    private(set) var snapshots: [ContainerStatsSnapshot]
    let maxDataPoints: Int
    
    init(containerName: String, maxDataPoints: Int = 2160) {
        self.containerName = containerName
        self.snapshots = []
        self.maxDataPoints = maxDataPoints
    }
    
    // MARK: - Mutating Methods
    
    mutating func add(_ snapshot: ContainerStatsSnapshot) {
        snapshots.append(snapshot)
        
        // Cleanup old data points
        if snapshots.count > maxDataPoints {
            let removeCount = snapshots.count - maxDataPoints
            snapshots.removeFirst(removeCount)
        }
    }
    
    mutating func clear() {
        snapshots.removeAll()
    }
    
    // MARK: - Query Methods
    
    func dataPoints(for timeRange: TimeRange) -> [ContainerStatsSnapshot] {
        let cutoffDate = Date().addingTimeInterval(-timeRange.seconds)
        return snapshots.filter { $0.timestamp >= cutoffDate }
    }
    
    func latestSnapshot() -> ContainerStatsSnapshot? {
        return snapshots.last
    }
    
    func averageCPU(for timeRange: TimeRange) -> Double {
        let points = dataPoints(for: timeRange)
        guard !points.isEmpty else { return 0 }
        let sum = points.reduce(0.0) { $0 + $1.cpuPercent }
        return sum / Double(points.count)
    }
    
    func averageMemory(for timeRange: TimeRange) -> Double {
        let points = dataPoints(for: timeRange)
        guard !points.isEmpty else { return 0 }
        let sum = points.reduce(0.0) { $0 + $1.memoryUsageMB }
        return sum / Double(points.count)
    }
    
    func peakMemory(for timeRange: TimeRange) -> Double {
        let points = dataPoints(for: timeRange)
        return points.map { $0.memoryUsageMB }.max() ?? 0
    }
    
    func networkThroughput(for timeRange: TimeRange) -> (rx: Double, tx: Double) {
        let points = dataPoints(for: timeRange)
        guard points.count >= 2 else { return (0, 0) }
        
        let first = points.first!
        let last = points.last!
        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        
        guard duration > 0 else { return (0, 0) }
        
        let rxDelta = Double(last.networkRxBytes - first.networkRxBytes)
        let txDelta = Double(last.networkTxBytes - first.networkTxBytes)
        
        // Bytes per second
        return (rxDelta / duration, txDelta / duration)
    }
}

// MARK: - System Stats Snapshot

struct SystemStatsSnapshot: Equatable {
    let timestamp: Date
    let totalContainers: Int
    let runningContainers: Int
    let averageCPU: Double
    let totalMemoryMB: Double
    let networkRxBytesPerSec: Double
    let networkTxBytesPerSec: Double
}

// MARK: - Stats Collector

class StatsCollector: ObservableObject {
    @Published private(set) var containerStats: [String: ContainerStatsHistory] = [:]
    @Published private(set) var systemStats: SystemStatsSnapshot?
    @Published private(set) var isCollecting = false
    
    private var collectionTask: Task<Void, Never>?
    private let collectionInterval: TimeInterval = 10.0 // 10 seconds
    private let maxDataPoints: Int = 2160 // 6 hours at 10-second intervals
    
    // Callback for collecting stats (will be set by ContainerSystemMonitor)
    var statsCollectionHandler: (() async -> [ContainerStatsSnapshot])?
    
    // MARK: - Collection Control
    
    @MainActor
    func startCollection() {
        guard !isCollecting else { return }
        isCollecting = true
        
        collectionTask = Task {
            while !Task.isCancelled {
                await collectStats()
                
                // Wait for next collection interval
                try? await Task.sleep(nanoseconds: UInt64(collectionInterval * 1_000_000_000))
            }
        }
    }
    
    @MainActor
    func stopCollection() {
        collectionTask?.cancel()
        collectionTask = nil
        isCollecting = false
    }
    
    @MainActor
    func clearHistory(for containerName: String? = nil) {
        if let containerName = containerName {
            containerStats[containerName]?.clear()
        } else {
            containerStats.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func collectStats() async {
        guard let handler = statsCollectionHandler else { return }
        
        let snapshots = await handler()
        
        await MainActor.run {
            // Update container stats
            for snapshot in snapshots {
                if containerStats[snapshot.containerName] == nil {
                    containerStats[snapshot.containerName] = ContainerStatsHistory(
                        containerName: snapshot.containerName,
                        maxDataPoints: maxDataPoints
                    )
                }
                containerStats[snapshot.containerName]?.add(snapshot)
            }
            
            // Clean up stats for containers that no longer exist
            let currentContainers = Set(snapshots.map { $0.containerName })
            let staleContainers = containerStats.keys.filter { !currentContainers.contains($0) }
            for container in staleContainers {
                containerStats.removeValue(forKey: container)
            }
            
            // Update system stats
            updateSystemStats(from: snapshots)
        }
    }
    
    private func updateSystemStats(from snapshots: [ContainerStatsSnapshot]) {
        guard !snapshots.isEmpty else {
            systemStats = nil
            return
        }
        
        let totalContainers = snapshots.count
        let runningContainers = snapshots.count // All snapshots are for running containers
        
        // Average CPU across all containers
        let averageCPU = snapshots.reduce(0.0) { $0 + $1.cpuPercent } / Double(snapshots.count)
        
        // Total memory across all containers
        let totalMemoryMB = snapshots.reduce(0.0) { $0 + $1.memoryUsageMB }
        
        // Calculate network throughput by comparing with previous system stats
        var networkRxBytesPerSec: Double = 0
        var networkTxBytesPerSec: Double = 0
        
        if let previousStats = systemStats {
            let duration = Date().timeIntervalSince(previousStats.timestamp)
            if duration > 0 {
                let currentRxTotal = snapshots.reduce(0.0) { $0 + Double($1.networkRxBytes) }
                let currentTxTotal = snapshots.reduce(0.0) { $0 + Double($1.networkTxBytes) }
                let previousRxTotal = Double(previousStats.networkRxBytesPerSec) * duration
                let previousTxTotal = Double(previousStats.networkTxBytesPerSec) * duration
                
                networkRxBytesPerSec = (currentRxTotal - previousRxTotal) / duration
                networkTxBytesPerSec = (currentTxTotal - previousTxTotal) / duration
            }
        }
        
        systemStats = SystemStatsSnapshot(
            timestamp: Date(),
            totalContainers: totalContainers,
            runningContainers: runningContainers,
            averageCPU: averageCPU,
            totalMemoryMB: totalMemoryMB,
            networkRxBytesPerSec: max(0, networkRxBytesPerSec),
            networkTxBytesPerSec: max(0, networkTxBytesPerSec)
        )
    }
}

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
    @Published var statsCollector: StatsCollector?
    
    private var timer: Timer?
    private var settingsObserver: AnyCancellable?
    var containerPath: String?
    
    // Track previous CPU measurements for percentage calculation (thread-safe)
    private let cpuMeasurementLock = NSLock()
    nonisolated(unsafe) private var previousCPUMeasurements: [String: (usec: UInt64, timestamp: Date)] = [:]
    
    private var refreshInterval: Double {
        UserDefaults.standard.double(forKey: "refreshInterval")
    }
    
    init() {
        // Set default refresh interval if not set
        if UserDefaults.standard.object(forKey: "refreshInterval") == nil {
            UserDefaults.standard.set(10.0, forKey: "refreshInterval")
        }
        
        // Initialize stats collector
        let collector = StatsCollector()
        collector.statsCollectionHandler = { [weak self] in
            await self?.collectContainerStats() ?? []
        }
        self.statsCollector = collector
        
        findContainerPath()
        startMonitoring()
        
        // Observe UserDefaults changes for refresh interval
        settingsObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.recreateTimer(interval: self?.refreshInterval ?? 10.0)
            }
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
        
        // Set up periodic monitoring using the refresh interval setting
        recreateTimer(interval: refreshInterval)
    }
    
    private func recreateTimer(interval: TimeInterval) {
        // Clamp interval to valid range (2-300 seconds)
        let validInterval = max(2.0, min(300.0, interval))
        
        // Invalidate existing timer
        timer?.invalidate()
        
        // Create new timer with updated interval
        timer = Timer.scheduledTimer(withTimeInterval: validInterval, repeats: true) { [weak self] _ in
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
    
    func checkAppleContainerStatus() async {
        guard let containerPath else {
            await MainActor.run {
                let wasRunning = status == .running
                status = .stopped
                containers = []
                lastUpdated = Date()
                
                // Stop stats collection if was running
                if wasRunning, let statsCollector = self.statsCollector {
                    statsCollector.stopCollection()
                }
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
                        // Capture previous container states
                        let previousContainers = self.containers
                        
                        self.parseContainerOutput(output)
                        let wasRunning = self.status == .running
                        self.status = .running
                        self.lastUpdated = Date()
                        
                        // Detect and notify container state changes
                        self.detectAndNotifyChanges(previous: previousContainers, current: self.containers)
                        
                        // Start stats collection if not already running
                        if !wasRunning, let statsCollector = self.statsCollector {
                            statsCollector.startCollection()
                        }
                    }
                }
            } else {
                // Container command failed
                await MainActor.run {
                    let wasRunning = status == .running
                    status = .stopped
                    containers = []
                    lastUpdated = Date()
                    
                    // Stop stats collection if was running
                    if wasRunning, let statsCollector = self.statsCollector {
                        statsCollector.stopCollection()
                    }
                }
            }
        } catch {
            await MainActor.run {
                let wasRunning = status == .running
                status = .error
                containers = []
                lastUpdated = Date()
                
                // Stop stats collection if was running
                if wasRunning, let statsCollector = self.statsCollector {
                    statsCollector.stopCollection()
                }
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
            
            // Send notification on success
            if command == "start" {
                NotificationManager.shared.serviceStarted()
            } else if command == "stop" {
                NotificationManager.shared.serviceStopped()
            }
        } catch {
            // Send error notification
            NotificationManager.shared.serviceError("Failed to \(command) service: \(error.localizedDescription)")
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
    
    // Detect container state changes and send notifications
    private func detectAndNotifyChanges(previous: [ContainerInfo], current: [ContainerInfo]) {
        // Build lookup dictionaries for quick access
        let prevDict = Dictionary(uniqueKeysWithValues: previous.map { ($0.name, $0.status) })
        let currDict = Dictionary(uniqueKeysWithValues: current.map { ($0.name, $0.status) })
        
        // Check for state changes in existing containers
        for (name, currentStatus) in currDict {
            if let previousStatus = prevDict[name] {
                // Container existed before - check if status changed
                if previousStatus != currentStatus {
                    let wasRunning = previousStatus.lowercased().contains("running") || previousStatus.lowercased().contains("up")
                    let isRunning = currentStatus.lowercased().contains("running") || currentStatus.lowercased().contains("up")
                    
                    if !wasRunning && isRunning {
                        NotificationManager.shared.containerStarted(name)
                    } else if wasRunning && !isRunning {
                        NotificationManager.shared.containerStopped(name)
                    }
                }
            } else {
                // New container appeared
                let isRunning = currentStatus.lowercased().contains("running") || currentStatus.lowercased().contains("up")
                if isRunning {
                    NotificationManager.shared.containerStarted(name)
                }
            }
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
    
    // MARK: - Container Inspection
    
    func inspectContainer(_ containerName: String) async -> ContainerDetails? {
        guard let containerPath = containerPath else { return nil }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: containerPath)
        process.arguments = ["inspect", containerName]
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        if let existingPath = environment["PATH"] {
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\(existingPath)"
        } else {
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        }
        process.environment = environment
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                return nil
            }
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            
            return parseInspectOutput(output, containerName: containerName)
        } catch {
            return nil
        }
    }
    
    private func parseInspectOutput(_ output: String, containerName: String) -> ContainerDetails? {
        // Simple parsing of key-value pairs from inspect output
        // This is a basic implementation that looks for common patterns
        var env: [String: String] = [:]
        var labels: [String: String] = [:]
        var command: String?
        var workingDir: String?
        
        let lines = output.components(separatedBy: .newlines)
        var inEnvSection = false
        var inLabelsSection = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect sections
            if trimmed.contains("Environment:") || trimmed.contains("Env:") {
                inEnvSection = true
                inLabelsSection = false
                continue
            } else if trimmed.contains("Labels:") {
                inLabelsSection = true
                inEnvSection = false
                continue
            } else if trimmed.contains("Cmd:") || trimmed.contains("Command:") {
                inEnvSection = false
                inLabelsSection = false
                // Try to extract command
                if let match = trimmed.split(separator: ":").dropFirst().first {
                    command = String(match).trimmingCharacters(in: .whitespaces)
                }
                continue
            } else if trimmed.contains("WorkingDir:") {
                inEnvSection = false
                inLabelsSection = false
                if let match = trimmed.split(separator: ":").dropFirst().first {
                    workingDir = String(match).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            
            // Parse environment variables
            if inEnvSection && trimmed.contains("=") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                    let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        env[key] = value
                    }
                }
            }
            
            // Parse labels
            if inLabelsSection && trimmed.contains("=") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).inverted)
                    let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        labels[key] = value
                    }
                }
            }
        }
        
        return ContainerDetails(
            name: containerName,
            environmentVariables: env,
            labels: labels,
            command: command,
            workingDir: workingDir
        )
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct ContainerInfo: Identifiable, Equatable, Hashable {
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
    
    // Custom hash function that matches the equality implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(status)
        hasher.combine(image)
        hasher.combine(ports)
        hasher.combine(created)
    }
}

// MARK: - Detailed Container Info

struct ContainerDetails {
    let name: String
    let environmentVariables: [String: String]
    let labels: [String: String]
    let command: String?
    let workingDir: String?
    
    init(name: String, environmentVariables: [String: String] = [:], labels: [String: String] = [:], command: String? = nil, workingDir: String? = nil) {
        self.name = name
        self.environmentVariables = environmentVariables
        self.labels = labels
        self.command = command
        self.workingDir = workingDir
    }
}
// MARK: - Stats Collection Extension

extension ContainerSystemMonitor {
    /// Collect stats for all running containers
    func collectContainerStats() async -> [ContainerStatsSnapshot] {
        // Get list of running containers
        let runningContainers = await MainActor.run {
            containers.filter { container in
                let status = container.status.lowercased()
                return status == "running" || status == "up" || status.contains("running")
            }
        }
        
        guard !runningContainers.isEmpty else {
            return []
        }
        
        var snapshots: [ContainerStatsSnapshot] = []
        
        // Collect stats for each running container
        for container in runningContainers {
            if let snapshot = await collectStats(for: container.name) {
                snapshots.append(snapshot)
            }
        }
        
        return snapshots
    }
    
    /// Collect stats for a specific container
    private func collectStats(for containerName: String) async -> ContainerStatsSnapshot? {
        let timestamp = Date()
        
        // Try to collect stats using various methods
        // Method 1: Try Apple container tool stats command
        if let stats = await collectStatsFromContainerTool(containerName: containerName, timestamp: timestamp) {
            return stats
        }
        
        // Method 2: Try docker/podman stats command if available
        if let stats = await collectStatsFromDockerCommand(containerName: containerName, timestamp: timestamp) {
            return stats
        }
        
        // Method 3: Try using container exec with ps command (fallback)
        if let stats = await collectStatsFromExec(containerName: containerName, timestamp: timestamp) {
            return stats
        }
        
        // If all methods fail, return nil
        return nil
    }
    
    /// Try to collect stats using Apple container tool stats command
    private func collectStatsFromContainerTool(containerName: String, timestamp: Date) async -> ContainerStatsSnapshot? {
        guard let containerPath = containerPath else { return nil }
        
        // Run process on background queue to avoid blocking
        return await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: containerPath)
                process.arguments = ["stats", "--no-stream", "--format", "json", containerName]
                
                // Set up environment with PATH
                var environment = ProcessInfo.processInfo.environment
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\(existingPath)"
                } else {
                    environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                }
                process.environment = environment
                
                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    guard process.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let result = await self.parseContainerToolStatsOutput(output, containerName: containerName, timestamp: timestamp)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Parse Apple container tool stats JSON output
    nonisolated private func parseContainerToolStatsOutput(_ output: String, containerName: String, timestamp: Date) -> ContainerStatsSnapshot? {
        guard let data = output.data(using: .utf8) else { return nil }
        
        do {
            // The container tool may return an array of stats or a single object
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                // Find the stats for our container
                for json in jsonArray {
                    // Check both "id" and "name" fields
                    let id = json["id"] as? String
                    let name = json["name"] as? String
                    if (id == containerName || id?.hasPrefix(containerName) == true) ||
                       (name == containerName || name?.hasPrefix(containerName) == true) {
                        return parseContainerStatsJSON(json, containerName: containerName, timestamp: timestamp)
                    }
                }
            } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return parseContainerStatsJSON(json, containerName: containerName, timestamp: timestamp)
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    /// Parse stats JSON object
    nonisolated private func parseContainerStatsJSON(_ json: [String: Any], containerName: String, timestamp: Date) -> ContainerStatsSnapshot? {
        // Extract CPU percentage
        // Apple container tool provides cpuUsageUsec (microseconds of CPU time used)
        let cpuPercent: Double
        if let cpuUsageUsec = json["cpuUsageUsec"] as? UInt64 {
            // Calculate CPU percentage based on time delta (thread-safe)
            cpuMeasurementLock.lock()
            defer { cpuMeasurementLock.unlock() }
            
            if let previous = previousCPUMeasurements[containerName] {
                let timeDelta = timestamp.timeIntervalSince(previous.timestamp)
                if timeDelta > 0 {
                    let cpuDelta = Double(cpuUsageUsec) - Double(previous.usec)
                    // Convert microseconds to seconds and calculate percentage
                    // CPU % = (cpu_delta_seconds / time_delta_seconds) * 100
                    cpuPercent = (cpuDelta / 1_000_000.0) / timeDelta * 100.0
                    // Store current measurement for next calculation
                    previousCPUMeasurements[containerName] = (cpuUsageUsec, timestamp)
                } else {
                    cpuPercent = 0
                }
            } else {
                // Store current measurement for next calculation
                previousCPUMeasurements[containerName] = (cpuUsageUsec, timestamp)
                cpuPercent = 0
            }
        } else if let cpuPerc = json["cpu_percent"] as? Double {
            cpuPercent = cpuPerc
        } else if let cpuPerc = json["CPUPerc"] as? String {
            cpuPercent = parseCPUPercent(cpuPerc)
        } else {
            cpuPercent = 0
        }
        
        // Extract memory usage
        var memoryUsageBytes: UInt64 = 0
        var memoryLimitBytes: UInt64 = 0
        
        if let memUsage = json["memoryUsageBytes"] as? UInt64 {
            memoryUsageBytes = memUsage
        } else if let memUsage = json["mem_usage"] as? UInt64 {
            memoryUsageBytes = memUsage
        }
        
        if let memLimit = json["memoryLimitBytes"] as? UInt64 {
            memoryLimitBytes = memLimit
        } else if let memLimit = json["mem_limit"] as? UInt64 {
            memoryLimitBytes = memLimit
        }
        
        // Fallback to string parsing if numeric values not found
        if memoryUsageBytes == 0 && memoryLimitBytes == 0 {
            if let memUsageStr = json["MemUsage"] as? String {
                let memValues = parseMemoryValue(memUsageStr)
                memoryUsageBytes = memValues.usage
                memoryLimitBytes = memValues.limit
            }
        }
        
        // Extract network I/O
        var networkRxBytes: UInt64 = 0
        var networkTxBytes: UInt64 = 0
        
        if let netRx = json["networkRxBytes"] as? UInt64 {
            networkRxBytes = netRx
        } else if let netRx = json["net_rx"] as? UInt64 {
            networkRxBytes = netRx
        }
        
        if let netTx = json["networkTxBytes"] as? UInt64 {
            networkTxBytes = netTx
        } else if let netTx = json["net_tx"] as? UInt64 {
            networkTxBytes = netTx
        }
        
        // Fallback to string parsing
        if networkRxBytes == 0 && networkTxBytes == 0 {
            if let netIO = json["NetIO"] as? String {
                let netValues = parseNetworkIO(netIO)
                networkRxBytes = netValues.rx
                networkTxBytes = netValues.tx
            }
        }
        
        // Extract block I/O
        var blockReadBytes: UInt64 = 0
        var blockWriteBytes: UInt64 = 0
        
        if let blockRead = json["blockReadBytes"] as? UInt64 {
            blockReadBytes = blockRead
        } else if let blockRead = json["block_read"] as? UInt64 {
            blockReadBytes = blockRead
        }
        
        if let blockWrite = json["blockWriteBytes"] as? UInt64 {
            blockWriteBytes = blockWrite
        } else if let blockWrite = json["block_write"] as? UInt64 {
            blockWriteBytes = blockWrite
        }
        
        // Fallback to string parsing
        if blockReadBytes == 0 && blockWriteBytes == 0 {
            if let blockIO = json["BlockIO"] as? String {
                let blockValues = parseBlockIO(blockIO)
                blockReadBytes = blockValues.read
                blockWriteBytes = blockValues.write
            }
        }
        
        return ContainerStatsSnapshot(
            timestamp: timestamp,
            containerName: containerName,
            cpuPercent: cpuPercent,
            memoryUsageBytes: memoryUsageBytes,
            memoryLimitBytes: memoryLimitBytes,
            networkRxBytes: networkRxBytes,
            networkTxBytes: networkTxBytes,
            blockReadBytes: blockReadBytes,
            blockWriteBytes: blockWriteBytes
        )
    }
    
    /// Try to collect stats using docker/podman stats command
    private func collectStatsFromDockerCommand(containerName: String, timestamp: Date) async -> ContainerStatsSnapshot? {
        // Try docker first
        if let dockerPath = findCommandPath("docker") {
            if let output = await executeStatsCommand(path: dockerPath, containerName: containerName) {
                return parseDockerStatsOutput(output, containerName: containerName, timestamp: timestamp)
            }
        }
        
        // Try podman
        if let podmanPath = findCommandPath("podman") {
            if let output = await executeStatsCommand(path: podmanPath, containerName: containerName) {
                return parseDockerStatsOutput(output, containerName: containerName, timestamp: timestamp)
            }
        }
        
        return nil
    }
    
    /// Execute stats command
    private func executeStatsCommand(path: String, containerName: String) async -> String? {
        return await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = ["stats", "--no-stream", "--format", "{{json .}}", containerName]
                
                // Set up environment with PATH
                var environment = ProcessInfo.processInfo.environment
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\(existingPath)"
                } else {
                    environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                }
                process.environment = environment
                
                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    guard process.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Parse docker/podman stats JSON output
    nonisolated private func parseDockerStatsOutput(_ output: String, containerName: String, timestamp: Date) -> ContainerStatsSnapshot? {
        guard let data = output.data(using: .utf8) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let cpuPercent = parseCPUPercent(json["CPUPerc"] as? String ?? "0%")
                let memoryUsageBytes = parseMemoryValue(json["MemUsage"] as? String ?? "0B / 0B").usage
                let memoryLimitBytes = parseMemoryValue(json["MemUsage"] as? String ?? "0B / 0B").limit
                let networkIO = parseNetworkIO(json["NetIO"] as? String ?? "0B / 0B")
                let blockIO = parseBlockIO(json["BlockIO"] as? String ?? "0B / 0B")
                
                return ContainerStatsSnapshot(
                    timestamp: timestamp,
                    containerName: containerName,
                    cpuPercent: cpuPercent,
                    memoryUsageBytes: memoryUsageBytes,
                    memoryLimitBytes: memoryLimitBytes,
                    networkRxBytes: networkIO.rx,
                    networkTxBytes: networkIO.tx,
                    blockReadBytes: blockIO.read,
                    blockWriteBytes: blockIO.write
                )
            }
        } catch {
            return nil
        }
        
        return nil
    }
    
    /// Collect stats using container exec (fallback method)
    private func collectStatsFromExec(containerName: String, timestamp: Date) async -> ContainerStatsSnapshot? {
        // Use ps command to get basic CPU and memory info
        guard let containerPath = containerPath else { return nil }
        
        return await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: containerPath)
                process.arguments = ["exec", containerName, "ps", "aux"]
                
                // Set up environment
                var environment = ProcessInfo.processInfo.environment
                if let existingPath = environment["PATH"] {
                    environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:\(existingPath)"
                } else {
                    environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                }
                process.environment = environment
                
                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = Pipe()
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    guard process.terminationStatus == 0 else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let result = self.parsePsOutput(output, containerName: containerName, timestamp: timestamp)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Parse ps aux output
    nonisolated private func parsePsOutput(_ output: String, containerName: String, timestamp: Date) -> ContainerStatsSnapshot? {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }
        
        // Skip header line
        let dataLines = lines.dropFirst()
        
        var totalCPU: Double = 0
        var totalMem: Double = 0
        
        for line in dataLines {
            let components = line.split(separator: " ", omittingEmptySubsequences: true).map { String($0) }
            guard components.count >= 11 else { continue }
            
            // ps aux format: USER PID %CPU %MEM VSZ RSS TTY STAT START TIME COMMAND
            if let cpu = Double(components[2]), let mem = Double(components[3]) {
                totalCPU += cpu
                totalMem += mem
            }
        }
        
        // Estimate memory in bytes (rough approximation)
        let estimatedMemoryMB = totalMem * 10 // Very rough estimate
        let memoryBytes = UInt64(estimatedMemoryMB * 1024 * 1024)
        
        return ContainerStatsSnapshot(
            timestamp: timestamp,
            containerName: containerName,
            cpuPercent: totalCPU,
            memoryUsageBytes: memoryBytes,
            memoryLimitBytes: memoryBytes * 2, // Estimate limit as 2x usage
            networkRxBytes: 0, // Not available from ps
            networkTxBytes: 0,
            blockReadBytes: 0,
            blockWriteBytes: 0
        )
    }
    
    // MARK: - Helper Methods
    
    nonisolated private func findCommandPath(_ command: String) -> String? {
        let paths = [
            "/opt/homebrew/bin/\(command)",
            "/usr/local/bin/\(command)",
            "/usr/bin/\(command)"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    nonisolated private func parseCPUPercent(_ value: String) -> Double {
        let cleanValue = value.replacingOccurrences(of: "%", with: "")
        return Double(cleanValue) ?? 0
    }
    
    nonisolated private func parseMemoryValue(_ value: String) -> (usage: UInt64, limit: UInt64) {
        // Format: "123.4MiB / 4GiB"
        let components = value.components(separatedBy: " / ")
        guard components.count == 2 else { return (0, 0) }
        
        let usage = parseBytes(components[0].trimmingCharacters(in: .whitespaces))
        let limit = parseBytes(components[1].trimmingCharacters(in: .whitespaces))
        
        return (usage, limit)
    }
    
    nonisolated private func parseNetworkIO(_ value: String) -> (rx: UInt64, tx: UInt64) {
        // Format: "1.2kB / 3.4kB"
        let components = value.components(separatedBy: " / ")
        guard components.count == 2 else { return (0, 0) }
        
        let rx = parseBytes(components[0].trimmingCharacters(in: .whitespaces))
        let tx = parseBytes(components[1].trimmingCharacters(in: .whitespaces))
        
        return (rx, tx)
    }
    
    nonisolated private func parseBlockIO(_ value: String) -> (read: UInt64, write: UInt64) {
        // Format: "1.2kB / 3.4kB"
        let components = value.components(separatedBy: " / ")
        guard components.count == 2 else { return (0, 0) }
        
        let read = parseBytes(components[0].trimmingCharacters(in: .whitespaces))
        let write = parseBytes(components[1].trimmingCharacters(in: .whitespaces))
        
        return (read, write)
    }
    
    nonisolated private func parseBytes(_ value: String) -> UInt64 {
        let cleanValue = value.trimmingCharacters(in: .whitespaces)
        let numberPart = cleanValue.prefix(while: { $0.isNumber || $0 == "." })
        let unitPart = cleanValue.suffix(from: numberPart.endIndex)
        
        guard let number = Double(numberPart) else { return 0 }
        
        let multiplier: Double
        switch unitPart.uppercased() {
        case "B": multiplier = 1
        case "KB", "KIB": multiplier = 1024
        case "MB", "MIB": multiplier = 1024 * 1024
        case "GB", "GIB": multiplier = 1024 * 1024 * 1024
        case "TB", "TIB": multiplier = 1024 * 1024 * 1024 * 1024
        default: multiplier = 1
        }
        
        return UInt64(number * multiplier)
    }
}

