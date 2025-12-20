//
//  SettingsView.swift
//  GoogleDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    
    var body: some View {
        TabView {
            FoldersSettingsView()
                .tabItem {
                    Label("Folders", systemImage: "folder")
                }
                .environmentObject(syncManager)
            
            AccountsSettingsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.crop.circle")
                }
                .environmentObject(syncManager)
            
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .environmentObject(syncManager)
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
                .environmentObject(syncManager)
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Folders Tab

struct FoldersSettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    @State private var showingAddSheet = false
    @State private var showingAddAccountSheet = false
    @State private var selectedFolder: SyncFolder?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Toolbar
            HStack {
                Text("Sync Folders")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(syncManager.availableRemotes.isEmpty)
                .help(syncManager.availableRemotes.isEmpty ? "Add a Google Drive account first" : "Add folder")
            }
            
            if syncManager.folders.isEmpty {
                if syncManager.availableRemotes.isEmpty {
                    // No accounts configured yet - show big connect button
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Connect to Google Drive")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Sign in with your Google account to start syncing folders.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            showingAddAccountSheet = true
                        } label: {
                            Label("Connect Google Drive", systemImage: "link")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Text("This will open your browser to sign in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Has accounts, no folders
                    ContentUnavailableView {
                        Label("No Folders", systemImage: "folder")
                    } description: {
                        Text("Add a folder to start syncing to Google Drive")
                    } actions: {
                        Button("Add Folder") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxHeight: .infinity)
                }
            } else {
                List(syncManager.folders) { folder in
                    FolderSettingsRow(folder: folder, onEdit: {
                        selectedFolder = folder
                    })
                }
                .listStyle(.inset)
            }
        }
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            AddFolderSheet()
                .environmentObject(syncManager)
        }
        .sheet(isPresented: $showingAddAccountSheet) {
            AddAccountSheet()
                .environmentObject(syncManager)
        }
        .sheet(item: $selectedFolder) { folder in
            EditFolderSheet(folder: folder)
                .environmentObject(syncManager)
        }
    }
}

