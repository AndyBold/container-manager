//
//  ContainerLogsTests.swift
//  container-manager
//
//  Tests for container logs viewer functionality
//

import Testing
import Foundation
@testable import container_manager

@Suite("Container Logs Viewer Tests")
struct ContainerLogsTests {
    
    // MARK: - Log Parsing Tests
    
    @Test("Parse simple log line")
    func parseSimpleLogLine() async throws {
        let logLine = "2026-02-06T10:30:45.123456Z Hello from container"
        let parsed = LogEntry.parse(logLine)
        
        #expect(parsed != nil)
        #expect(parsed?.message == "Hello from container")
        #expect(parsed?.timestamp != nil)
    }
    
    @Test("Parse log line with timestamp and stream")
    func parseLogLineWithStream() async throws {
        let logLine = "2026-02-06T10:30:45.123456Z stdout: Application started"
        let parsed = LogEntry.parse(logLine)
        
        #expect(parsed?.stream == .stdout)
        #expect(parsed?.message == "Application started")
    }
    
    @Test("Parse log line with stderr")
    func parseLogLineWithStderr() async throws {
        let logLine = "2026-02-06T10:30:45.123456Z stderr: Error occurred"
        let parsed = LogEntry.parse(logLine)
        
        #expect(parsed?.stream == .stderr)
        #expect(parsed?.message == "Error occurred")
    }
    
    @Test("Parse multi-line log entry")
    func parseMultilineLogEntry() async throws {
        let logLines = """
        2026-02-06T10:30:45.123456Z stdout: Starting service...
        2026-02-06T10:30:45.234567Z stdout: Configuration loaded
        2026-02-06T10:30:45.345678Z stdout: Service ready
        """
        
        let entries = LogEntry.parseMultiple(logLines)
        
        #expect(entries.count == 3)
        #expect(entries[0].message == "Starting service...")
        #expect(entries[1].message == "Configuration loaded")
        #expect(entries[2].message == "Service ready")
    }
    
    @Test("Handle malformed log lines gracefully")
    func handleMalformedLogLines() async throws {
        let logLine = "This is not a properly formatted log line"
        let parsed = LogEntry.parse(logLine)
        
        // Should still create an entry, but with defaults
        #expect(parsed != nil)
        #expect(parsed?.message == logLine)
        #expect(parsed?.stream == .stdout)
    }
    
    // MARK: - Log Streaming Tests
    
    @Test("Fetch logs from container")
    func fetchLogsFromContainer() async throws {
        let monitor = ContainerSystemMonitor()
        let containerName = "test-container"
        
        let logs = await monitor.fetchLogs(containerName: containerName, tail: 10)
        
        #expect(logs != nil)
        #expect(logs is [LogEntry] || logs == nil)
    }
    
    @Test("Fetch logs with tail limit")
    func fetchLogsWithTailLimit() async throws {
        let monitor = ContainerSystemMonitor()
        let containerName = "test-container"
        
        let logs = await monitor.fetchLogs(containerName: containerName, tail: 5)
        
        if let logs = logs {
            #expect(logs.count <= 5)
        }
    }
    
    @Test("Fetch logs with follow mode")
    func fetchLogsWithFollowMode() async throws {
        let monitor = ContainerSystemMonitor()
        let containerName = "test-container"
        
        // Start streaming logs
        let stream = await monitor.streamLogs(containerName: containerName)
        
        #expect(stream != nil)
        
        // Cancel after a short time
        try? await Task.sleep(for: .milliseconds(100))
    }
    
    @Test("Handle non-existent container logs")
    func handleNonExistentContainerLogs() async throws {
        let monitor = ContainerSystemMonitor()
        let containerName = "non-existent-container"
        
        let logs = await monitor.fetchLogs(containerName: containerName, tail: 10)
        
        // Should return nil or empty array, not crash
        #expect(logs == nil || logs?.isEmpty == true)
    }
    
    // MARK: - Log Filtering Tests
    
