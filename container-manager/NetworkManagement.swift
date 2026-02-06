//
//  NetworkManagement.swift
//  container-manager
//
//  Created by Claude on 2/6/26.
//

import Foundation

// MARK: - Network Info Model

public struct NetworkInfo: Identifiable, Equatable {
    public let id = UUID()
    public let name: String
    public let networkID: String
    public let driver: String
    public let scope: String
    public let subnet: String?
    public let gateway: String?
    public let ipRange: String?
    public let created: Date?
    public let `internal`: Bool
    public let enableIPv6: Bool
    public let labels: [String: String]?
    public let containerCount: Int
    
    public init(name: String, networkID: String, driver: String, scope: String, subnet: String?, gateway: String?, ipRange: String?, created: Date?, internal: Bool, enableIPv6: Bool, labels: [String: String]?, containerCount: Int) {
        self.name = name
        self.networkID = networkID
        self.driver = driver
        self.scope = scope
        self.subnet = subnet
        self.gateway = gateway
        self.ipRange = ipRange
        self.created = created
        self.internal = `internal`
        self.enableIPv6 = enableIPv6
        self.labels = labels
        self.containerCount = containerCount
    }
    
    // MARK: - Computed Properties
    
    public var displayName: String {
        return name
    }
    
    public var isUserDefined: Bool {
        return !isDefaultNetwork
    }
    
    public var isDefaultNetwork: Bool {
        return ["bridge", "host", "none"].contains(name)
    }
    
    public var shortID: String {
        return String(networkID.prefix(12))
    }
    
    // MARK: - Parsing Methods
    
    /// Parse network list output from container CLI
    /// Expected format: "NETWORK ID    NAME       DRIVER    SCOPE" header followed by data rows
    public static func parseList(_ output: String) -> [NetworkInfo] {
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
    
    /// Parse a single network list line
    private static func parseLine(_ line: String) -> NetworkInfo? {
        // Split by whitespace, handling multiple spaces
        let components = line.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }
        
        guard components.count >= 4 else {
            return nil
        }
        
        let networkID = components[0]
        let name = components[1]
        let driver = components[2]
        let scope = components[3]
        
        return NetworkInfo(
            name: name,
            networkID: networkID,
            driver: driver,
            scope: scope,
            subnet: nil,
            gateway: nil,
            ipRange: nil,
            created: nil,
            internal: false,
            enableIPv6: false,
            labels: nil,
            containerCount: 0
        )
    }
    
