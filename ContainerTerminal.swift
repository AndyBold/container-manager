//
//  ContainerTerminal.swift
//  container-manager
//
//  Interactive terminal session management
//

import Foundation

// MARK: - Exec Result

struct ExecResult {
    let exitCode: Int?
    let stdout: String?
    let stderr: String?
    let timedOut: Bool
    let error: String?
}

// MARK: - Interactive Exec Session

actor InteractiveExecSession {
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var outputBuffer: String = ""
    private var outputTask: Task<Void, Never>?
    private var lastReadPosition: Int = 0
    
    var isRunning: Bool {
        guard let process = process else { return false }
        return process.isRunning
    }
    
    init(process: Process, inputPipe: Pipe, outputPipe: Pipe) {
        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        
        // Start monitoring output in a Task since init is nonisolated
        Task {
            await self.startOutputMonitoring()
        }
    }
    
    private func startOutputMonitoring() {
        outputTask = Task {
            guard let outputPipe = outputPipe else { return }
            
            let fileHandle = outputPipe.fileHandleForReading
            
            // Use async reading
            while !Task.isCancelled {
                do {
                    let data = fileHandle.availableData
                    if !data.isEmpty {
                        if let text = String(data: data, encoding: .utf8) {
                            outputBuffer += text
                        }
                    }
                    
                    // Small delay to avoid busy waiting
                    try await Task.sleep(for: .milliseconds(50))
                } catch {
                    break
                }
            }
        }
    }
    
    func sendInput(_ text: String) -> Bool {
        guard let inputPipe = inputPipe,
              let data = text.data(using: .utf8) else {
            return false
        }
        
        do {
            try inputPipe.fileHandleForWriting.write(contentsOf: data)
            return true
        } catch {
            print("Error sending input: \(error)")
            return false
        }
    }
    
    func getRecentOutput() -> String? {
        guard lastReadPosition < outputBuffer.count else {
            return nil
        }
        
        let startIndex = outputBuffer.index(outputBuffer.startIndex, offsetBy: lastReadPosition)
        let newOutput = String(outputBuffer[startIndex...])
        lastReadPosition = outputBuffer.count
        
        return newOutput.isEmpty ? nil : newOutput
    }
    
    func clearOutput() {
        outputBuffer = ""
        lastReadPosition = 0
    }
    
    func terminate() {
        outputTask?.cancel()
        outputTask = nil
        
        if let process = process, process.isRunning {
            process.terminate()
        }
        
        // Close pipes
        try? inputPipe?.fileHandleForWriting.close()
        try? outputPipe?.fileHandleForReading.close()
        
        inputPipe = nil
        outputPipe = nil
        process = nil
    }
}

// MARK: - Command History

struct CommandHistory {
    private var commands: [String] = []
    private var currentIndex: Int?
    private let maxSize: Int
    
    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }
    
    mutating func add(_ command: String) {
        guard !command.isEmpty else { return }
        
        // Don't add duplicate consecutive commands
        if let last = commands.last, last == command {
            return
        }
        
        commands.append(command)
        
        // Maintain max size
        if commands.count > maxSize {
            commands.removeFirst()
        }
        
        resetNavigation()
    }
    
    mutating func previous() -> String? {
        guard !commands.isEmpty else { return nil }
        
        if let currentIndex = currentIndex {
            if currentIndex > 0 {
                self.currentIndex = currentIndex - 1
                return commands[currentIndex - 1]
            }
            return commands[currentIndex]
        } else {
            currentIndex = commands.count - 1
            return commands[commands.count - 1]
        }
    }
    
    mutating func next() -> String? {
        guard !commands.isEmpty, let currentIndex = currentIndex else {
            return nil
        }
        
        if currentIndex < commands.count - 1 {
            self.currentIndex = currentIndex + 1
            return commands[currentIndex + 1]
        } else {
            self.currentIndex = nil
            return nil
        }
    }
    
    mutating func resetNavigation() {
        currentIndex = nil
    }
    
    func getAll() -> [String] {
        return commands
    }
}

// MARK: - Container System Monitor Extension

