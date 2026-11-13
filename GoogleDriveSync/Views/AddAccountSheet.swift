//
//  AddAccountSheet.swift
//  GoogleDriveSync
//
//  Google Drive onboarding: name the account, supply an OAuth client,
//  sign in with Google in the browser, verify the connection.
//

import SwiftUI
import AppKit

struct AddAccountSheet: View {
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var connector = DriveAccountConnector()
    
    @State private var accountName: String = ""
    @State private var useOwnClient: Bool = true
    @State private var clientID: String = ""
    @State private var clientSecret: String = ""
    @State private var reusedExistingClient: Bool = false
    @State private var formError: String? = nil
    
    var body: some View {
        Group {
            switch connector.phase {
            case .idle, .failed:
                formView
            case .authorizing:
                authorizingView
            case .saving, .verifying:
                verifyingView
            case .connected(let info):
                connectedView(info)
            }
        }
        .padding(24)
        .frame(width: 480)
        .task { await prefillCredentials() }
        .onChange(of: connector.phase) { _, newPhase in
            switch newPhase {
            case .connected:
                Task { await syncManager.refreshRemotes() }
            case .failed(let message):
                formError = message
            default:
                break
            }
        }
    }
    
    // MARK: - Step 1: form
    
    private var formView: some View {
        VStack(spacing: 20) {
            header(
                icon: "person.crop.circle.badge.plus",
                title: "Connect Google Drive",
                subtitle: "Name the account, then sign in with Google in your browser."
            )
            
            VStack(alignment: .leading, spacing: 12) {
                TextField("Account Name (e.g. Work Drive)", text: $accountName)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Use my own Google OAuth client (recommended)", isOn: $useOwnClient)
                
                if useOwnClient {
                    credentialFields
                } else {
                    Label {
                        Text("rclone's shared client is being retired during 2026 and Google may already reject it with “invalid_client”. If sign-in fails, switch this on and use your own client.")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                
                if let error = formError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            HStack(spacing: 16) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Button("Connect Account") { connect() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canConnect)
            }
        }
    }
    
    private var credentialFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Client ID (ends in .apps.googleusercontent.com)", text: $clientID)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
            
            if !clientID.trimmingCharacters(in: .whitespaces).isEmpty && !credentials.hasValidClientID {
                Text("Client IDs end in \(DriveClientCredentials.clientIDSuffix). Double-check you copied the ID, not the secret.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            SecureField("Client Secret", text: $clientSecret)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
            
            if reusedExistingClient {
                Text("Reusing the OAuth client from your existing account. Each Google account you add can share the same client.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            DisclosureGroup("How do I get a Client ID and Secret?") {
                clientInstructions
                    .padding(.top, 6)
            }
            .font(.callout)
        }
    }
    
    private var clientInstructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About five minutes in the Google Cloud Console. Google requires this because the client identifies *you*, not this app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            instructionStep(1, "Create a project (or pick an existing one).",
                            link: "Open Console", url: "https://console.cloud.google.com/projectcreate")
            instructionStep(2, "Enable the Google Drive API for that project.",
                            link: "Enable Drive API", url: "https://console.cloud.google.com/apis/library/drive.googleapis.com")
            instructionStep(3, "Set up the OAuth consent screen: user type External, add your own Google account as a test user.",
                            link: "Consent Screen", url: "https://console.cloud.google.com/auth/overview")
            instructionStep(4, "Under Audience, set Publishing status to “In production”. In “Testing”, Google expires sign-ins after 7 days and syncing silently stops.",
                            link: "Audience", url: "https://console.cloud.google.com/auth/audience", emphasized: true)
            instructionStep(5, "Credentials → Create Credentials → OAuth client ID, application type “Desktop app”. Copy the Client ID and Client Secret into the fields above.",
                            link: "Credentials", url: "https://console.cloud.google.com/apis/credentials")
            
            Text("When you sign in, Google shows an “unverified app” warning once. Choose Advanced → Go to your project name to continue. That's expected for a personal client.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func instructionStep(_ number: Int, _ text: String, link: String, url: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.caption)
                    .fontWeight(emphasized ? .semibold : .regular)
                    .fixedSize(horizontal: false, vertical: true)
                if let destination = URL(string: url) {
                    Link("\(link) ↗", destination: destination)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Step 2: browser sign-in
    
    private var authorizingView: some View {
        VStack(spacing: 20) {
            header(
                icon: "safari.fill",
                title: "Waiting for Google sign-in…",
                subtitle: "Your browser should have opened. Sign in, allow access to Google Drive, then come back here."
            )
            
            ProgressView()
                .controlSize(.large)
            
            if let url = connector.authURL {
                VStack(spacing: 6) {
                    Text("Browser didn't open?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Open Sign-in Page") { NSWorkspace.shared.open(url) }
                        Button("Copy Link") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url.absoluteString, forType: .string)
                        }
                    }
                    .controlSize(.small)
                }
            }
            
            Text("Times out after \(Int(RcloneWrapper.authorizationTimeout / 60)) minutes.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            Button("Cancel") { connector.cancel() }
                .keyboardShortcut(.cancelAction)
        }
    }
    
    // MARK: - Step 3: save and verify
    
    private var verifyingView: some View {
        VStack(spacing: 20) {
            header(
                icon: "checkmark.icloud",
                title: "Checking the connection…",
                subtitle: "Saving the account and asking Google Drive for your storage quota."
            )
            ProgressView()
                .controlSize(.large)
        }
    }
    
    // MARK: - Step 4: done
    
    private func connectedView(_ info: DriveAccountInfo) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
            
            VStack(spacing: 8) {
                Text("“\(sanitizedName)” is connected")
                    .font(.title3.bold())
                Text(info.summary)
                    .foregroundStyle(.secondary)
            }
            
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
    
    // MARK: - Shared pieces
    
    private func header(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.blue.gradient)
            Text(title)
                .font(.title3.bold())
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Logic
    
    private var credentials: DriveClientCredentials {
        DriveClientCredentials(clientID: clientID, clientSecret: clientSecret)
    }
    
    private var sanitizedName: String {
        let trimmed = accountName.trimmingCharacters(in: .whitespaces)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_@.-"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
            .replacingOccurrences(of: " ", with: "_")
    }
    
    private var canConnect: Bool {
        guard !sanitizedName.isEmpty, !connector.isBusy else { return false }
        return useOwnClient ? credentials.isComplete : true
    }
    
    private func prefillCredentials() async {
        guard clientID.isEmpty, clientSecret.isEmpty,
              let existing = await connector.existingCredentials(rclone: syncManager.rcloneWrapper) else { return }
        clientID = existing.clientID
        clientSecret = existing.clientSecret
        reusedExistingClient = true
    }
    
    private func connect() {
        guard canConnect else { return }
        
        if syncManager.availableRemotes.contains(where: { $0.name == sanitizedName }) {
            formError = "An account with this name already exists."
            return
        }
        
        formError = nil
        connector.connect(
            rclone: syncManager.rcloneWrapper,
            name: sanitizedName,
            credentials: useOwnClient ? credentials : nil
        )
    }
}
