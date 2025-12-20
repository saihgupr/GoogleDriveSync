//
//  ProcessRunner.swift
//  GoogleDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import Foundation

struct ProcessResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let wasCancelled: Bool
    
    var isSuccess: Bool { exitCode == 0 && !wasCancelled }
    
    init(stdout: String, stderr: String, exitCode: Int32, wasCancelled: Bool = false) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.wasCancelled = wasCancelled
    }
}

actor ProcessRunner {
    static let shared = ProcessRunner()
    
    private var currentProcess: Process?
    
    private init() {}
    
    /// Terminate the currently running process
    func terminateCurrentProcess() {
        if let process = currentProcess, process.isRunning {
            process.terminate()
        }
    }
    
    func run(
        _ executablePath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: String? = nil
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                
                if let env = environment {
                    var processEnv = ProcessInfo.processInfo.environment
                    for (key, value) in env {
                        processEnv[key] = value
                    }
                    process.environment = processEnv
                }
                
                if let dir = currentDirectory {
                    process.currentDirectoryURL = URL(fileURLWithPath: dir)
                }
                
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    
                    let result = ProcessResult(
                        stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                        stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                        exitCode: process.terminationStatus
                    )
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Run a command with real-time output streaming (cancellable)
    func runWithProgress(
        _ executablePath: String,
        arguments: [String] = [],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult {
        // Create the process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        
        // Store reference for cancellation
        currentProcess = process
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                
                var allStdout = ""
                var allStderr = ""
                
                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                        allStdout += str
                        onOutput(str)
                    }
                }
                
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                        allStderr += str
                    }
                }
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    // Clean up handlers
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    
                    // Check if it was terminated (cancelled)
                    let wasCancelled = process.terminationReason == .uncaughtSignal
                    
                    let result = ProcessResult(
                        stdout: allStdout.trimmingCharacters(in: .whitespacesAndNewlines),
                        stderr: allStderr.trimmingCharacters(in: .whitespacesAndNewlines),
                        exitCode: process.terminationStatus,
                        wasCancelled: wasCancelled
                    )
                    
                    // Clear current process reference
                    Task {
                        await self?.clearCurrentProcess()
                    }
                    
                    continuation.resume(returning: result)
                } catch {
                    Task {
                        await self?.clearCurrentProcess()
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func clearCurrentProcess() {
        currentProcess = nil
    }
}
