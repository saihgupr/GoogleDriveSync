//
//  SyncManager.swift
//  GoogleDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import Foundation
import SwiftUI
import UserNotifications
import ServiceManagement

@MainActor
class SyncManager: ObservableObject {
    
    struct GitHubRelease: Codable {
        let tagName: String
        let htmlUrl: String
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    // MARK: - Published State
    
    @Published var folders: [SyncFolder] = []
    @Published var settings: AppSettings
    @Published var isRcloneInstalled: Bool = false
    @Published var rcloneVersion: String = ""
    @Published var availableRemotes: [RcloneRemote] = []
    @Published var isSyncing: Bool = false
    @Published var currentSyncFolder: SyncFolder?
    @Published var lastSyncDate: Date?
    @Published var syncProgress: String = ""
    @Published var syncProgressPercent: Double? = nil  // 0.0 to 1.0
    @Published private(set) var syncCancelled: Bool = false
    
    // MARK: - Computed Properties
    
    /// Enabled folders only (for UI display)
    var enabledFolders: [SyncFolder] {
        folders.filter { $0.isEnabled }
    }
    
    var statusIcon: String {
        if !isRcloneInstalled {
            return "exclamationmark.icloud"
        } else if isSyncing {
            return "arrow.triangle.2.circlepath.icloud"
        } else if enabledFolders.contains(where: { $0.lastSyncStatus == .error }) {
            return "xmark.icloud"
        } else {
            return "checkmark.icloud"
        }
    }
    
    var statusText: String {
        if !isRcloneInstalled {
            return "rclone not installed"
        } else if isSyncing {
            if let folder = currentSyncFolder {
                return "Syncing \(folder.displayName)..."
            }
            return "Syncing..."
        } else {
            let errorCount = enabledFolders.filter { $0.lastSyncStatus == .error }.count
            if errorCount > 0 {
                return "\(errorCount) folder\(errorCount == 1 ? "" : "s") failed to sync"
            } else if let lastSync = lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Last sync: \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
            } else {
                return "Ready"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var rclone: RcloneWrapper!
    private var syncTimer: Timer?
    private let userDefaultsKey = "GoogleDriveSync.Folders"
    private let settingsKey = "GoogleDriveSync.Settings"
    
    // MARK: - Initialization
    
    init() {
        // Load settings first
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            // Auto-detect rclone path
            let detectedPath = AppSettings.detectRclonePath() ?? AppSettings.defaultRclonePath
            self.settings = AppSettings(rclonePath: detectedPath)
        }
        
        // Now initialize rclone with settings
        self.rclone = RcloneWrapper(rclonePath: self.settings.rclonePath)
        
        // Load folders
        loadFolders()
        
        // Initial setup
        Task {
            await checkRcloneInstallation()
            await refreshRemotes()
            scheduleSync()
            
            if settings.syncOnLaunch && !folders.isEmpty {
                await syncAll()
            }
            
            if settings.checkUpdatesAutomatically {
                performAutomaticUpdateCheck()
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadFolders() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedFolders = try? JSONDecoder().decode([SyncFolder].self, from: data) {
            self.folders = savedFolders
        }
    }
    
    func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
        
        // Update rclone wrapper with new path
        rclone = RcloneWrapper(rclonePath: settings.rclonePath)
        
        // Update launch at login
        updateLaunchAtLogin()
        
        // Restart timer with new interval
        scheduleSync()
    }
    
    // MARK: - rclone Management
    
    func checkRcloneInstallation() async {
        isRcloneInstalled = await rclone.isInstalled()
        if isRcloneInstalled {
            do {
                rcloneVersion = try await rclone.version()
            } catch {
                rcloneVersion = "Unknown"
            }
        }
    }
    
    func refreshRemotes() async {
        guard isRcloneInstalled else { return }
        
        do {
            availableRemotes = try await rclone.listRemotes()
        } catch {
            print("Failed to list remotes: \(error)")
        }
    }
    
    func openRcloneConfig() async {
        do {
            try await rclone.openInteractiveConfig()
            // Refresh remotes after a delay to allow user to complete config
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await refreshRemotes()
        } catch {
            print("Failed to open config: \(error)")
        }
    }
    
    func addNewDriveRemote(name: String) async {
        do {
            try await rclone.configureNewDrive(name: name)
            // Refresh after delay
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await refreshRemotes()
        } catch {
            print("Failed to add remote: \(error)")
        }
    }
    
    /// Quick one-click setup for Google Drive - creates with temp name, returns the name for renaming
    @discardableResult
    func quickSetupGoogleDrive() async -> String? {
        // Generate a unique temp name
        let baseName = "_TempGDrive"
        var name = baseName
        var counter = 1
        
        let existingNames = Set(availableRemotes.map { $0.name })
        while existingNames.contains(name) {
            counter += 1
            name = "\(baseName)\(counter)"
        }
        
        do {
            try await rclone.configureNewDrive(name: name)
            // Wait a bit then refresh - user needs time to complete OAuth
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await refreshRemotes()
            return name
        } catch {
            print("Failed to setup Google Drive: \(error)")
            return nil
        }
    }
    
    /// Rename a remote to a user-friendly name
    func renameRemote(from oldName: String, to newName: String) async -> Bool {
        do {
            try await rclone.renameRemote(from: oldName, to: newName)
            await refreshRemotes()
            
            // Update any existing folders that use this remote
            for index in folders.indices where folders[index].remoteName == oldName {
                folders[index].remoteName = newName
            }
            saveFolders()
            
            return true
        } catch {
            print("Failed to rename remote: \(error)")
            return false
        }
    }
    
    /// Delete a remote
    func deleteRemote(name: String) async {
        do {
            try await rclone.deleteRemote(name: name)
            await refreshRemotes()
            
            // Remove any folders that use this remote
            folders.removeAll { $0.remoteName == name }
            saveFolders()
        } catch {
            print("Failed to delete remote: \(error)")
        }
    }
    
    /// Reset all app data and settings
    func resetAllSettings() {
        // Clear properties
        folders.removeAll()
        availableRemotes.removeAll()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: settingsKey)
        
        // Re-initialize settings to defaults
        let detectedPath = AppSettings.detectRclonePath() ?? AppSettings.defaultRclonePath
        self.settings = AppSettings(rclonePath: detectedPath)
        
        // Update rclone wrapper
        self.rclone = RcloneWrapper(rclonePath: self.settings.rclonePath)
        
        // Save initial state
        saveSettings()
        saveFolders()
        
        // Refresh remotes
        Task {
            await checkRcloneInstallation()
            await refreshRemotes()
        }
    }
    
    // MARK: - Folder Management
    
    func addFolder(localPath: String, remoteName: String, remotePath: String = "") {
        let folder = SyncFolder(
            localPath: localPath,
            remoteName: remoteName,
            remotePath: remotePath
        )
        folders.append(folder)
        saveFolders()
    }
    
    func removeFolder(_ folder: SyncFolder) {
        folders.removeAll { $0.id == folder.id }
        saveFolders()
    }
    
    func updateFolder(_ folder: SyncFolder) {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
            saveFolders()
        }
    }
    