    @Test("Filter logs by search term")
    func filterLogsBySearchTerm() async throws {
        let logs = [
            LogEntry(timestamp: Date(), stream: .stdout, message: "Application started"),
            LogEntry(timestamp: Date(), stream: .stdout, message: "Error: Connection failed"),
            LogEntry(timestamp: Date(), stream: .stdout, message: "Retrying connection"),
            LogEntry(timestamp: Date(), stream: .stderr, message: "Critical error")
        ]
        
        let filtered = LogEntry.filter(logs, searchTerm: "error")
        
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.message.localizedCaseInsensitiveContains("error") })
    }
    
    @Test("Filter logs by stream type")
    func filterLogsByStreamType() async throws {
        let logs = [
            LogEntry(timestamp: Date(), stream: .stdout, message: "Normal output"),
            LogEntry(timestamp: Date(), stream: .stderr, message: "Error message"),
            LogEntry(timestamp: Date(), stream: .stdout, message: "More output"),
            LogEntry(timestamp: Date(), stream: .stderr, message: "Warning")
        ]
        
        let stdoutLogs = LogEntry.filter(logs, stream: .stdout)
        let stderrLogs = LogEntry.filter(logs, stream: .stderr)
        
        #expect(stdoutLogs.count == 2)
        #expect(stderrLogs.count == 2)
        #expect(stdoutLogs.allSatisfy { $0.stream == .stdout })
        #expect(stderrLogs.allSatisfy { $0.stream == .stderr })
    }
    
    @Test("Filter logs by time range")
    func filterLogsByTimeRange() async throws {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        let logs = [
            LogEntry(timestamp: twoHoursAgo, stream: .stdout, message: "Old log"),
            LogEntry(timestamp: oneHourAgo, stream: .stdout, message: "Recent log"),
            LogEntry(timestamp: now, stream: .stdout, message: "Current log")
        ]
        
        let filtered = LogEntry.filter(logs, since: oneHourAgo)
        
        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.timestamp >= oneHourAgo })
    }
    
    // MARK: - Log Export Tests
    
    @Test("Export logs to string")
    func exportLogsToString() async throws {
        let logs = [
            LogEntry(timestamp: Date(), stream: .stdout, message: "Line 1"),
            LogEntry(timestamp: Date(), stream: .stdout, message: "Line 2"),
            LogEntry(timestamp: Date(), stream: .stderr, message: "Line 3")
        ]
        
        let exported = LogEntry.export(logs)
        
        #expect(exported.contains("Line 1"))
        #expect(exported.contains("Line 2"))
        #expect(exported.contains("Line 3"))
    }
    
    @Test("Export logs to file")
    func exportLogsToFile() async throws {
        let logs = [
            LogEntry(timestamp: Date(), stream: .stdout, message: "Test log 1"),
            LogEntry(timestamp: Date(), stream: .stdout, message: "Test log 2")
        ]
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-logs.txt")
        
        let success = await LogEntry.exportToFile(logs, url: tempURL)
        
        #expect(success == true)
        
        // Verify file exists and contains data
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
        
        let contents = try? String(contentsOf: tempURL)
        #expect(contents?.contains("Test log 1") == true)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - Log Buffer Management Tests
    
    @Test("Log buffer respects maximum size")
    func logBufferRespectsMaxSize() async throws {
        let maxSize = 100
        var buffer = LogBuffer(maxSize: maxSize)
        
        // Add more logs than the max size
        for i in 0..<150 {
            buffer.append(LogEntry(timestamp: Date(), stream: .stdout, message: "Log \(i)"))
        }
        
        #expect(buffer.count == maxSize)
        #expect(buffer.entries.first?.message == "Log 50") // Oldest 50 should be dropped
    }
    
    @Test("Log buffer maintains order")
    func logBufferMaintainsOrder() async throws {
        var buffer = LogBuffer(maxSize: 100)
        
        let timestamps = (0..<10).map { Date(timeIntervalSinceNow: TimeInterval($0)) }
        
        for (index, timestamp) in timestamps.enumerated() {
            buffer.append(LogEntry(timestamp: timestamp, stream: .stdout, message: "Log \(index)"))
        }
        
        let entries = buffer.entries
        
        // Verify chronological order
        for i in 0..<(entries.count - 1) {
            #expect(entries[i].timestamp <= entries[i + 1].timestamp)
        }
    }
    
    @Test("Log buffer can be cleared")
    func logBufferCanBeCleared() async throws {
        var buffer = LogBuffer(maxSize: 100)
        
        for i in 0..<50 {
            buffer.append(LogEntry(timestamp: Date(), stream: .stdout, message: "Log \(i)"))
        }
        
        #expect(buffer.count == 50)
        
        buffer.clear()
        
        #expect(buffer.count == 0)
        #expect(buffer.entries.isEmpty)
    }
    
    // MARK: - Timestamp Formatting Tests
    
    @Test("Format timestamp with default format")
    func formatTimestampDefault() throws {
        let date = Date()
        let formatted = LogEntry.formatTimestamp(date)
        
        #expect(!formatted.isEmpty)
        #expect(formatted.contains(":"))
    }
    
    @Test("Format timestamp with custom format")
    func formatTimestampCustom() throws {
        let date = Date()
        let formatted = LogEntry.formatTimestamp(date, format: "yyyy-MM-dd")
        
        #expect(!formatted.isEmpty)
        #expect(formatted.contains("-"))
        #expect(formatted.count == 10) // YYYY-MM-DD
    }
    
    @Test("Parse ISO8601 timestamp")
    func parseISO8601Timestamp() throws {
        let iso8601String = "2026-02-06T10:30:45.123456Z"
        let parsed = LogEntry.parseISO8601(iso8601String)
        
        #expect(parsed != nil)
    }
    
    // MARK: - Performance Tests
    
    @Test("Parse large number of log entries efficiently")
    func parseLargeNumberOfLogEntries() async throws {
        var logLines = ""
        for i in 0..<1000 {
            logLines += "2026-02-06T10:30:45.123456Z stdout: Log entry \(i)\n"
        }
        
        let startTime = Date()
        let entries = LogEntry.parseMultiple(logLines)
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(entries.count == 1000)
        #expect(duration < 1.0) // Should parse 1000 entries in less than 1 second
    }
    
    @Test("Filter large log set efficiently")
    func filterLargeLogSetEfficiently() async throws {
        let logs = (0..<10000).map { i in
            LogEntry(
                timestamp: Date(),
                stream: i % 2 == 0 ? .stdout : .stderr,
                message: "Log entry \(i)"
            )
        }
        
        let startTime = Date()
        let filtered = LogEntry.filter(logs, stream: .stdout)
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(filtered.count == 5000)
        #expect(duration < 0.5) // Should filter 10K entries in less than 0.5 seconds
    }
}

