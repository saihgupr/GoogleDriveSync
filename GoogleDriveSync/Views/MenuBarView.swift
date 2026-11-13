//
//  MenuBarView.swift
//  DriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.openSettings) private var openSettings
    @State private var expandedErrorID: UUID? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status
            headerSection
            
            // Error details (when present)
            errorBanner
            
            // Progress (only shows when syncing)
            progressSection
            
            Divider()
                .padding(.vertical, 8)
            
            if !syncManager.isRcloneInstalled {
                rcloneNotInstalledSection
            } else {
                // Folders list (only show enabled folders)
                let enabledFolders = syncManager.folders.filter { $0.isEnabled }
                if enabledFolders.isEmpty {
                    emptyFoldersSection
                } else {
                    foldersSection
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Actions
                actionsSection
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Footer
            footerSection
        }
        .padding(12)
        .frame(width: 320)
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("GoogleDriveSync")
                    .font(.system(size: 13, weight: .semibold))
                
                Text(syncManager.statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: syncManager.statusIcon)
                .font(.system(size: 18))
                .foregroundStyle(statusColor)
        }
    }
    
    private var progressSection: some View {
        Group {
            if syncManager.isSyncing {
                VStack(alignment: .leading, spacing: 6) {
                    // Progress bar with cancel button
                    HStack(spacing: 8) {
                        if let percent = syncManager.syncProgressPercent {
                            ProgressView(value: percent)
                                .progressViewStyle(.linear)
                        } else {
                            ProgressView()
                                .progressViewStyle(.linear)
                        }
                        
                        Button {
                            syncManager.cancelSync()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                        .help("Cancel sync")
                    }
                    
                    // Progress details
                    HStack {
                        if let percent = syncManager.syncProgressPercent {
                            Text("\(Int(percent * 100))%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        if !syncManager.syncProgress.isEmpty && !syncManager.syncProgress.contains("0.0 / 0.0") {
                            Text(syncManager.syncProgress)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var errorBanner: some View {
        let reconnectRemotes = syncManager.accountsNeedingReconnect.sorted()
        let foldersWithErrors = syncManager.folders.filter { folder in
            guard folder.isEnabled, folder.lastSyncStatus == .error else { return false }
            
            let isAuthFailure = RcloneError.isAuthorizationMessage(folder.lastError ?? "")
            return !(isAuthFailure && syncManager.accountsNeedingReconnect.contains(folder.remoteName))
        }
        
        return VStack(alignment: .leading, spacing: 6) {
            if !reconnectRemotes.isEmpty {
                reconnectCard(reconnectRemotes)
            }
            
            if !foldersWithErrors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(foldersWithErrors) { folder in
                        Button {
                            if expandedErrorID == folder.id {
                                expandedErrorID = nil
                            } else {
                                expandedErrorID = folder.id
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.system(size: 12))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.displayName)
                                        .font(.system(size: 11, weight: .medium))
                                    
                                    Text(folder.lastError ?? "Unknown error")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(expandedErrorID == folder.id ? nil : 2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Spacer()
                                
                                Image(systemName: expandedErrorID == folder.id ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .pointingHandCursor()
                    }
                }
                .padding(10)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
                .padding(.top, 8)
            }
        }
    }
    
    private func reconnectCard(_ remotes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Google sign-in expired")
                    .font(.system(size: 11, weight: .semibold))
            } icon: {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12))
            }
            
            Text("Your files are unchanged. Sign in again to resume syncing.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            ForEach(remotes, id: \.self) { remote in
                HStack(spacing: 8) {
                    Text(remote)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer(minLength: 4)
                    
                    Button("Reconnect...") {
                        syncManager.requestReconnect(remote)
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    }
                    .controlSize(.small)
                    .pointingHandCursor()
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 8)
    }
    
    private var statusColor: Color {
        if !syncManager.isRcloneInstalled {
            return .red
        } else if syncManager.isSyncing {
            return .orange
        } else if syncManager.folders.contains(where: { $0.lastSyncStatus == .error }) {
            return .red
        } else {
            return .green
        }
    }
    
    private var rcloneNotInstalledSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("rclone is not installed")
                .font(.subheadline)
                .foregroundStyle(.red)
            
            Text("Install via Homebrew:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("brew install rclone")
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(4)
                
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("brew install rclone", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help("Copy to clipboard")
            }
            
            Button("Check Again") {
                Task {
                    await syncManager.checkRcloneInstallation()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .pointingHandCursor()
        }
        .padding(.vertical, 8)
    }
    
    private var emptyFoldersSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No folders configured")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("Add Folder") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .pointingHandCursor()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    private var foldersSection: some View {
        let enabledFolders = syncManager.folders.filter { $0.isEnabled }
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("Folders")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            
            ForEach(enabledFolders) { folder in
                FolderRowView(folder: folder)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 4) {
            Button {
                Task {
                    await syncManager.syncAll()
                }
            } label: {
                Label("Sync All", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .disabled(syncManager.isSyncing || syncManager.folders.isEmpty)
            
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings...", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
            .keyboardShortcut(",", modifiers: .command)
        }
    }
    
    private var footerSection: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit GoogleDriveSync", systemImage: "power")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Folder Row

struct FolderRowView: View {
    let folder: SyncFolder
    @EnvironmentObject var syncManager: SyncManager
    
    var body: some View {
        HStack {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(folder.remoteName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let lastSync = folder.lastSyncDate {
                Text(lastSync, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            // Dropdown menu
            Menu {
                Button("Sync Now") {
                    Task {
                        await syncManager.syncFolder(folder)
                    }
                }
                .disabled(syncManager.isSyncing)
                
                Divider()
                
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.localPath)
                }
                
                Button("Open in Remote") {
                    Task {
                        await syncManager.openRemoteFolder(folder)
                    }
                }
                
                Divider()
                
                Button("Remove", role: .destructive) {
                    syncManager.removeFolder(folder)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 20)
            .pointingHandCursor()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(6)
    }
    
    private var statusIcon: some View {
        Group {
            switch folder.lastSyncStatus {
            case .idle:
                Image(systemName: "circle")
                    .foregroundStyle(.secondary)
            case .syncing:
                ProgressView()
                    .controlSize(.mini)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .help(folder.lastError ?? "Sync failed")
            }
        }
        .frame(width: 16)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(SyncManager())
}
