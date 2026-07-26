//
//  SettingsView.swift
//  GoogleDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SyncSettingsView()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(0)
            
            AccountsSettingsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.crop.circle")
                }
                .tag(1)
            
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(2)
        }
        .frame(width: 500, height: 450)
        .padding(.bottom, 20)
    }
}

// MARK: - Sync Settings Tab

struct SyncSettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    @State private var showingAddSheet = false
    @State private var showingAddAccountSheet = false
    @State private var selectedFolder: SyncFolder?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                .help("Add a new sync folder")
            }
            
            if syncManager.folders.isEmpty {
                if syncManager.availableRemotes.isEmpty {
                    // No accounts at all
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Welcome to GoogleDriveSync")
                            .font(.title2.bold())
                        
                        Text("Configure a cloud storage provider to start syncing folders.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button {
                            showingAddAccountSheet = true
                        } label: {
                            Label("Connect Account", systemImage: "link")
                                .font(.headline)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Text("This will open a terminal window to configure rclone.")
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
                        Text("Add a folder to start syncing")
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
    
    @State private var showingErrorPopover = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Status Icon
            Button {
                if folder.lastSyncStatus == .error {
                    showingErrorPopover = true
                }
            } label: {
                Group {
                    switch folder.lastSyncStatus {
                    case .idle:
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.tertiary)
                    case .syncing:
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.blue)
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .error:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.system(size: 16))
                .frame(width: 20)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingErrorPopover) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sync Failed")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                    if let error = folder.lastError {
                        ScrollView {
                            Text(error)
                                .font(.caption)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                    } else {
                        Text("Unknown error occurred.")
                            .font(.caption)
                    }
                }
                .padding()
                .frame(width: 300)
            }

            // Folder info (takes available space)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(folder.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Text(folder.syncMode == .bisync ? "Two-way" : "One-way")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(folder.localPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(folder.fullRemotePath.trimmingCharacters(in: CharacterSet(charactersIn: ":")))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
    @State private var ignoredPatternsText: String = ""
    @State private var syncMode: SyncMode = .sync
    
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
                    Picker("Remote Account", selection: $selectedRemote) {
                        Text("Select...").tag(nil as RcloneRemote?)
                        ForEach(syncManager.availableRemotes) { remote in
                            Text(remote.displayName).tag(remote as RcloneRemote?)
                        }
                    }
                    
                    TextField("Destination Folder (optional)", text: $remotePath)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Leave empty to sync to the root.\nOr type a folder path (e.g. 'Backups/MyMac').")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Toggle(
                        "Two-way sync",
                        isOn: Binding(
                            get: {
                                syncMode == .bisync
                            },
                            set: { enabled in
                                syncMode = enabled ? .bisync : .sync
                            }
                        )
                    )

                    Text(
                        syncMode == .bisync
                        ? "Changes on both the local and remote side are synchronized."
                        : "The remote folder is mirrored from the local folder."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                } header: {
                    Text("Sync Mode")
                }

                Section {
                    TextEditor(text: $ignoredPatternsText)
                        .frame(height: 80)
                        .font(.system(.body, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    Text("Enter patterns to ignore (one per line). e.g., 'node_modules/**' or '.git/**'")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Ignored Files/Folders")
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
                        let parsedPatterns = ignoredPatternsText
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            
                        var folder = SyncFolder(
                            localPath: localPath,
                            remoteName: remote.name,
                            remotePath: remotePath,
                            ignoredPatterns: parsedPatterns,
                            syncMode: syncMode
                        )
                        syncManager.folders.append(folder)
                        syncManager.saveFolders()
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(localPath.isEmpty || selectedRemote == nil)
            }
        }
        .padding()
        .frame(width: 450, height: 450)
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
    @State private var ignoredPatternsText: String = ""
    @State private var syncMode: SyncMode = .sync
    
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
                    Picker("Remote Account", selection: $selectedRemote) {
                        Text("Select...").tag(nil as RcloneRemote?)
                        ForEach(syncManager.availableRemotes) { remote in
                            Text(remote.displayName).tag(remote as RcloneRemote?)
                        }
                    }
                    
                    TextField("Remote Path", text: $remotePath)
                        .textFieldStyle(.roundedBorder)
                }

                Section {
                    Toggle(
                        "Two-way sync",
                        isOn: Binding(
                            get: {
                                syncMode == .bisync
                            },
                            set: { enabled in
                                syncMode = enabled ? .bisync : .sync
                            }
                        )
                    )

                    Text(
                        syncMode == .bisync
                        ? "Changes on both the local and remote side are synchronized."
                        : "The remote folder is mirrored from the local folder."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                } header: {
                    Text("Sync Mode")
                }
                
                Section {
                    TextEditor(text: $ignoredPatternsText)
                        .frame(height: 80)
                        .font(.system(.body, design: .monospaced))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    Text("Enter patterns to ignore (one per line). e.g., 'node_modules/**' or '.git/**'")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Ignored Files/Folders")
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
                        updated.syncMode = syncMode
                        
                        updated.ignoredPatterns = ignoredPatternsText
                            .components(separatedBy: .newlines)
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                            
                        syncManager.updateFolder(updated)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(localPath.isEmpty || selectedRemote == nil)
            }
        }
        .padding()
        .frame(width: 450, height: 450)
        .onAppear {
            localPath = folder.localPath
            remotePath = folder.remotePath
            selectedRemote = syncManager.availableRemotes.first { $0.name == folder.remoteName }
            ignoredPatternsText = folder.ignoredPatterns.joined(separator: "\n")
            syncMode = folder.syncMode
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
    
    @State private var accountName: String = ""
    @State private var isAuthenticating: Bool = false
    @State private var authError: String? = nil
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "safari.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 12) {
                Text("Connect Google Drive")
                    .font(.title3.bold())
                
                Text("Give your account a name. This will open your web browser to sign in to Google Drive.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Account Name (e.g. Work Drive)", text: $accountName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isAuthenticating)
                
                if let error = authError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isAuthenticating)
                
                Button {
                    authenticate()
                } label: {
                    if isAuthenticating {
                        HStack {
                            Text("Authenticating...")
                            ProgressView()
                                .controlSize(.small)
                        }
                    } else {
                        Text("Connect Account")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(sanitizedName.isEmpty || isAuthenticating)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
    
    private var sanitizedName: String {
        let trimmed = accountName.trimmingCharacters(in: .whitespaces)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_@.-"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
            .replacingOccurrences(of: " ", with: "_")
    }
    
    private func authenticate() {
        guard !sanitizedName.isEmpty else { return }
        
        // Check if name already exists
        if syncManager.availableRemotes.contains(where: { $0.name == sanitizedName }) {
            authError = "An account with this name already exists."
            return
        }
        
        isAuthenticating = true
        authError = nil
        
        Task {
            do {
                try await syncManager.addNewDriveRemote(name: sanitizedName)
                dismiss()
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        }
    }
}

// MARK: - Accounts Tab

struct AccountsSettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    @State private var showingAddAccountSheet = false
    @State private var showingRenameSheet = false
    @State private var accountToRename: RcloneRemote?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected Accounts")
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
                        Label("Connect Account", systemImage: "link")
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
                            Text(remote.type)
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
    
    @State private var isCheckingForUpdates = false
    @State private var showingUpdateAlert = false
    @State private var updateAlertTitle = ""
    @State private var updateAlertMessage = ""
    @State private var updateURL: URL?
    
    // Advanced / Reset state
    @State private var showingResetConfirmation = false
    
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
            
            Section {
                Toggle("Automatically check for updates", isOn: $syncManager.settings.checkUpdatesAutomatically)
                
                Button {
                    checkForUpdates()
                } label: {
                    if isCheckingForUpdates {
                        HStack {
                            Text("Checking...")
                            ProgressView()
                                .controlSize(.small)
                        }
                    } else {
                        Text("Check for Updates")
                    }
                }
                .disabled(isCheckingForUpdates)
                .alert(updateAlertTitle, isPresented: $showingUpdateAlert) {
                    if let url = updateURL {
                        Button("Get Update") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(updateAlertMessage)
                }
                
                HStack {
                    Text("Version")
                    Spacer()
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .foregroundStyle(.secondary)
                }
                
            } header: {
                Text("About")
            }
            
            Section {
                Button {
                    if let url = URL(string: "https://ko-fi.com/saihgupr") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label("Buy me a coffee", systemImage: "cup.and.saucer.fill")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Support")
            }
            
            Section {
                Button("Reset Everything...", role: .destructive) {
                    showingResetConfirmation = true
                }
            } header: {
                Text("Danger Zone")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: syncManager.settings) { _, _ in
            syncManager.saveSettings()
        }
        .alert("Reset All Settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset Everything", role: .destructive) {
                syncManager.resetAllSettings()
            }
        } message: {
            Text("This will remove all sync folders and account connections from the app. This cannot be undone.")
        }
    }
    
    private func checkForUpdates() {
        isCheckingForUpdates = true
        Task {
            do {
                let (isAvailable, latestVersion, url) = try await syncManager.checkForUpdates()
                if isAvailable {
                    updateAlertTitle = "Update Available"
                    updateAlertMessage = "A new version (\(latestVersion)) is available."
                    updateURL = url
                } else {
                    updateAlertTitle = "Up to Date"
                    updateAlertMessage = "You are running the latest version."
                    updateURL = nil
                }
            } catch {
                updateAlertTitle = "Update Check Failed"
                updateAlertMessage = error.localizedDescription
            }
            isCheckingForUpdates = false
            showingUpdateAlert = true
        }
    }
}
