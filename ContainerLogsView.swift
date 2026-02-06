//
//  ContainerLogsView.swift
//  container-manager
//
//  Container logs viewer UI
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct ContainerLogsView: View {
    @EnvironmentObject var containerMonitor: ContainerSystemMonitor
    let containerName: String
    
    @State private var logs: [LogEntry] = []
    @State private var isStreaming = false
    @State private var autoScroll = true
    @State private var searchText = ""
    @State private var selectedStream: LogEntry.LogStream? = nil
    @State private var isLoading = false
    @State private var streamTask: Task<Void, Never>?
    
    @State private var scrollViewProxy: ScrollViewProxy?
    
    private var filteredLogs: [LogEntry] {
        var filtered = logs
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = LogEntry.filter(filtered, searchTerm: searchText)
        }
        
        // Apply stream filter
        if let stream = selectedStream {
            filtered = LogEntry.filter(filtered, stream: stream)
        }
        
        return filtered
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Logs: \(containerName)")
                    .font(.headline)
                
                Spacer()
                
                // Stream filter
                Picker("Stream", selection: $selectedStream) {
                    Text("All").tag(nil as LogEntry.LogStream?)
                    Text("stdout").tag(LogEntry.LogStream.stdout as LogEntry.LogStream?)
                    Text("stderr").tag(LogEntry.LogStream.stderr as LogEntry.LogStream?)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                // Search
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                // Auto-scroll toggle
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .help("Automatically scroll to newest log entries")
                
                // Stream toggle
                Button(action: toggleStreaming) {
                    Label(isStreaming ? "Stop" : "Stream", systemImage: isStreaming ? "stop.fill" : "play.fill")
                }
                .disabled(isLoading)
                
                // Refresh
                Button(action: refreshLogs) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading || isStreaming)
                
                // Clear
                Button(action: clearLogs) {
                    Label("Clear", systemImage: "trash")
                }
                
                // Export
                Button(action: exportLogs) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(logs.isEmpty)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Log content
            if isLoading && logs.isEmpty {
                loadingView
            } else if logs.isEmpty {
                emptyView
            } else {
                logListView
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("\(filteredLogs.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .controlSize(.small)
                        Text("Streaming...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if !searchText.isEmpty {
                    Button("Clear Search") {
                        searchText = ""
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onAppear {
            refreshLogs()
        }
        .onDisappear {
            stopStreaming()
        }
    }
    
    // MARK: - Views
    
    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredLogs) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollViewProxy = proxy
            }
            .onChange(of: filteredLogs.count) { oldValue, newValue in
                if autoScroll && newValue > oldValue {
                    if let lastLog = filteredLogs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading logs...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Logs")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("No log entries found for this container")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Button("Refresh") {
                refreshLogs()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func refreshLogs() {
        isLoading = true
        
        Task {
            let monitor = containerMonitor
            let fetchedLogs = await monitor.fetchLogs(containerName: containerName, tail: 1000)
            
            await MainActor.run {
                if let fetchedLogs = fetchedLogs {
                    logs = fetchedLogs
                }
                isLoading = false
            }
        }
    }
    
    private func toggleStreaming() {
        if isStreaming {
            stopStreaming()
        } else {
            startStreaming()
        }
    }
    
    private func startStreaming() {
        isStreaming = true
        
        streamTask = Task {
            let monitor = containerMonitor
            guard let stream = await monitor.streamLogs(containerName: containerName) else {
                await MainActor.run {
                    isStreaming = false
                }
                return
            }
            
            for await entry in stream {
                await MainActor.run {
                    logs.append(entry)
                }
            }
            
            await MainActor.run {
                isStreaming = false
            }
        }
    }
    
    private func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }
    
    private func clearLogs() {
        logs.removeAll()
    }
    
    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(containerName)-logs.txt"
        panel.allowedContentTypes = [.plainText]
        panel.message = "Export container logs"
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                let success = await LogEntry.exportToFile(logs, url: url)
                
                if success {
                    print("Logs exported successfully")
                } else {
                    print("Failed to export logs")
                }
            }
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry
    
    @State private var isHovered = false
    
    private var streamColor: Color {
        switch entry.stream {
        case .stdout:
            return .primary
        case .stderr:
            return .red
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(LogEntry.formatTimestamp(entry.timestamp, format: "HH:mm:ss.SSS"))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            
            // Stream indicator
            Circle()
                .fill(streamColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(streamColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.message, forType: .string)
            }
            
            Button("Copy Line") {
                let line = "\(LogEntry.formatTimestamp(entry.timestamp)) [\(entry.stream.rawValue)] \(entry.message)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(line, forType: .string)
            }
        }
    }
}

// MARK: - Preview

#Preview("Container Logs View") {
    ContainerLogsView(containerName: "nginx")
        .environmentObject(ContainerSystemMonitor())
        .frame(width: 900, height: 600)
}

#Preview("Log Entry Row") {
    VStack(spacing: 0) {
        LogEntryRow(entry: LogEntry(
            timestamp: Date(),
            stream: .stdout,
            message: "Application started successfully on port 8080"
        ))
        
        LogEntryRow(entry: LogEntry(
            timestamp: Date(),
            stream: .stderr,
            message: "Warning: Configuration file not found, using defaults"
        ))
        
        LogEntryRow(entry: LogEntry(
            timestamp: Date(),
            stream: .stdout,
            message: "Connected to database at postgresql://localhost:5432/mydb"
        ))
    }
    .frame(width: 800)
}