    /// Parse network inspect JSON output
    public static func parseInspect(_ output: String) -> NetworkInfo? {
        guard let data = output.data(using: .utf8) else {
            return nil
        }
        
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let networkDict = jsonArray.first {
                
                let name = networkDict["Name"] as? String ?? ""
                let networkID = networkDict["Id"] as? String ?? ""
                let driver = networkDict["Driver"] as? String ?? "bridge"
                let scope = networkDict["Scope"] as? String ?? "local"
                let `internal` = networkDict["Internal"] as? Bool ?? false
                let enableIPv6 = networkDict["EnableIPv6"] as? Bool ?? false
                let labels = networkDict["Labels"] as? [String: String]
                
                var subnet: String?
                var gateway: String?
                var ipRange: String?
                
                if let ipam = networkDict["IPAM"] as? [String: Any],
                   let config = ipam["Config"] as? [[String: Any]],
                   let firstConfig = config.first {
                    subnet = firstConfig["Subnet"] as? String
                    gateway = firstConfig["Gateway"] as? String
                    ipRange = firstConfig["IPRange"] as? String
                }
                
                var created: Date?
                if let createdStr = networkDict["Created"] as? String {
                    let formatter = ISO8601DateFormatter()
                    created = formatter.date(from: createdStr)
                }
                
                return NetworkInfo(
                    name: name,
                    networkID: networkID,
                    driver: driver,
                    scope: scope,
                    subnet: subnet,
                    gateway: gateway,
                    ipRange: ipRange,
                    created: created,
                    internal: `internal`,
                    enableIPv6: enableIPv6,
                    labels: labels,
                    containerCount: 0
                )
            }
        } catch {
            print("Error parsing network inspect JSON: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Filtering Methods
    
    /// Filter networks by name (case-insensitive)
    public static func filter(_ networks: [NetworkInfo], name: String) -> [NetworkInfo] {
        guard !name.isEmpty else {
            return networks
        }
        
        return networks.filter { network in
            network.name.localizedCaseInsensitiveContains(name)
        }
    }
    
    /// Filter networks by driver
    public static func filterByDriver(_ networks: [NetworkInfo], driver: String) -> [NetworkInfo] {
        return networks.filter { $0.driver == driver }
    }
    
    /// Filter user-defined networks (exclude default networks)
    public static func filterUserDefined(_ networks: [NetworkInfo]) -> [NetworkInfo] {
        return networks.filter { $0.isUserDefined }
    }
    
    /// Filter networks by scope
    public static func filterByScope(_ networks: [NetworkInfo], scope: String) -> [NetworkInfo] {
        return networks.filter { $0.scope == scope }
    }
    
    // MARK: - Sorting Methods
    
    /// Sort networks by name (ascending)
    public static func sortByName(_ networks: [NetworkInfo]) -> [NetworkInfo] {
        return networks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Sort networks by driver (ascending)
    public static func sortByDriver(_ networks: [NetworkInfo]) -> [NetworkInfo] {
        return networks.sorted { $0.driver < $1.driver }
    }
    
    /// Sort networks by creation date (newest first)
    public static func sortByDate(_ networks: [NetworkInfo]) -> [NetworkInfo] {
        return networks.sorted { (lhs, rhs) in
            guard let lhsDate = lhs.created, let rhsDate = rhs.created else {
                return lhs.created != nil
            }
            return lhsDate > rhsDate
        }
    }
    
    // MARK: - Validation
    
    /// Validate subnet format (CIDR notation)
    public static func validateSubnet(_ subnet: String) -> Bool {
        guard !subnet.isEmpty else {
            return false
        }
        
        // Basic CIDR validation: xxx.xxx.xxx.xxx/xx
        let parts = subnet.components(separatedBy: "/")
        guard parts.count == 2 else {
            return false
        }
        
        // Validate IP address part
        guard validateIPAddress(parts[0]) else {
            return false
        }
        
        // Validate prefix length
        guard let prefixLength = Int(parts[1]), prefixLength >= 0 && prefixLength <= 32 else {
            return false
        }
        
        return true
    }
    
    /// Validate IP address format
    public static func validateIPAddress(_ ipAddress: String) -> Bool {
        guard !ipAddress.isEmpty else {
            return false
        }
        
        let components = ipAddress.components(separatedBy: ".")
        guard components.count == 4 else {
            return false
        }
        
        for component in components {
            guard let value = Int(component), value >= 0 && value <= 255 else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: NetworkInfo, rhs: NetworkInfo) -> Bool {
        return lhs.networkID == rhs.networkID && lhs.name == rhs.name
    }
}

// MARK: - Network Operation Result

public struct NetworkOperationResult {
    public let success: Bool
    public let error: String?
    public let networkName: String?
    public let networkID: String?
    
    public init(success: Bool, error: String?, networkName: String?, networkID: String? = nil) {
        self.success = success
        self.error = error
        self.networkName = networkName
        self.networkID = networkID
    }
}

// MARK: - Network Connection Info

public struct NetworkConnectionInfo {
    public let networkName: String
    public let containers: [ContainerNetworkInfo]
    
    public init(networkName: String, containers: [ContainerNetworkInfo]) {
        self.networkName = networkName
        self.containers = containers
    }
}

public struct ContainerNetworkInfo {
    public let name: String
    public let ipAddress: String?
    public let macAddress: String?
    public let aliases: [String]?
    
    public init(name: String, ipAddress: String?, macAddress: String?, aliases: [String]?) {
        self.name = name
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.aliases = aliases
    }
}

// MARK: - Network Create Options

public struct NetworkCreateOptions {
    public let name: String
    public let driver: String
    public let subnet: String?
    public let gateway: String?
    public let ipRange: String?
    public let `internal`: Bool
    public let enableIPv6: Bool
    public let options: [String: String]?
    public let labels: [String: String]?
    
    public init(name: String, driver: String, subnet: String?, gateway: String?, ipRange: String?, internal: Bool, enableIPv6: Bool, options: [String: String]?, labels: [String: String]?) {
        self.name = name
        self.driver = driver
        self.subnet = subnet
        self.gateway = gateway
        self.ipRange = ipRange
        self.internal = `internal`
        self.enableIPv6 = enableIPv6
        self.options = options
        self.labels = labels
    }
}

// MARK: - ContainerSystemMonitor Extension

extension ContainerSystemMonitor {
    
    /// Fetch list of networks
    func fetchNetworks() async -> [NetworkInfo]? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) network ls"
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
                    return NetworkInfo.parseList(output)
                }
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8) {
                    print("Error fetching networks: \(errorOutput)")
                }
            }
            
