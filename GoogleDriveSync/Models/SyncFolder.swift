//
//  SyncFolder.swift
//  DriveSync
//
//  Created by saihgupr on 2024-12-11.
//  Edited by MichasCoup on 2026-07-26.
//

import Foundation

enum BisyncState: String, Codable {
    case uninitialized
    case ready
    case needsResync
}

enum SyncStatus: String, Codable {
    case idle
    case syncing
    case success
    case error
}

struct SyncFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var localPath: String
    var remoteName: String      // e.g., "gdrive"
    var remotePath: String      // e.g., "Backups/YAML"
    var lastSyncDate: Date?
    var lastSyncStatus: SyncStatus
    var isEnabled: Bool
    var lastError: String?
    var ignoredPatterns: [String]
    var bisyncState: BisyncState
    
    init(
        id: UUID = UUID(),
        localPath: String,
        remoteName: String,
        remotePath: String = "",
        lastSyncDate: Date? = nil,
        lastSyncStatus: SyncStatus = .idle,
        isEnabled: Bool = true,
        lastError: String? = nil,
        ignoredPatterns: [String] = []
    ) {
        self.id = id
        self.localPath = localPath
        self.remoteName = remoteName
        self.remotePath = remotePath
        self.lastSyncDate = lastSyncDate
        self.lastSyncStatus = lastSyncStatus
        self.isEnabled = isEnabled
        self.lastError = lastError
        self.ignoredPatterns = ignoredPatterns
        self.bisyncState = .uninitialized
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case localPath
        case remoteName
        case remotePath
        case lastSyncDate
        case lastSyncStatus
        case isEnabled
        case lastError
        case ignoredPatterns
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.localPath = try container.decode(String.self, forKey: .localPath)
        self.remoteName = try container.decode(String.self, forKey: .remoteName)
        self.remotePath = try container.decodeIfPresent(String.self, forKey: .remotePath) ?? ""
        self.lastSyncDate = try container.decodeIfPresent(Date.self, forKey: .lastSyncDate)
        self.lastSyncStatus = try container.decodeIfPresent(SyncStatus.self, forKey: .lastSyncStatus) ?? .idle
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        self.lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        self.ignoredPatterns = try container.decodeIfPresent([String].self, forKey: .ignoredPatterns) ?? []
        self.bisyncState = .uninitialized
    }
    
    var displayName: String {
        URL(fileURLWithPath: localPath).lastPathComponent
    }
    
    var fullRemotePath: String {
        if remotePath.isEmpty {
            return "\(remoteName):"
        }
        return "\(remoteName):\(remotePath)"
    }
}
