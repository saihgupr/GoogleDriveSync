//
//  AppSettings.swift
//  GoogleDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import Foundation

enum SyncInterval: Codable, Equatable, Hashable, CaseIterable {
    case manual
    case minutes15
    case minutes30
    case hourly
    case daily
    case custom(minutes: Int)
    
    static var allCases: [SyncInterval] {
        [.manual, .minutes15, .minutes30, .hourly, .daily]
    }
    
    var displayName: String {
        switch self {
        case .manual: return "Manual Only"
        case .minutes15: return "Every 15 minutes"
        case .minutes30: return "Every 30 minutes"
        case .hourly: return "Every Hour"
        case .daily: return "Once a Day"
        case .custom(let minutes): return "Every \(minutes) minutes"
        }
    }
    
    var intervalSeconds: TimeInterval? {
        switch self {
        case .manual: return nil
        case .minutes15: return 15 * 60
        case .minutes30: return 30 * 60
        case .hourly: return 60 * 60
        case .daily: return 24 * 60 * 60
        case .custom(let minutes): return TimeInterval(minutes * 60)
        }
    }
}

struct AppSettings: Codable, Equatable {
    var syncInterval: SyncInterval
    var rclonePath: String
    var showNotifications: Bool
    var notifyOnError: Bool
    var launchAtLogin: Bool
    var syncOnLaunch: Bool
    var dailySyncTime: Date  // Time of day for daily syncs (only hour/minute matter)
    
    static let defaultRclonePath = "/opt/homebrew/bin/rclone"
    static let intelRclonePath = "/usr/local/bin/rclone"
    
    /// Default sync time: 9:00 AM
    static var defaultDailySyncTime: Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
    
    init(
        syncInterval: SyncInterval = .hourly,
        rclonePath: String = AppSettings.defaultRclonePath,
        showNotifications: Bool = true,
        notifyOnError: Bool = true,
        launchAtLogin: Bool = false,
        syncOnLaunch: Bool = true,
        dailySyncTime: Date? = nil
    ) {
        self.syncInterval = syncInterval
        self.rclonePath = rclonePath
        self.showNotifications = showNotifications
        self.notifyOnError = notifyOnError
        self.launchAtLogin = launchAtLogin
        self.syncOnLaunch = syncOnLaunch
        self.dailySyncTime = dailySyncTime ?? AppSettings.defaultDailySyncTime
    }
    
    static func detectRclonePath() -> String? {
        // Check common locations
        let paths = [
            defaultRclonePath,      // Apple Silicon Homebrew
            intelRclonePath,        // Intel Homebrew
            "/usr/bin/rclone",      // System
            "/opt/local/bin/rclone" // MacPorts
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try which command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["rclone"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            // Ignore
        }
        
        return nil
    }
}