struct FolderSettingsRow: View {
    let folder: SyncFolder
    let onEdit: () -> Void
    @EnvironmentObject var syncManager: SyncManager
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Folder info (takes available space)
            VStack(alignment: .leading, spacing: 3) {
                Text(folder.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                
                Text(folder.localPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(folder.fullRemotePath)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer(minLength: 8)
            
            // Controls (fixed width)
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { folder.isEnabled },
                    set: { newValue in
                        var updated = folder
                        updated.isEnabled = newValue
                        syncManager.updateFolder(updated)
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                
                Button {
                    syncManager.removeFolder(folder)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Add Folder Sheet

struct AddFolderSheet: View {
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var localPath: String = ""
    @State private var selectedRemote: RcloneRemote?
    @State private var remotePath: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Sync Folder")
                .font(.headline)
            
            Form {
                Section {
                    HStack {
                        TextField("Local Folder", text: $localPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectFolder()
                        }
                    }
                }
                
                Section {
                    Picker("Google Drive Account", selection: $selectedRemote) {
                        Text("Select...").tag(nil as RcloneRemote?)
                        ForEach(syncManager.availableRemotes) { remote in
                            Text(remote.displayName).tag(remote as RcloneRemote?)
                        }
                    }
                    
                    TextField("Remote Path (optional)", text: $remotePath)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("e.g., Backups/YAML - leave empty for root")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add") {
                    if let remote = selectedRemote {
                        syncManager.addFolder(
                            localPath: localPath,
                            remoteName: remote.name,
                            remotePath: remotePath
                        )
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(localPath.isEmpty || selectedRemote == nil)
            }
        }
        .padding()
        .frame(width: 450, height: 300)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }
}

// MARK: - Edit Folder Sheet

struct EditFolderSheet: View {
    let folder: SyncFolder
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var localPath: String = ""
    @State private var selectedRemote: RcloneRemote?
    @State private var remotePath: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Sync Folder")
                .font(.headline)
            
            Form {
                Section {
                    HStack {
                        TextField("Local Folder", text: $localPath)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Browse...") {
                            selectFolder()
                        }
                    }
                }
                
                Section {
                    Picker("Google Drive Account", selection: $selectedRemote) {
                        Text("Select...").tag(nil as RcloneRemote?)
                        ForEach(syncManager.availableRemotes) { remote in
                            Text(remote.displayName).tag(remote as RcloneRemote?)
                        }
                    }
                    
                    TextField("Remote Path", text: $remotePath)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    if let remote = selectedRemote {
                        var updated = folder
                        updated.localPath = localPath
                        updated.remoteName = remote.name
                        updated.remotePath = remotePath
                        syncManager.updateFolder(updated)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(localPath.isEmpty || selectedRemote == nil)
            }
        }
        .padding()
        .frame(width: 450, height: 300)
        .onAppear {
            localPath = folder.localPath
            remotePath = folder.remotePath
            selectedRemote = syncManager.availableRemotes.first { $0.name == folder.remoteName }
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }
}

// MARK: - Add Account Sheet

struct AddAccountSheet: View {
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.dismiss) private var dismiss
    
    enum SetupStep {
        case connecting
        case naming
    }
    
    @State private var step: SetupStep = .connecting
    @State private var tempRemoteName: String = ""
    @State private var accountName: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            switch step {
            case .connecting:
                connectingView
            case .naming:
                namingView
            }
        }
        .padding(30)
        .frame(width: 380)
        .onAppear {
            startConnection()
        }
    }
    
    private var connectingView: some View {
        VStack(spacing: 16) {
            Text("Connecting to Google Drive...")
                .font(.headline)
            
            ProgressView()
                .controlSize(.regular)
            
            Text("Complete the sign-in in your browser, then return here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Cancel") {
                dismiss()
            }
            .padding(.top, 8)
        }
    }
    
    private var namingView: some View {
        VStack(spacing: 16) {
            Text("Account Connected!")
                .font(.headline)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Give this account a name:")
                    .font(.subheadline)
                
                TextField("e.g., Work, Personal, john@gmail.com", text: $accountName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                
                Text("This helps you identify which Google account this is.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack(spacing: 16) {
                Button("Skip") {
                    dismiss()
                }
                
                Button {
                    finishWithName()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(accountName.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    private func startConnection() {
        Task {
            if let tempName = await syncManager.quickSetupGoogleDrive() {
                tempRemoteName = tempName
                
                // Poll for the remote to appear (user completing OAuth)
                for _ in 0..<60 { // Wait up to 60 seconds
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await syncManager.refreshRemotes()
                    
                    if syncManager.availableRemotes.contains(where: { $0.name == tempName }) {
                        step = .naming
                        return
                    }
                }
            }
            // If we get here, something went wrong
            dismiss()
        }
    }
    
    private func finishWithName() {
        let newName = sanitizedName
        guard !newName.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            let success = await syncManager.renameRemote(from: tempRemoteName, to: newName)
            
            if success {
                dismiss()
            } else {
                errorMessage = "Failed to rename. The account is still connected as '\(tempRemoteName)'."
                isProcessing = false
            }
        }
    }
    
    private var sanitizedName: String {
        let trimmed = accountName.trimmingCharacters(in: .whitespaces)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_@.-"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
            .replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - Accounts Tab

struct AccountsSettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    @State private var showingAddAccountSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Google Drive Accounts")
                .font(.headline)
            
            if syncManager.availableRemotes.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                    
                    Text("No accounts connected")
                        .font(.title3)
                    
                    Button {
                        showingAddAccountSheet = true
                    } label: {
                        Label("Connect Google Drive", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(syncManager.availableRemotes) { remote in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading) {
                            Text(remote.name)
                                .font(.body)
                            Text("Google Drive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button {
                            accountToRename = remote
                            showingRenameSheet = true
                        } label: {
                            Label("Rename...", systemImage: "pencil")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            Task {
                                await syncManager.deleteRemote(name: remote.name)
                            }
                        } label: {
                            Label("Remove Account", systemImage: "trash")
                        }
                    }
                }
                .listStyle(.inset)
                
                Divider()
                
                HStack {
                    Button {
                        showingAddAccountSheet = true
                    } label: {
                        Label("Add Another Account", systemImage: "plus")
                    }
                    
                    Spacer()
                    
                    Button("Refresh") {
                        Task {
                            await syncManager.refreshRemotes()
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAddAccountSheet) {
            AddAccountSheet()
                .environmentObject(syncManager)
        }
        .sheet(isPresented: $showingRenameSheet) {
            if let remote = accountToRename {
                RenameAccountSheet(currentName: remote.name)
                    .environmentObject(syncManager)
            }
        }
        .onAppear {
            Task {
                await syncManager.refreshRemotes()
            }
        }
    }
    
    @State private var showingRenameSheet = false
    @State private var accountToRename: RcloneRemote?
}

// MARK: - Rename Account Sheet

struct RenameAccountSheet: View {
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.dismiss) private var dismiss
    
    let currentName: String
    @State private var newName: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Account")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current name: \(currentName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextField("New name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button {
                    renameAccount()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal)
                    } else {
                        Text("Rename")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(sanitizedName.isEmpty || sanitizedName == currentName || isProcessing)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 350)
        .onAppear {
            newName = currentName
        }
    }
    
    private func renameAccount() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            let success = await syncManager.renameRemote(from: currentName, to: sanitizedName)
            
            if success {
                dismiss()
            } else {
                errorMessage = "Failed to rename account"
                isProcessing = false
            }
        }
    }
    
    private var sanitizedName: String {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_@.-"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
            .replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    
    var body: some View {
        Form {
            Section {
                Picker("Sync Interval", selection: $syncManager.settings.syncInterval) {
                    ForEach(SyncInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                
                // Show time picker only when "Once a Day" is selected
                if case .daily = syncManager.settings.syncInterval {
                    DatePicker(
                        "Sync Time",
                        selection: $syncManager.settings.dailySyncTime,
                        displayedComponents: .hourAndMinute
                    )
                    
                    Text("Next sync: \(nextSyncDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Toggle("Sync when app launches", isOn: $syncManager.settings.syncOnLaunch)
            } header: {
                Text("Sync Schedule")
            }
            
            Section {
                Toggle("Show notifications after sync", isOn: $syncManager.settings.showNotifications)
                
                Toggle("Notify on Error", isOn: $syncManager.settings.notifyOnError)
                
                Toggle("Launch at login", isOn: $syncManager.settings.launchAtLogin)
            } header: {
                Text("App Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: syncManager.settings) { _, _ in
            syncManager.saveSettings()
        }
    }
    
    /// Calculate when the next daily sync will occur
    private var nextSyncDescription: String {
        let calendar = Calendar.current
        let syncTimeComponents = calendar.dateComponents([.hour, .minute], from: syncManager.settings.dailySyncTime)
        
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        todayComponents.hour = syncTimeComponents.hour
        todayComponents.minute = syncTimeComponents.minute
        
        guard let todayAtSyncTime = calendar.date(from: todayComponents) else {
            return "Unknown"
        }
        
        let nextSync: Date
        if todayAtSyncTime > Date() {
            nextSync = todayAtSyncTime
        } else {
            nextSync = calendar.date(byAdding: .day, value: 1, to: todayAtSyncTime) ?? todayAtSyncTime
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: nextSync)
    }
}

// MARK: - Advanced Tab

struct AdvancedSettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    
    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("rclone Path", text: $syncManager.settings.rclonePath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Detect") {
                        if let path = AppSettings.detectRclonePath() {
                            syncManager.settings.rclonePath = path
                        }
                    }
                }
                
                if syncManager.isRcloneInstalled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("rclone found: \(syncManager.rcloneVersion)")
                            .font(.caption)
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("rclone not found at this path")
                            .font(.caption)
                    }
                }
            } header: {
                Text("rclone Configuration")
            }
            
            Section {
                Button("Check for Updates") {
                    Task {
                        await syncManager.checkRcloneInstallation()
                        await syncManager.refreshRemotes()
                    }
                }
                
                Button("Reset All Settings", role: .destructive) {
                    // TODO: Add confirmation
                    UserDefaults.standard.removeObject(forKey: "GoogleDriveSync.Folders")
                    UserDefaults.standard.removeObject(forKey: "GoogleDriveSync.Settings")
                }
            } header: {
                Text("Maintenance")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: syncManager.settings.rclonePath) { _, _ in
            syncManager.saveSettings()
            Task {
                await syncManager.checkRcloneInstallation()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SyncManager())
}
