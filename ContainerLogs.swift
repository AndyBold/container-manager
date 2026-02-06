//
//  ContainerLogs.swift
//  container-manager
//
//  Container log management and parsing
//

import Foundation

// MARK: - Log Entry Model

struct LogEntry: Equatable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let stream: LogStream
    let message: String
    
    enum LogStream: String, Codable {
        case stdout
        case stderr
    }
    
    init(timestamp: Date, stream: LogStream, message: String) {
        self.timestamp = timestamp
        self.stream = stream
        self.message = message
    }
    
    // MARK: - Parsing
    
    static func parse(_ line: String) -> LogEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        
        let components = trimmed.components(separatedBy: .whitespaces)
        
        if components.count >= 2 {
            // Try to parse timestamp (ISO8601 format)
            let timestampString = components[0]
            let timestamp = parseISO8601(timestampString) ?? Date()
            
            // Determine stream
            var stream: LogStream = .stdout
            var messageStart = 1
            
            if components.count > 2 {
                let potentialStream = components[1].lowercased().replacingOccurrences(of: ":", with: "")
                if potentialStream == "stdout" {
                    stream = .stdout
                    messageStart = 2
                } else if potentialStream == "stderr" {
                    stream = .stderr
                    messageStart = 2
                }
            }
            
            // Extract message
            let message = components[messageStart...].joined(separator: " ")
            
            return LogEntry(timestamp: timestamp, stream: stream, message: message)
        }
        
        // Fallback for malformed lines - still create entry
        return LogEntry(timestamp: Date(), stream: .stdout, message: trimmed)
    }
    
    static func parseMultiple(_ text: String) -> [LogEntry] {
        return text.components(separatedBy: .newlines)
            .compactMap { parse($0) }
    }
    
    // MARK: - Filtering
    
    static func filter(_ logs: [LogEntry], searchTerm: String) -> [LogEntry] {
        guard !searchTerm.isEmpty else { return logs }
        return logs.filter { $0.message.localizedCaseInsensitiveContains(searchTerm) }
    }
    
    static func filter(_ logs: [LogEntry], stream: LogStream) -> [LogEntry] {
        return logs.filter { $0.stream == stream }
    }
    
    static func filter(_ logs: [LogEntry], since: Date) -> [LogEntry] {
        return logs.filter { $0.timestamp >= since }
    }
    
    // MARK: - Export
    
    static func export(_ logs: [LogEntry]) -> String {
        return logs.map { entry in
            "\(formatTimestamp(entry.timestamp)) [\(entry.stream.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
    
    static func exportToFile(_ logs: [LogEntry], url: URL) async -> Bool {
        let content = export(logs)
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error exporting logs: \(error)")
            return false
        }
    }
    
    // MARK: - Formatting
    
    static func formatTimestamp(_ date: Date, format: String = "yyyy-MM-dd HH:mm:ss") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
    
    static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: string) {
            return date
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        let timestampsMatch = lhs.timestamp == rhs.timestamp
        let streamsMatch = lhs.stream == rhs.stream
        let messagesMatch = lhs.message == rhs.message
        return timestampsMatch && streamsMatch && messagesMatch
    }
}

// MARK: - Log Buffer

struct LogBuffer {
    private(set) var entries: [LogEntry] = []
    let maxSize: Int
    
    var count: Int {
        entries.count
    }
    
    init(maxSize: Int = 10000) {
        self.maxSize = maxSize
    }
    
    mutating func append(_ entry: LogEntry) {
        entries.append(entry)
        
        // Maintain max size by removing oldest entries
        if entries.count > maxSize {
            let overflow = entries.count - maxSize
            entries.removeFirst(overflow)
        }
    }
    
    mutating func append(contentsOf newEntries: [LogEntry]) {
        entries.append(contentsOf: newEntries)
        
        if entries.count > maxSize {
            let overflow = entries.count - maxSize
            entries.removeFirst(overflow)
        }
    }
    
    mutating func clear() {
        entries.removeAll()
    }
}

// MARK: - Container System Monitor Extension

extension ContainerSystemMonitor {
    
    /// Fetch logs from a container
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - tail: Number of lines to fetch from the end (default: 100)
    ///   - since: Fetch logs since this timestamp
    /// - Returns: Array of log entries, or nil if error
    func fetchLogs(containerName: String, tail: Int = 100, since: Date? = nil) async -> [LogEntry]? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            // Build command
            var command = "\(containerPath) logs \(containerName)"
            
            if tail > 0 {
                command += " --tail \(tail)"
            }
            
            if let since = since {
                let formatter = ISO8601DateFormatter()
                let sinceString = formatter.string(from: since)
                command += " --since \(sinceString)"
            }
            
            process.arguments = ["-c", command]
            
            // Set up environment
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
                    return LogEntry.parseMultiple(output)
                }
            }
            
            return nil
        } catch {
            print("Error fetching logs: \(error)")
            return nil
        }
    }
    
    /// Stream logs from a container in real-time
    /// - Parameter containerName: Name of the container
    /// - Returns: AsyncStream of log entries
    func streamLogs(containerName: String) async -> AsyncStream<LogEntry>? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        return AsyncStream { continuation in
            Task {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    
                    let command = "\(containerPath) logs \(containerName) --follow"
                    process.arguments = ["-c", command]
                    
                    // Set up environment
                    var environment = ProcessInfo.processInfo.environment
                    if let existingPath = environment["PATH"] {
                        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
                    } else {
                        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                    }
                    process.environment = environment
                    
                    let outputPipe = Pipe()
                    process.standardOutput = outputPipe
                    
                    // Read output asynchronously
                    outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
                        let data = fileHandle.availableData
                        
                        if data.isEmpty {
                            continuation.finish()
                            return
                        }
                        
                        if let output = String(data: data, encoding: .utf8) {
                            Task { @MainActor in
                                let entries = LogEntry.parseMultiple(output)
                                for entry in entries {
                                    continuation.yield(entry)
                                }
                            }
                        }
                    }
                    
                    try process.run()
                    
                    // Handle termination
                    process.terminationHandler = { _ in
                        continuation.finish()
                    }
                    
                } catch {
                    print("Error streaming logs: \(error)")
                    continuation.finish()
                }
            }
        }
    }
}