extension ContainerSystemMonitor {
    
    /// Detect available shells in a container
    /// - Parameter containerName: Name of the container
    /// - Returns: Array of available shell paths, or nil if detection failed
    func detectAvailableShells(containerName: String) async -> [String]? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        let commonShells = [
            "/bin/bash",
            "/bin/sh",
            "/bin/zsh",
            "/bin/ash",
            "/bin/dash"
        ]
        
        var availableShells: [String] = []
        
        for shell in commonShells {
            // Check if shell exists in container
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                
                let command = "\(containerPath) exec \(containerName) test -f \(shell)"
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
                    availableShells.append(shell)
                }
            } catch {
                // Continue checking other shells
                continue
            }
        }
        
        // If no shells found, default to /bin/sh
        if availableShells.isEmpty {
            availableShells = ["/bin/sh"]
        }
        
        return availableShells
    }
    
    /// Get the default shell for a container
    /// - Parameter containerName: Name of the container
    /// - Returns: Path to the default shell, or nil if detection failed
    func getDefaultShell(containerName: String) async -> String? {
        guard let availableShells = await detectAvailableShells(containerName: containerName) else {
            return nil
        }
        
        // Prefer bash, then zsh, then fall back to the first available shell
        if availableShells.contains("/bin/bash") {
            return "/bin/bash"
        } else if availableShells.contains("/bin/zsh") {
            return "/bin/zsh"
        } else {
            return availableShells.first
        }
    }
    
    /// Start an interactive exec session with a container
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - shell: Shell to use (default: /bin/sh)
    /// - Returns: Interactive exec session, or nil if failed
    func startInteractiveExec(containerName: String, shell: String = "/bin/sh") async -> InteractiveExecSession? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            // Use interactive mode with PTY allocation
            let command = "\(containerPath) exec -it \(containerName) \(shell)"
            process.arguments = ["-c", command]
            
            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            if let existingPath = environment["PATH"] {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            environment["TERM"] = "xterm-256color"
            process.environment = environment
            
            let inputPipe = Pipe()
            let outputPipe = Pipe()
            
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = outputPipe // Combine stderr with stdout
            
            try process.run()
            
            // Create and return session
            return InteractiveExecSession(
                process: process,
                inputPipe: inputPipe,
                outputPipe: outputPipe
            )
            
        } catch {
            print("Error starting interactive exec: \(error)")
            return nil
        }
    }
    
    /// Stream command output in real-time
    /// - Parameters:
    ///   - containerName: Name of the container
    ///   - command: Command to execute
    ///   - arguments: Optional command arguments
    /// - Returns: AsyncStream of output strings, or nil if failed
    func streamExecOutput(
        containerName: String,
        command: String,
        arguments: [String] = []
    ) async -> AsyncStream<String>? {
        guard let containerPath = containerPath else {
            return nil
        }
        
        return AsyncStream { continuation in
            Task {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    
                    // Build command
                    var fullCommand = "\(containerPath) exec \(containerName) \(command)"
                    
                    if !arguments.isEmpty {
                        fullCommand += " " + arguments.joined(separator: " ")
                    }
                    
                    process.arguments = ["-c", fullCommand]
                    
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
                    process.standardError = outputPipe // Combine stderr with stdout
                    
                    try process.run()
                    
                    let fileHandle = outputPipe.fileHandleForReading
                    
                    // Read output in chunks and stream it
                    while process.isRunning {
                        let data = fileHandle.availableData
                        if !data.isEmpty {
                            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                                continuation.yield(text)
                            }
                        }
                        
                        // Small delay to avoid busy waiting
                        try? await Task.sleep(for: .milliseconds(50))
                    }
                    
                    // Read any remaining output
                    let finalData = try fileHandle.readToEnd()
                    if let finalData = finalData, !finalData.isEmpty {
                        if let text = String(data: finalData, encoding: .utf8), !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    print("Error streaming exec output: \(error)")
                    continuation.finish()
                }
            }
        }
    }
}
// MARK: - Helper Extensions

// Helper extension for safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

