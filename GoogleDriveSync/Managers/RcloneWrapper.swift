//
//  RcloneWrapper.swift
//  GoogleDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import Foundation

enum RcloneError: LocalizedError {
    case notInstalled
    case configurationFailed(String)
    case syncFailed(String)
    case invalidRemote(String)
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "rclone is not installed. Please install it via Homebrew: brew install rclone"
        case .configurationFailed(let message):
            return "Configuration failed: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .invalidRemote(let name):
            return "Invalid remote: \(name)"
        }
    }
}

struct RcloneRemote: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let type: String
    
    var displayName: String {
        "\(name) (\(type))"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
    }
    
    static func == (lhs: RcloneRemote, rhs: RcloneRemote) -> Bool {
        lhs.name == rhs.name && lhs.type == rhs.type
    }
}

actor RcloneWrapper {
    private let rclonePath: String
    private let runner = ProcessRunner.shared
    
    init(rclonePath: String = AppSettings.defaultRclonePath) {
        self.rclonePath = rclonePath
    }
    
    /// Cancel any currently running sync operation
    func cancelCurrentOperation() async {
        await runner.terminateCurrentProcess()
    }
    
    // MARK: - Installation Check
    
    func isInstalled() async -> Bool {
        do {
            let result = try await runner.run(rclonePath, arguments: ["version"])
            return result.isSuccess
        } catch {
            return false
        }
    }
    
    func version() async throws -> String {
        let result = try await runner.run(rclonePath, arguments: ["version"])
        guard result.isSuccess else {
            throw RcloneError.notInstalled
        }
        // Extract first line (e.g., "rclone v1.65.0")
        return result.stdout.components(separatedBy: "\n").first ?? result.stdout
    }
    
    // MARK: - Remote Management
    
    func listRemotes() async throws -> [RcloneRemote] {
        let result = try await runner.run(rclonePath, arguments: ["listremotes", "--long"])
        guard result.isSuccess else {
            throw RcloneError.configurationFailed(result.stderr)
        }
        
        var remotes: [RcloneRemote] = []
        let lines = result.stdout.components(separatedBy: "\n")
        
        for line in lines where !line.isEmpty {
            // Format: "remotename: type"
            let parts = line.components(separatedBy: ":")
            if parts.count >= 2 {
                let name = parts[0].trimmingCharacters(in: .whitespaces)
                let type = parts[1].trimmingCharacters(in: .whitespaces)
                remotes.append(RcloneRemote(name: name, type: type))
            }
        }
        
        return remotes
    }
    
    func listDriveRemotes() async throws -> [RcloneRemote] {
        let allRemotes = try await listRemotes()
        return allRemotes.filter { $0.type == "drive" }
    }
    
    /// Opens Terminal to run rclone config for adding a new Google Drive
    func configureNewDrive(name: String) async throws {
        // Build the rclone config command
        let command = "\(rclonePath) config create \(name) drive"
        
        // Open Terminal and run the command
        let script = """
        tell application "Terminal"
            activate
            do script "\(command)"
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        try process.run()
        process.waitUntilExit()
    }
    
    /// Opens Terminal to run interactive rclone config
    func openInteractiveConfig() async throws {
        let script = """
        tell application "Terminal"
            activate
            do script "\(rclonePath) config"
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        try process.run()
        process.waitUntilExit()
    }
    
    /// Rename an existing remote
    func renameRemote(from oldName: String, to newName: String) async throws {
        // Use rclone config update to effectively rename by creating new and deleting old
        // First, get the config for the old remote
        let showResult = try await runner.run(rclonePath, arguments: ["config", "show", oldName])
        guard showResult.isSuccess else {
            throw RcloneError.invalidRemote(oldName)
        }
        
        // Parse the config to get the token
        let configLines = showResult.stdout.components(separatedBy: "\n")
        var token = ""
        for line in configLines {
            if line.hasPrefix("token = ") {
                token = String(line.dropFirst("token = ".count))
            }
        }
        
        // Create new remote with the new name using the same token
        let createArgs = ["config", "create", newName, "drive", "token", token]
        let createResult = try await runner.run(rclonePath, arguments: createArgs)
        guard createResult.isSuccess else {
            throw RcloneError.configurationFailed("Failed to create new remote: \(createResult.stderr)")
        }
        
        // Delete the old remote
        let deleteResult = try await runner.run(rclonePath, arguments: ["config", "delete", oldName])
        guard deleteResult.isSuccess else {
            // Try to clean up the new one if delete fails
            _ = try? await runner.run(rclonePath, arguments: ["config", "delete", newName])
            throw RcloneError.configurationFailed("Failed to delete old remote: \(deleteResult.stderr)")
        }
    }
    
    /// Delete a remote
    func deleteRemote(name: String) async throws {
        let result = try await runner.run(rclonePath, arguments: ["config", "delete", name])
        guard result.isSuccess else {
            throw RcloneError.configurationFailed("Failed to delete remote: \(result.stderr)")
        }
    }
    
    /// Get the Google Drive folder ID for a remote path
    /// Returns "root" for empty paths (My Drive root), or the actual folder ID
    func getFolderID(remote: String, path: String) async -> String? {
        do {
            // If path is empty, we're looking at the root (My Drive)
            if path.isEmpty {
                // Return special marker for root
                return "root"
            }
            
            // To get the folder ID, we need to list the parent directory and find our folder by name
            // Split path to get parent and folder name
            let pathComponents = path.components(separatedBy: "/")
            let folderName = pathComponents.last ?? path
            let parentPath = pathComponents.dropLast().joined(separator: "/")
            
            // List the parent directory (or root if no parent)
            let listPath = parentPath.isEmpty ? "\(remote):" : "\(remote):\(parentPath)"
            let result = try await runner.run(rclonePath, arguments: ["lsjson", listPath, "--dirs-only"])
            
            if result.isSuccess, let data = result.stdout.data(using: .utf8) {
                // Parse JSON array
                if let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    // Find our folder by name
                    for item in items {
                        if let name = item["Name"] as? String, name == folderName,
                           let id = item["ID"] as? String {
                            return id
                        }
                    }
                }
            }
        } catch {
            print("Failed to get folder ID: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Sync Operations
    
    func sync(
        source: String,
        destination: String,
        dryRun: Bool = false,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> SyncResult {
        var args = ["sync", source, destination, "--progress", "--stats-one-line"]
        
        if dryRun {
            args.append("--dry-run")
        }
        
        let startTime = Date()
        
        let result: ProcessResult
        if let progressHandler = onProgress {
            result = try await runner.runWithProgress(rclonePath, arguments: args) { output in
                progressHandler(output)
            }
        } else {
            result = try await runner.run(rclonePath, arguments: args)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        if result.isSuccess {
            return SyncResult(
                success: true,
                filesTransferred: parseFileCount(from: result.stdout),
                bytesTransferred: parseByteCount(from: result.stdout),
                duration: duration,
                error: nil
            )
        } else {
            throw RcloneError.syncFailed(result.stderr)
        }
    }
    
    func copy(
        source: String,
        destination: String,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> SyncResult {
        let args = ["copy", source, destination, "--progress", "--stats-one-line"]
        
        let startTime = Date()
        
        let result: ProcessResult
        if let progressHandler = onProgress {
            result = try await runner.runWithProgress(rclonePath, arguments: args) { output in
                progressHandler(output)
            }
        } else {
            result = try await runner.run(rclonePath, arguments: args)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        if result.isSuccess {
            return SyncResult(
                success: true,
                filesTransferred: parseFileCount(from: result.stdout),
                bytesTransferred: parseByteCount(from: result.stdout),
                duration: duration,
                error: nil
            )
        } else {
            throw RcloneError.syncFailed(result.stderr)
        }
    }
    
    // MARK: - Helpers
    
    private func parseFileCount(from output: String) -> Int {
        // Parse "Transferred: X / Y, 100%" pattern
        let pattern = #"Transferred:\s+(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let range = Range(match.range(at: 1), in: output) {
            return Int(output[range]) ?? 0
        }
        return 0
    }
    
    private func parseByteCount(from output: String) -> Int64 {
        // Parse byte counts - simplified
        return 0
    }
}

struct SyncResult {
    let success: Bool
    let filesTransferred: Int
    let bytesTransferred: Int64
    let duration: TimeInterval
    let error: String?
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "\(Int(duration))s"
    }
}