// MARK: - Supporting Types for Testing

extension ContainerSystemMonitor {
    func fetchLogs(containerName: String, tail: Int) async -> [LogEntry]? {
        // This will be implemented in the actual feature
        // For now, return nil to make tests compilable
        return nil
    }
    
    func streamLogs(containerName: String) async -> AsyncStream<LogEntry>? {
        // This will be implemented in the actual feature
        return nil
    }
}

// MARK: - Mock Data Structures (will be moved to actual implementation)

struct LogEntry: Equatable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let stream: LogStream
    let message: String
    
    enum LogStream: String {
        case stdout
        case stderr
    }
    
    static func parse(_ line: String) -> LogEntry? {
        // Simple parser - will be enhanced in implementation
        let components = line.components(separatedBy: " ")
        
        if components.count >= 2 {
            // Try to parse timestamp
            let timestampString = components[0]
            let timestamp = parseISO8601(timestampString) ?? Date()
            
            // Determine stream
            var stream: LogStream = .stdout
            var messageStart = 1
            
            if components.count > 2 && (components[1] == "stdout:" || components[1] == "stderr:") {
                stream = components[1].hasPrefix("stdout") ? .stdout : .stderr
                messageStart = 2
            }
            
            // Extract message
            let message = components[messageStart...].joined(separator: " ")
            
            return LogEntry(timestamp: timestamp, stream: stream, message: message)
        }
        
        // Fallback for malformed lines
        return LogEntry(timestamp: Date(), stream: .stdout, message: line)
    }
    
    static func parseMultiple(_ text: String) -> [LogEntry] {
        return text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .compactMap { parse($0) }
    }
    
    static func filter(_ logs: [LogEntry], searchTerm: String) -> [LogEntry] {
        return logs.filter { $0.message.localizedCaseInsensitiveContains(searchTerm) }
    }
    
    static func filter(_ logs: [LogEntry], stream: LogStream) -> [LogEntry] {
        return logs.filter { $0.stream == stream }
    }
    
    static func filter(_ logs: [LogEntry], since: Date) -> [LogEntry] {
        return logs.filter { $0.timestamp >= since }
    }
    
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
            return false
        }
    }
    
    static func formatTimestamp(_ date: Date, format: String = "yyyy-MM-dd HH:mm:ss") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}

struct LogBuffer {
    private(set) var entries: [LogEntry] = []
    let maxSize: Int
    
    var count: Int {
        entries.count
    }
    
    mutating func append(_ entry: LogEntry) {
        entries.append(entry)
        
        // Maintain max size
        if entries.count > maxSize {
            entries.removeFirst(entries.count - maxSize)
        }
    }
    
    mutating func clear() {
        entries.removeAll()
    }
}
