//
//  RcloneWrapper.swift
//  DriveSync
//
//  Created by saihgupr on 2024-12-11.
//  Edited by MichasCoup on 2026-07-26.
//

import Foundation

enum BisyncMode {
    case normal
    case initial
    case resync
}

enum RcloneError: LocalizedError {
    case notInstalled
    case configurationFailed(String)
    case syncFailed(String)
    case bisyncNeedsResync(String)
    case invalidRemote(String)
    case authorizationCancelled
    case authorizationTimedOut
    case authorizationFailed(String)
    case verificationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "rclone is not installed. Please install it via Homebrew: brew install rclone"
        case .configurationFailed(let message):
            return "Configuration failed: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .bisyncNeedsResync(let message):
            return "Bi-Sync failed and requires a resync: \(message)"
        case .invalidRemote(let name):
            return "Invalid remote: \(name)"
        case .authorizationCancelled:
            return "Sign-in was cancelled."
        case .authorizationTimedOut:
            return "Sign-in timed out. Finish signing in within the browser and try again."
        case .authorizationFailed(let message):
            return "Google sign-in failed: \(message)"
        case .verificationFailed(let message):
            return "The account was created but Google Drive rejected it: \(message)"
        }
    }
}

/// OAuth client credentials from the user's own Google Cloud project.
///
/// rclone's shared Google Drive client ID is being retired during 2026, so each
/// user is expected to create a Desktop-app OAuth client and supply its ID and
/// secret here. See docs/GoogleDriveOnboarding.md.
struct DriveClientCredentials: Equatable, Sendable {
    static let clientIDSuffix = ".apps.googleusercontent.com"
    
    let clientID: String
    let clientSecret: String
    
    init(clientID: String, clientSecret: String) {
        self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var hasValidClientID: Bool {
        clientID.hasSuffix(Self.clientIDSuffix) && clientID.count > Self.clientIDSuffix.count
    }
    
    var isComplete: Bool {
        hasValidClientID && !clientSecret.isEmpty
    }
}

/// What we learn about a Drive account when verifying it with `rclone about`.
struct DriveAccountInfo: Equatable, Sendable {
    let totalBytes: Int64?
    let usedBytes: Int64?
    