    /// Open the folder in Google Drive web interface
    func openFolderInGoogleDrive(_ folder: SyncFolder) async {
        // Get the folder ID from rclone
        if let folderID = await rclone.getFolderID(remote: folder.remoteName, path: folder.remotePath) {
            var urlString: String
            if folderID == "root" {
                // For root folder, open "My Drive" with authuser to select correct account
                urlString = "https://drive.google.com/drive/my-drive"
            } else {
                // For specific folder, open by ID
                urlString = "https://drive.google.com/drive/folders/\(folderID)"
            }
            
            // Add authuser parameter with email to force correct Google account
            if let encodedEmail = folder.remoteName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?authuser=\(encodedEmail)"
            }
            
            if let url = URL(string: urlString) {
                await MainActor.run {
                    _ = NSWorkspace.shared.open(url)
                }
            }
        } else {
            // Fallback to just opening Google Drive
            if let url = URL(string: "https://drive.google.com") {
                await MainActor.run {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func syncAll() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        for index in folders.indices where folders[index].isEnabled {
            currentSyncFolder = folders[index]
            folders[index].lastSyncStatus = .syncing
            
            // Check if cancelled before starting this folder
            if syncCancelled {
                folders[index].lastSyncStatus = .idle
                break
            }
            
            do {
                let result = try await rclone.sync(
                    source: folders[index].localPath,
                    destination: folders[index].fullRemotePath
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.syncProgress = self?.simplifyProgress(progress) ?? progress
                        // Parse percentage from rclone output (e.g., "Transferred: 5 / 10, 50%")
                        self?.syncProgressPercent = self?.parseProgressPercent(from: progress)
                    }
                }
                
                folders[index].lastSyncDate = Date()
                folders[index].lastSyncStatus = result.success ? .success : .error
                folders[index].lastError = nil
                
            } catch {
                folders[index].lastSyncStatus = .error
                folders[index].lastError = error.localizedDescription
            }
        }
        
        currentSyncFolder = nil
        syncProgress = ""
        syncProgressPercent = nil
        syncCancelled = false
        isSyncing = false
        lastSyncDate = Date()
        
        saveFolders()
        
        if !syncCancelled {
            await sendSyncNotification(folders)
        }
    }
    
    /// Cancel the current sync operation
    func cancelSync() {
        guard isSyncing else { return }
        syncCancelled = true
        syncProgress = "Cancelling..."
        
        // Terminate the rclone process immediately
        Task {
            await rclone.cancelCurrentOperation()
        }
    }
    
    func syncFolder(_ folder: SyncFolder) async {
        guard !isSyncing else { return }
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        
        isSyncing = true
        currentSyncFolder = folder
        folders[index].lastSyncStatus = .syncing
        
        // Resolve the actual local path (handling Volume-1 issues)
        let resolvedPath = resolveLocalPath(folder.localPath)
        
        do {
            let result = try await rclone.sync(
                source: resolvedPath,
                destination: folder.fullRemotePath
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.syncProgress = self?.simplifyProgress(progress) ?? progress
                    self?.syncProgressPercent = self?.parseProgressPercent(from: progress)
                }
            }
            
            folders[index].lastSyncDate = Date()
            folders[index].lastSyncStatus = result.success ? .success : .error
            folders[index].lastError = nil
            
        } catch {
            folders[index].lastSyncStatus = .error
            folders[index].lastError = error.localizedDescription
        }
        
        currentSyncFolder = nil
        syncProgress = ""
        syncProgressPercent = nil
        isSyncing = false
        
        saveFolders()
    }
    
