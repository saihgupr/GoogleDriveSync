//
//  SyncFolderValidator.swift
//  GoogleDriveSync
//
//  Input validation for sync folders and remote names (security hardening).
//

import Foundation

enum SyncFolderValidator {
    static let maxPathLength = 1024
    
    /// Allowed character set for rclone remote names (matches RenameAccountSheet sanitization).
    private static let allowedRemoteNameCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "_@.-"))
    
    /// Validate local path: exists, under home or /Volumes, length limit.
    static func validateLocalPath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= maxPathLength else { return false }
        guard FileManager.default.fileExists(atPath: trimmed) else { return false }
        let resolved = (trimmed as NSString).standardizingPath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return resolved.hasPrefix(home) || resolved.hasPrefix("/Volumes/")
    }
    
    /// Validate remote path: no .., no control characters, length limit.
    static func validateRemotePath(_ path: String) -> Bool {
        guard path.count <= maxPathLength else { return false }
        if path.contains("..") { return false }
        let allowed = CharacterSet.urlPathAllowed.union(CharacterSet(charactersIn: "/ "))
        return path.unicodeScalars.allSatisfy { allowed.contains($0) && !CharacterSet.controlCharacters.contains($0) }
    }
    
    /// Validate remote name: alphanumerics plus _ @ . -
    static func validateRemoteName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 256 else { return false }
        return trimmed.unicodeScalars.allSatisfy { allowedRemoteNameCharacters.contains($0) }
    }
}