    var summary: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        switch (usedBytes, totalBytes) {
        case let (used?, total?):
            return "\(formatter.string(fromByteCount: used)) of \(formatter.string(fromByteCount: total)) used"
        case let (used?, nil):
            return "\(formatter.string(fromByteCount: used)) used"
        default:
            return "Connected"
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
    
    // MARK: - Google Drive Onboarding
    
    /// Default time to wait for the user to finish signing in with Google.
    static let authorizationTimeout: TimeInterval = 180
    
    /// Runs `rclone authorize drive [client_id client_secret]`.
    ///
    /// rclone opens the default browser, serves the OAuth callback on
    /// 127.0.0.1:53682 itself, and prints the resulting token JSON on stdout
    /// between `--->` and `<---End paste`. The sign-in URL is reported on stderr
    /// as soon as it is known so the UI can offer a "browser didn't open" link.
    ///
    /// - Returns: the token JSON to pass to `createDriveAccount`.
    func authorizeDrive(
        credentials: DriveClientCredentials?,
        timeout: TimeInterval = RcloneWrapper.authorizationTimeout,
        onStart: (@Sendable (ProcessHandle) -> Void)? = nil,
        onAuthURL: (@Sendable (URL) -> Void)? = nil
    ) async throws -> String {
        var args = ["authorize", "drive"]
        if let credentials {
            args.append(contentsOf: [credentials.clientID, credentials.clientSecret])
        }
        
        let result = try await runner.runStreaming(
            rclonePath,
            arguments: args,
            timeout: timeout,
            onStart: onStart,
            onStderr: { chunk in
                if let url = RcloneWrapper.extractAuthURL(from: chunk) {
                    onAuthURL?(url)
                }
            }
        )
        
        if result.timedOut { throw RcloneError.authorizationTimedOut }
        if result.wasCancelled { throw RcloneError.authorizationCancelled }
        guard result.isSuccess else {
            throw RcloneError.authorizationFailed(RcloneWrapper.cleanErrorMessage(result.stderr))
        }
        guard let token = RcloneWrapper.extractToken(from: result.stdout) else {
            throw RcloneError.authorizationFailed("rclone did not return a token. Output was: \(result.stdout.prefix(300))")
        }
        return token
    }
    
    /// Creates a Google Drive remote from an already-obtained token.
    ///
    /// Every question rclone's config state machine would ask is answered up
    /// front so `--non-interactive` reaches its terminal state instead of
    /// returning a JSON question with exit code 0 (which the old flow mistook
    /// for success and which left a tokenless remote behind).
    func createDriveAccount(name: String, credentials: DriveClientCredentials?, token: String) async throws {
        var options: [String] = []
        if let credentials {
            options.append(contentsOf: [
                "client_id=\(credentials.clientID)",
                "client_secret=\(credentials.clientSecret)"
            ])
        } else {
            // Shared client: acknowledge rclone's retirement warning.
            options.append("config_shared_client_id=true")
        }
        options.append(contentsOf: [
            "scope=drive",
            "token=\(token)",
            "config_refresh_token=false",       // we already have a token
            "config_change_team_drive=false"    // My Drive, not a Shared Drive
        ])
        
        let args = ["config", "create", name, "drive"] + options + ["--non-interactive"]
        let result = try await runner.run(rclonePath, arguments: args)
        guard result.isSuccess else {
            throw RcloneError.configurationFailed(RcloneWrapper.cleanErrorMessage(result.stderr))
        }
        try RcloneWrapper.checkNonInteractiveResult(result.stdout)
    }
    
    /// Confirms the remote can actually talk to Google Drive.
    ///
    /// `rclone about` is a single cheap API call that fails fast on a bad
    /// client ID, a revoked token, or a consent screen still in "Testing".
    func verifyRemote(name: String) async throws -> DriveAccountInfo {
        let result = try await runner.run(rclonePath, arguments: ["about", "\(name):", "--json"])
        guard result.isSuccess else {
            throw RcloneError.verificationFailed(RcloneWrapper.cleanErrorMessage(result.stderr))
        }
        
        var total: Int64? = nil
        var used: Int64? = nil
        if let data = result.stdout.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            total = (json["total"] as? NSNumber)?.int64Value
            used = (json["used"] as? NSNumber)?.int64Value
        }
        return DriveAccountInfo(totalBytes: total, usedBytes: used)
    }
    