    /// Resolve correct path for Volumes that might have a suffix (e.g. /Volumes/Name-1)
    private func resolveLocalPath(_ path: String) -> String {
        // If path exists as is, use it
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
        
        // Only try to be smart about /Volumes paths
        guard path.hasPrefix("/Volumes/") else { return path }
        
        // Example: /Volumes/Media/Backup -> components: ["", "Volumes", "Media", "Backup"]
        let components = path.components(separatedBy: "/")
        guard components.count >= 3 else { return path }
        
        let volumeName = components[2] // "Media"
        let relativePath = components.dropFirst(3).joined(separator: "/") // "Backup"
        
        // Check /Volumes for variants
        do {
            let volumes = try FileManager.default.contentsOfDirectory(atPath: "/Volumes")
            
            // Look for volume starting with original name (e.g. "Media" matches "Media-1")
            for candidate in volumes {
                if candidate.hasPrefix(volumeName) {
                    let newVolumePath = "/Volumes/\(candidate)"
                    let fullNewPath = relativePath.isEmpty ? newVolumePath : "\(newVolumePath)/\(relativePath)"
                    
                    if FileManager.default.fileExists(atPath: fullNewPath) {
                        print("Smart Resolve: Remapped \(path) -> \(fullNewPath)")
                        return fullNewPath
                    }
                }
            }
        } catch {
            print("Error listing /Volumes: \(error)")
        }
        
        return path
    }
    
    /// Parse percentage from rclone progress output
    private func parseProgressPercent(from output: String) -> Double? {
        // rclone outputs progress like: "Transferred: 5 / 10, 50%" or just "50%"
        let pattern = #"(\d+)%"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let range = Range(match.range(at: 1), in: output),
           let percent = Double(output[range]) {
            return percent / 100.0
        }
        return nil
    }
    
    /// Simplify rclone progress output to just show transferred/total and ETA
    /// Input: "5.459 MiB / 6.622 MiB, 82%, ... 63 KiB/s, ETA 2s (xfr#20/29)"
    /// Output: "5.5 / 6.6 MiB • ETA 2s"
    private func simplifyProgress(_ progress: String) -> String {
        var transferred = ""
        var total = ""
        var unit = ""
        var eta = ""
        
        // Extract transferred/total bytes (e.g., "5.459 MiB / 6.622 MiB")
        let bytesPattern = #"([\d.]+)\s*([\w]+)\s*/\s*([\d.]+)\s*([\w]+)"#
        if let regex = try? NSRegularExpression(pattern: bytesPattern),
           let match = regex.firstMatch(in: progress, range: NSRange(progress.startIndex..., in: progress)) {
            if let range1 = Range(match.range(at: 1), in: progress),
               let range3 = Range(match.range(at: 3), in: progress),
               let range4 = Range(match.range(at: 4), in: progress) {
                let t = Double(progress[range1]) ?? 0
                let tot = Double(progress[range3]) ?? 0
                transferred = String(format: "%.1f", t)
                total = String(format: "%.1f", tot)
                unit = String(progress[range4])
            }
        }
        
        // Extract ETA (e.g., "ETA 2s" or "ETA 1m30s")
        let etaPattern = #"ETA\s+([\w\d]+)"#
        if let regex = try? NSRegularExpression(pattern: etaPattern),
           let match = regex.firstMatch(in: progress, range: NSRange(progress.startIndex..., in: progress)),
           let range = Range(match.range(at: 1), in: progress) {
            eta = String(progress[range])
        }
        
        // Build simplified string
        if !transferred.isEmpty && !total.isEmpty {
            var result = "\(transferred) / \(total) \(unit)"
            if !eta.isEmpty && eta != "-" {
                result += " • ETA \(eta)"
            }
            return result
        }
        
        return progress
    }
    
