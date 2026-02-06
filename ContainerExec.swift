//
//  ContainerExec.swift
//  container-manager
//
//  Container command execution and terminal support
//

import Foundation

// Note: ExecResult, InteractiveExecSession, and CommandHistory are now defined in ContainerTerminal.swift
// to avoid duplicate definitions

// MARK: - Container System Monitor Exec Extension

extension ContainerSystemMonitor {
    
    /// Execute a command in a container (non-interactive)
    func executeCommand(
        containerName: String,
        command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        user: String? = nil,
        timeout: TimeInterval? = nil
    ) async -> ExecResult? {
        guard let containerPath = containerPath else {
            return ExecResult(
                exitCode: nil,
                stdout: nil,
                stderr: nil,
                timedOut: false,
                error: "Container path not found"
            )
        }
        
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            // Build command
            var fullCommand = "\(containerPath) exec"
            
            if let workingDirectory = workingDirectory {
                fullCommand += " -w \(workingDirectory)"
            }
            
            if let user = user {
                fullCommand += " -u \(user)"
            }
            
            // Add environment variables
            if let environment = environment {
                for (key, value) in environment {
                    fullCommand += " -e \(key)=\(value)"
                }
            }
            
            fullCommand += " \(containerName) \(command)"
            
            if !arguments.isEmpty {
                fullCommand += " " + arguments.joined(separator: " ")
            }
            
            process.arguments = ["-c", fullCommand]
            
            // Set up environment
            var processEnv = ProcessInfo.processInfo.environment
            if let existingPath = processEnv["PATH"] {
                processEnv["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:\(existingPath)"
            } else {
                processEnv["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            }
            process.environment = processEnv
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            try process.run()
            
            // Handle timeout
            var timedOut = false
            if let timeout = timeout {
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning {
                        process.terminate()
                        timedOut = true
                    }
                }
            }
            
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let stdout = String(data: outputData, encoding: .utf8)
            let stderr = String(data: errorData, encoding: .utf8)
            
            return ExecResult(
                exitCode: Int(process.terminationStatus),
                stdout: stdout,
                stderr: stderr,
                timedOut: timedOut,
                error: nil
            )
            
        } catch {
            return ExecResult(
                exitCode: nil,
                stdout: nil,
                stderr: nil,
                timedOut: false,
                error: error.localizedDescription
            )
        }
    }
    
    /// Convenience method - alias for executeCommand
    /// This provides a shorter name for test compatibility
    func execCommand(
        containerName: String,
        command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        user: String? = nil,
        timeout: TimeInterval? = nil
    ) async -> ExecResult? {
        return await executeCommand(
            containerName: containerName,
            command: command,
            arguments: arguments,
            workingDirectory: workingDirectory,
            environment: environment,
            user: user,
            timeout: timeout
        )
    }
    
    // Note: startInteractiveExec, streamExecOutput, detectAvailableShells, and getDefaultShell
    // are now defined in ContainerTerminal.swift
}

// Note: Helper extensions like subscript(safe:) are now defined in ContainerTerminal.swift