    /// Returns every key/value pair rclone has stored for each remote.
    func dumpConfig() async throws -> [String: [String: String]] {
        let result = try await runner.run(rclonePath, arguments: ["config", "dump"])
        guard result.isSuccess, let data = result.stdout.data(using: .utf8) else {
            throw RcloneError.configurationFailed(RcloneWrapper.cleanErrorMessage(result.stderr))
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var remotes: [String: [String: String]] = [:]
        for (name, value) in json {
            guard let section = value as? [String: Any] else { continue }
            var pairs: [String: String] = [:]
            for (key, raw) in section {
                if let str = raw as? String {
                    pairs[key] = str
                } else {
                    pairs[key] = "\(raw)"
                }
            }
            remotes[name] = pairs
        }
        return remotes
    }
    
    /// Client credentials already used by an existing Drive remote, if any.
    /// Lets a second account reuse the OAuth client the user set up for the first.
    func existingDriveClientCredentials() async -> DriveClientCredentials? {
        guard let remotes = try? await dumpConfig() else { return nil }
        for name in remotes.keys.sorted() {
            guard let section = remotes[name], section["type"] == "drive",
                  let id = section["client_id"], let secret = section["client_secret"] else { continue }
            let credentials = DriveClientCredentials(clientID: id, clientSecret: secret)
            if credentials.isComplete { return credentials }
        }
        return nil
    }
    
    /// Rename an existing remote
    ///
    /// rclone has no rename command, so this copies every stored key (token,
    /// client ID/secret, scope, team drive...) into a new remote and deletes
    /// the old one. Earlier versions copied only the token, which silently
    /// dropped a user's own client ID and broke the account on next sync.
    func renameRemote(from oldName: String, to newName: String) async throws {
        let remotes = try await dumpConfig()
        guard let section = remotes[oldName], let type = section["type"], !type.isEmpty else {
            throw RcloneError.invalidRemote(oldName)
        }
        
        var options: [String] = []
        for key in section.keys.sorted() where key != "type" {
            options.append("\(key)=\(section[key] ?? "")")
        }
        if type == "drive" {
            // Answer the questions rclone would otherwise ask about a token we already have.
            if section["token"] != nil { options.append("config_refresh_token=false") }
            if section["client_id"] == nil { options.append("config_shared_client_id=true") }
            options.append("config_change_team_drive=false")
        }
        
        let createArgs = ["config", "create", newName, type] + options + ["--non-interactive"]
        let createResult = try await runner.run(rclonePath, arguments: createArgs)
        guard createResult.isSuccess else {
            throw RcloneError.configurationFailed("Failed to create new remote: \(RcloneWrapper.cleanErrorMessage(createResult.stderr))")
        }
        do {
            try RcloneWrapper.checkNonInteractiveResult(createResult.stdout)
        } catch {
            _ = try? await runner.run(rclonePath, arguments: ["config", "delete", newName])
            throw error
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
        ignoredPatterns: [String] = [],
        dryRun: Bool = false,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> SyncResult {
        var args = ["sync", source, destination, "--progress", "--stats-one-line"]
        
        for pattern in ignoredPatterns {
            let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                args.append(contentsOf: ["--exclude", trimmed])
            }
        }
        
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
        ignoredPatterns: [String] = [],
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> SyncResult {
        var args = ["copy", source, destination, "--progress", "--stats-one-line"]
        
        for pattern in ignoredPatterns {
            let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                args.append(contentsOf: ["--exclude", trimmed])
            }
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
    
    func bidirectionalSync(
        local: String,
        remote: String,
        ignoredPatterns: [String] = [],
        mode: BisyncMode,
        dryRun: Bool = false,
        onProgress: (@Sendable (String) -> Void)? = nil
    ) async throws -> SyncResult {
        
        var args = [
            "bisync",
            local,
            remote,
            "--progress",
            "--stats-one-line",
            "--resilient",
            "--recover",
            "--max-lock", "2m",
            "--conflict-resolve", "newer"
        ]

        if mode == .initial {
            args.append(contentsOf: [
                "--resync-mode", "newer"
            ])
        }

        for pattern in ignoredPatterns {
            let trimmed = pattern.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                args.append(contentsOf: [
                    "--exclude",
                    trimmed
                ])
            }
        }

        if dryRun {
            args.append("--dry-run")
        }

        let startTime = Date()
        let result: ProcessResult

        if let progressHandler = onProgress {
            result = try await runner.runWithProgress(
                rclonePath,
                arguments: args
            ) { output in
                progressHandler(output)
            }
        } else {
            result = try await runner.run(
                rclonePath,
                arguments: args
            )
        }

        let duration = Date().timeIntervalSince(startTime)

        guard result.isSuccess else {
            let errorMessage = result.stderr.isEmpty
                ? result.stdout
                : result.stderr

            if result.exitCode == 7 {
                throw RcloneError.bisyncNeedsResync(errorMessage)
            }

            throw RcloneError.syncFailed(errorMessage)
        }

        let combinedOutput = result.stdout + "\n" + result.stderr

        return SyncResult(
            success: true,
            filesTransferred: parseFileCount(from: combinedOutput),
            bytesTransferred: parseByteCount(from: combinedOutput),
            duration: duration,
            error: nil
        )
    }

    // MARK: - Helpers
    
    /// `rclone authorize` prints "Please go to the following link: http://127.0.0.1:53682/auth?state=..." on stderr.
    static func extractAuthURL(from text: String) -> URL? {
        let pattern = #"(https?://127\.0\.0\.1:\d+/auth\?state=[A-Za-z0-9_\-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return URL(string: String(text[range]))
    }
    
    /// Pulls the token JSON out of `rclone authorize` stdout:
    ///
    ///     Paste the following into your remote machine --->
    ///     {"access_token":...}
    ///     <---End paste
    static func extractToken(from stdout: String) -> String? {
        guard let startMarker = stdout.range(of: "--->"),
              let endMarker = stdout.range(of: "<---", range: startMarker.upperBound..<stdout.endIndex) else {
            return nil
        }
        let token = stdout[startMarker.upperBound..<endMarker.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.hasPrefix("{"), token.hasSuffix("}"),
              let data = token.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else { return nil }
        return token
    }
    
    /// `rclone config create --non-interactive` exits 0 even when it stopped at a
    /// question. Treat anything other than the terminal state as a failure.
    static func checkNonInteractiveResult(_ stdout: String) throws {
        guard let data = stdout.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Older rclone prints nothing on success.
            if stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
            throw RcloneError.configurationFailed("Unexpected rclone output: \(stdout.prefix(300))")
        }
        if let error = json["Error"] as? String, !error.isEmpty {
            throw RcloneError.configurationFailed(error)
        }
        if let state = json["State"] as? String, !state.isEmpty {
            let option = json["Option"] as? [String: Any]
            let help = (option?["Help"] as? String)?.components(separatedBy: "\n").first ?? state
            throw RcloneError.configurationFailed("rclone needs an answer we did not supply (\(state)): \(help)")
        }
    }
    
    /// Strips rclone's log prefixes ("2026/11/09 15:23:07 CRITICAL: ") and adds a
    /// plain-English hint for the Google errors people actually hit.
    static func cleanErrorMessage(_ stderr: String) -> String {
        let lines = stderr
            .components(separatedBy: "\n")
            .map { line -> String in
                let pattern = #"^\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2} (NOTICE|ERROR|CRITICAL|INFO|DEBUG|Failed to [a-z ]+): ?"#
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    return regex.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "")
                }
                return line
            }
            .filter { !$0.isEmpty && !$0.hasPrefix("Config file") && !$0.hasPrefix("Make sure your Redirect URL") }
        var message = lines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty { message = "rclone exited with an error but printed nothing." }
        if message.count > 500 { message = String(message.prefix(500)) + "…" }
        
        let lower = message.lowercased()
        if lower.contains("invalid_client") || lower.contains("oauth client was not found") {
            message += "\n\nHint: Google does not recognise this Client ID / Secret. Check both values in the Google Cloud Console under APIs & Services → Credentials, and make sure the OAuth client type is \"Desktop app\"."
        } else if lower.contains("invalid_grant") {
            message += "\n\nHint: the token was revoked or expired. If your OAuth consent screen is still in \"Testing\", Google expires tokens after 7 days; set the publishing status to \"In production\"."
        } else if lower.contains("access_denied") || lower.contains("has not completed the google verification") {
            message += "\n\nHint: Google refused the sign-in. If the consent screen is in \"Testing\", your Google account must be listed as a test user, or set the publishing status to \"In production\"."
        } else if lower.contains("accessnotconfigured") || lower.contains("drive api has not been used") {
            message += "\n\nHint: enable the Google Drive API for your project in the Google Cloud Console."
        } else if lower.contains("address already in use") {
            message += "\n\nHint: another rclone sign-in is still waiting on port 53682. Quit it (or run `pkill -f 'rclone authorize'`) and try again."
        }
        return message
    }
    
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
        // rclone stats one-line outputs like: "Transferred: 5.459 MiB / 6.622 MiB, 82%, 0 B/s, ETA -"
        // We look for the part before the first "/"
        let pattern = #"Transferred:\s+([\d.]+)\s*(\w+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let valueRange = Range(match.range(at: 1), in: output),
           let unitRange = Range(match.range(at: 2), in: output) {
            
            let valueStr = String(output[valueRange])
            let unitStr = String(output[unitRange]).lowercased()
            
            if let value = Double(valueStr) {
                let multiplier: Double
                switch unitStr {
                case "b": multiplier = 1
                case "k", "kib": multiplier = 1024
                case "m", "mib": multiplier = 1024 * 1024
                case "g", "gib": multiplier = 1024 * 1024 * 1024
                case "t", "tib": multiplier = 1024 * 1024 * 1024 * 1024
                default: multiplier = 1
                }
                return Int64(value * multiplier)
            }
        }
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