    // MARK: - Timer
    
    private func scheduleSync() {
        syncTimer?.invalidate()
        
        // For daily sync, schedule at specific time
        if case .daily = settings.syncInterval {
            scheduleDailySync()
            return
        }
        
        // For other intervals, use fixed interval timer
        guard let interval = settings.syncInterval.intervalSeconds else { return }
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAll()
            }
        }
    }
    
    /// Schedule a sync at the user's preferred daily sync time
    private func scheduleDailySync() {
        let calendar = Calendar.current
        let syncTimeComponents = calendar.dateComponents([.hour, .minute], from: settings.dailySyncTime)
        
        // Calculate next occurrence of this time
        var nextSyncDate: Date
        
        // Get today at the sync time
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        todayComponents.hour = syncTimeComponents.hour
        todayComponents.minute = syncTimeComponents.minute
        todayComponents.second = 0
        
        if let todayAtSyncTime = calendar.date(from: todayComponents) {
            if todayAtSyncTime > Date() {
                // Sync time is still coming today
                nextSyncDate = todayAtSyncTime
            } else {
                // Sync time already passed, schedule for tomorrow
                nextSyncDate = calendar.date(byAdding: .day, value: 1, to: todayAtSyncTime) ?? todayAtSyncTime
            }
        } else {
            // Fallback: schedule for 24 hours from now
            nextSyncDate = Date().addingTimeInterval(24 * 60 * 60)
        }
        
        let timeUntilSync = nextSyncDate.timeIntervalSince(Date())
        
        // Schedule one-shot timer, then reschedule after sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: timeUntilSync, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.syncAll()
                // Reschedule for the next day
                self?.scheduleDailySync()
            }
        }
    }
    
    // MARK: - Notifications
    
    private func sendSyncNotification(_ folders: [SyncFolder]) async {
        let errorCount = folders.filter { $0.lastSyncStatus == .error }.count
        let hasErrors = errorCount > 0
        
        // Check settings - if neither is enabled, return early
        if !settings.showNotifications && !(hasErrors && settings.notifyOnError) {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        if hasErrors {
            content.title = "Sync Failed"
            content.body = "\(errorCount) folder(s) encountered errors"
            content.categoryIdentifier = "SYNC_ERROR"
            
            // Mark as time sensitive for errors
            if #available(macOS 12.0, *) {
                content.interruptionLevel = .timeSensitive
            }
        } else {
            // Success case - only proceed if showNotifications is true
            guard settings.showNotifications else { return }
            
            content.title = "Sync Complete"
            content.body = "\(folders.count) folder(s) synced successfully"
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            print("Notification permission: \(granted)")
        }
    }
    
    // MARK: - Launch at Login
    
    private func updateLaunchAtLogin() {
        do {
            if settings.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    // MARK: - Updates
    
    private func performAutomaticUpdateCheck() {
        Task {
            do {
                let (isAvailable, latestVersion, _) = try await checkForUpdates()
                if isAvailable {
                    await sendUpdateNotification(version: latestVersion)
                }
            } catch {
                print("Failed to check for updates: \(error)")
            }
        }
    }
    
    private func sendUpdateNotification(version: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Update Available"
        content.body = "Version \(version) is available on GitHub."
        content.sound = .default
        
        // Use a fixed identifier to avoid spamming the user if they don't update
        let request = UNNotificationRequest(
            identifier: "UPDATE_AVAILABLE",
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    /// Check for updates via GitHub API
    /// Returns: (isUpdateAvailable, latestVersion, releaseURL)
    func checkForUpdates() async throws -> (Bool, String, URL?) {
        let url = URL(string: "https://api.github.com/repos/saihgupr/GoogleDriveSync/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        
        let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        
        let isUpdateAvailable = compareVersions(latest: latestVersion, current: currentVersion)
        
        return (isUpdateAvailable, release.tagName, URL(string: release.htmlUrl))
    }
    
    private func compareVersions(latest: String, current: String) -> Bool {
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(latestComponents.count, currentComponents.count)
        
        for i in 0..<maxCount {
            let v1 = i < latestComponents.count ? latestComponents[i] : 0
            let v2 = i < currentComponents.count ? currentComponents[i] : 0
            
            if v1 > v2 { return true }
            if v1 < v2 { return false }
        }
        
        return false
    }
}
