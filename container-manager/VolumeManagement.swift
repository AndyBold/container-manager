//
//  VolumeManagement.swift
//  container-manager
//
//  Created by Claude on 2/6/26.
//

import Foundation

// MARK: - Volume Info Model

public struct VolumeInfo: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let driver: String
    public let mountpoint: String
    public let scope: String
    public let created: Date?
    public let size: String?
    public let labels: [String: String]?
    public let containerCount: Int
    
    public init(name: String, driver: String, mountpoint: String, scope: String, created: Date?, size: String?, labels: [String: String]?, containerCount: Int) {
        self.name = name
        self.driver = driver
        self.mountpoint = mountpoint
        self.scope = scope
        self.created = created
        self.size = size
        self.labels = labels
        self.containerCount = containerCount
    }
    
    // MARK: - Computed Properties
    
    var displayName: String {
        return name
    }
    
    var isInUse: Bool {
        return containerCount > 0
    }
    
    var isLocalDriver: Bool {
        return driver == "local"
    }
    
    // MARK: - Parsing Methods
    
    /// Parse volume list output from container CLI
    /// Expected format: "DRIVER    NAME" header followed by data rows
    static func parseList(_ output: String) -> [VolumeInfo] {
        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard lines.count > 1 else {
            return []
        }
        
        // Skip header line
        let dataLines = lines.dropFirst()
        
        return dataLines.compactMap { line in
            parseLine(line)
        }
    }
    
    /// Parse a single volume list line
    private static func parseLine(_ line: String) -> VolumeInfo? {
        // Split by whitespace, handling multiple spaces
        let components = line.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }
        
        guard components.count >= 2 else {
            return nil
        }
        
        let driver = components[0]
        let name = components[1]
        
        return VolumeInfo(
            name: name,
            driver: driver,
            mountpoint: "",
            scope: "local",
            created: nil,
            size: nil,
            labels: nil,
            containerCount: 0
        )
    }
    
    /// Parse volume inspect JSON output
    static func parseInspect(_ output: String) -> VolumeInfo? {
        guard let data = output.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let volumeDict = jsonArray.first {
                
                let name = volumeDict["Name"] as? String ?? ""
                let driver = volumeDict["Driver"] as? String ?? "local"
                let mountpoint = volumeDict["Mountpoint"] as? String ?? ""
                let scope = volumeDict["Scope"] as? String ?? "local"
                let labels = volumeDict["Labels"] as? [String: String]
                
                var created: Date?
                if let createdStr = volumeDict["CreatedAt"] as? String {
                    let formatter = ISO8601DateFormatter()
                    created = formatter.date(from: createdStr)
                }
                
                return VolumeInfo(
                    name: name,
                    driver: driver,
                    mountpoint: mountpoint,
                    scope: scope,
                    created: created,
                    size: nil,
                    labels: labels,
                    containerCount: 0
                )
            }
        } catch {
            print("Error parsing volume inspect JSON: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Filtering Methods
    
    /// Filter volumes by name (case-insensitive)
    static func filter(_ volumes: [VolumeInfo], name: String) -> [VolumeInfo] {
        guard !name.isEmpty else {
            return volumes
        }
        
        return volumes.filter { volume in
            volume.name.localizedCaseInsensitiveContains(name)
        }
    }
    
    /// Filter volumes by driver
    static func filterByDriver(_ volumes: [VolumeInfo], driver: String) -> [VolumeInfo] {
        return volumes.filter { $0.driver == driver }
    }
    
    /// Filter unused volumes (not attached to any container)
    static func filterUnused(_ volumes: [VolumeInfo]) -> [VolumeInfo] {
        return volumes.filter { !$0.isInUse }
    }
    
    // MARK: - Sorting Methods
    
    /// Sort volumes by name (ascending)
    static func sortByName(_ volumes: [VolumeInfo]) -> [VolumeInfo] {
        return volumes.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Sort volumes by creation date (newest first)
    static func sortByDate(_ volumes: [VolumeInfo]) -> [VolumeInfo] {
        return volumes.sorted { (lhs, rhs) in
            guard let lhsDate = lhs.created, let rhsDate = rhs.created else {
                return lhs.created != nil
            }
            return lhsDate > rhsDate
        }
    }
    
    // MARK: - Validation
    
    /// Validate volume name format (alphanumeric, hyphens, underscores)
    static func validateName(_ name: String) -> Bool {
        guard !name.isEmpty else {
            return false
        }
        
        let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        return name.unicodeScalars.allSatisfy { allowedCharacterSet.contains($0) }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: VolumeInfo, rhs: VolumeInfo) -> Bool {
        return lhs.name == rhs.name && lhs.driver == rhs.driver
    }
}

// MARK: - Volume Operation Result

public struct VolumeOperationResult {
    public let success: Bool
    public let error: String?
    public let volumeName: String?
    
    public init(success: Bool, error: String?, volumeName: String?) {
        self.success = success
        self.error = error
        self.volumeName = volumeName
    }
}

// MARK: - Volume Usage Info

public struct VolumeUsageInfo {
    public let volumeName: String
    public let containers: [String]  // Container names using this volume
    public let mountPaths: [String]  // Mount paths in containers
    public let size: Int?
    
    public init(volumeName: String, containers: [String], mountPaths: [String], size: Int?) {
        self.volumeName = volumeName
        self.containers = containers
        self.mountPaths = mountPaths
        self.size = size
    }
}

// MARK: - Volume Create Options

public struct VolumeCreateOptions {
    public let name: String
    public let driver: String
    public let options: [String: String]?
    public let labels: [String: String]?
    
    public init(name: String, driver: String, options: [String: String]?, labels: [String: String]?) {
        self.name = name
        self.driver = driver
        self.options = options
        self.labels = labels
    }
}

// MARK: - ContainerSystemMonitor Extension

extension ContainerSystemMonitor {
    
    /// Fetch list of volumes
    func fetchVolumes() async -> [VolumeInfo]? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) volume ls"
            process.arguments = ["-c", command]
            
            // Setup environment with PATH
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
                    return VolumeInfo.parseList(output)
                }
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8) {
                    print("Error fetching volumes: \(errorOutput)")
                }
            }
            
            return []
        } catch {
            print("Error fetching volumes: \(error)")
            return nil
        }
    }
    
    /// Inspect volume details
    func inspectVolume(_ volumeName: String) async -> VolumeInfo? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) volume inspect \(volumeName) --format json"
            process.arguments = ["-c", command]
            
            // Setup environment
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
                    return VolumeInfo.parseInspect(output)
                }
            }
            
            return nil
        } catch {
            print("Error inspecting volume: \(error)")
            return nil
        }
    }
    
    /// Create a new volume
    func createVolume(options: VolumeCreateOptions) async -> VolumeOperationResult? {
        guard let containerPath = containerPath else {
            return VolumeOperationResult(success: false, error: "Container path not found", volumeName: nil)
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            var command = "\(containerPath) volume create"
            
            // Add driver option
            command += " --driver \(options.driver)"
            
            // Add driver options
            if let opts = options.options {
                for (key, value) in opts {
                    command += " --opt \(key)=\(value)"
                }
            }
            
            // Add labels
            if let lbls = options.labels {
                for (key, value) in lbls {
                    command += " --label \(key)=\(value)"
                }
            }
            
            // Add volume name
            command += " \(options.name)"
            
            process.arguments = ["-c", command]
            
            // Setup environment
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
                return VolumeOperationResult(success: true, error: nil, volumeName: options.name)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return VolumeOperationResult(success: false, error: errorOutput, volumeName: options.name)
            }
        } catch {
            return VolumeOperationResult(success: false, error: error.localizedDescription, volumeName: options.name)
        }
    }
    
    /// Remove a volume
    func removeVolume(_ volumeName: String, force: Bool = false) async -> VolumeOperationResult? {
        guard let containerPath = containerPath else {
            return VolumeOperationResult(success: false, error: "Container path not found", volumeName: volumeName)
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            var command = "\(containerPath) volume rm"
            
            if force {
                command += " -f"
            }
            
            command += " \(volumeName)"
            
            process.arguments = ["-c", command]
            
            // Setup environment
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
                return VolumeOperationResult(success: true, error: nil, volumeName: volumeName)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return VolumeOperationResult(success: false, error: errorOutput, volumeName: volumeName)
            }
        } catch {
            return VolumeOperationResult(success: false, error: error.localizedDescription, volumeName: volumeName)
        }
    }
    
    /// Remove multiple volumes
    func removeVolumes(_ volumeNames: [String], force: Bool = false) async -> [VolumeOperationResult] {
        var results: [VolumeOperationResult] = []
        
        for volumeName in volumeNames {
            if let result = await removeVolume(volumeName, force: force) {
                results.append(result)
            } else {
                results.append(VolumeOperationResult(success: false, error: "Failed to remove", volumeName: volumeName))
            }
        }
        
        return results
    }
    
    /// Prune unused volumes
    func pruneVolumes() async -> VolumeOperationResult? {
        guard let containerPath = containerPath else {
            return VolumeOperationResult(success: false, error: "Container path not found", volumeName: nil)
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) volume prune -f"
            process.arguments = ["-c", command]
            
            // Setup environment
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
                return VolumeOperationResult(success: true, error: nil, volumeName: nil)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return VolumeOperationResult(success: false, error: errorOutput, volumeName: nil)
            }
        } catch {
            return VolumeOperationResult(success: false, error: error.localizedDescription, volumeName: nil)
        }
    }
    
    /// Get volume usage information (which containers are using it)
    func getVolumeUsage(_ volumeName: String) async -> VolumeUsageInfo? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) ps -a --filter volume=\(volumeName) --format '{{.Names}}'"
            process.arguments = ["-c", command]
            
            // Setup environment
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
                    let containers = output.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    
                    return VolumeUsageInfo(
                        volumeName: volumeName,
                        containers: containers,
                        mountPaths: [],
                        size: nil
                    )
                }
            }
            
            return VolumeUsageInfo(volumeName: volumeName, containers: [], mountPaths: [], size: nil)
        } catch {
            print("Error getting volume usage: \(error)")
            return nil
        }
    }
}