            return []
        } catch {
            print("Error fetching networks: \(error)")
            return nil
        }
    }
    
    /// Inspect network details
    func inspectNetwork(_ networkName: String) async -> NetworkInfo? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) network inspect \(networkName) --format json"
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
                    return NetworkInfo.parseInspect(output)
                }
            }
            
            return nil
        } catch {
            print("Error inspecting network: \(error)")
            return nil
        }
    }
    
    /// Create a new network
    func createNetwork(options: NetworkCreateOptions) async -> NetworkOperationResult? {
        guard let containerPath = containerPath else {
            return NetworkOperationResult(success: false, error: "Container path not found", networkName: nil)
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            var command = "\(containerPath) network create"
            
            // Add driver option
            command += " --driver \(options.driver)"
            
            // Add subnet
            if let subnet = options.subnet {
                command += " --subnet \(subnet)"
            }
            
            // Add gateway
            if let gateway = options.gateway {
                command += " --gateway \(gateway)"
            }
            
            // Add IP range
            if let ipRange = options.ipRange {
                command += " --ip-range \(ipRange)"
            }
            
            // Add internal flag
            if options.internal {
                command += " --internal"
            }
            
            // Add IPv6 flag
            if options.enableIPv6 {
                command += " --ipv6"
            }
            
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
            
            // Add network name
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
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let networkID = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return NetworkOperationResult(success: true, error: nil, networkName: options.name, networkID: networkID)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return NetworkOperationResult(success: false, error: errorOutput, networkName: options.name)
            }
        } catch {
            return NetworkOperationResult(success: false, error: error.localizedDescription, networkName: options.name)
        }
    }
    
    /// Remove a network
    func removeNetwork(_ networkName: String) async -> NetworkOperationResult? {
        guard let containerPath = containerPath else {
            return NetworkOperationResult(success: false, error: "Container path not found", networkName: networkName)
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) network rm \(networkName)"
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
                return NetworkOperationResult(success: true, error: nil, networkName: networkName)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return NetworkOperationResult(success: false, error: errorOutput, networkName: networkName)
            }
        } catch {
            return NetworkOperationResult(success: false, error: error.localizedDescription, networkName: networkName)
        }
    }
    
    /// Remove multiple networks
    func removeNetworks(_ networkNames: [String]) async -> [NetworkOperationResult] {
        var results: [NetworkOperationResult] = []
        
        for networkName in networkNames {
            if let result = await removeNetwork(networkName) {
                results.append(result)
            } else {
                results.append(NetworkOperationResult(success: false, error: "Failed to remove", networkName: networkName))
            }
        }
        
        return results
    }
    
    /// Prune unused networks
    func pruneNetworks() async -> NetworkOperationResult? {
        guard let containerPath = containerPath else {
            return NetworkOperationResult(success: false, error: "Container path not found", networkName: nil)
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            let command = "\(containerPath) network prune -f"
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
                return NetworkOperationResult(success: true, error: nil, networkName: nil)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return NetworkOperationResult(success: false, error: errorOutput, networkName: nil)
            }
        } catch {
            return NetworkOperationResult(success: false, error: error.localizedDescription, networkName: nil)
        }
    }
    
    /// Get network connections (containers connected to network)
    func getNetworkConnections(_ networkName: String) async -> NetworkConnectionInfo? {
        guard let networkDetails = await inspectNetwork(networkName) else {
            return nil
        }
        
        // For now, return empty container list
        // Full implementation would parse the Containers field from inspect output
        return NetworkConnectionInfo(networkName: networkName, containers: [])
    }
    
    /// Connect container to network
    func connectContainerToNetwork(
        networkName: String,
        containerName: String,
        ipAddress: String? = nil,
        aliases: [String]? = nil
    ) async -> NetworkOperationResult? {
        guard let containerPath = containerPath else {
            return NetworkOperationResult(success: false, error: "Container path not found", networkName: networkName)
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            var command = "\(containerPath) network connect"
            
            // Add IP address
            if let ip = ipAddress {
                command += " --ip \(ip)"
            }
            
            // Add aliases
            if let aliases = aliases {
                for alias in aliases {
                    command += " --alias \(alias)"
                }
            }
            
            command += " \(networkName) \(containerName)"
            
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
                return NetworkOperationResult(success: true, error: nil, networkName: networkName)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return NetworkOperationResult(success: false, error: errorOutput, networkName: networkName)
            }
        } catch {
            return NetworkOperationResult(success: false, error: error.localizedDescription, networkName: networkName)
        }
    }
    
    /// Disconnect container from network
    func disconnectContainerFromNetwork(
        networkName: String,
        containerName: String,
        force: Bool = false
    ) async -> NetworkOperationResult? {
        guard let containerPath = containerPath else {
            return NetworkOperationResult(success: false, error: "Container path not found", networkName: networkName)
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            var command = "\(containerPath) network disconnect"
            
            if force {
                command += " -f"
            }
            
            command += " \(networkName) \(containerName)"
            
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
                return NetworkOperationResult(success: true, error: nil, networkName: networkName)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                return NetworkOperationResult(success: false, error: errorOutput, networkName: networkName)
            }
        } catch {
            return NetworkOperationResult(success: false, error: error.localizedDescription, networkName: networkName)
        }
    }
}
