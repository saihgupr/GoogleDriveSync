//
//  DriveAccountConnector.swift
//  GoogleDriveSync
//
//  Drives the Google Drive onboarding flow:
//  authorize in the browser → save the remote → verify it can reach Drive.
//

import Foundation

@MainActor
final class DriveAccountConnector: ObservableObject {
    enum Phase: Equatable {
        case idle
        case authorizing
        case saving
        case verifying
        case connected(DriveAccountInfo)
        case failed(String)
    }
    
    @Published private(set) var phase: Phase = .idle
    /// The sign-in URL rclone is waiting on, for a "browser didn't open?" fallback.
    @Published private(set) var authURL: URL?
    
    private var authProcess: ProcessHandle?
    
    var isBusy: Bool {
        switch phase {
        case .authorizing, .saving, .verifying: return true
        case .idle, .connected, .failed: return false
        }
    }
    
    /// Credentials already stored on another Drive remote, so a second account
    /// can reuse the OAuth client the user created for the first one.
    func existingCredentials(rclone: RcloneWrapper) async -> DriveClientCredentials? {
        await rclone.existingDriveClientCredentials()
    }
    
    func connect(rclone: RcloneWrapper, name: String, credentials: DriveClientCredentials?) {
        guard !isBusy else { return }
        phase = .authorizing
        authURL = nil
        
        Task {
            do {
                let token = try await rclone.authorizeDrive(
                    credentials: credentials,
                    onStart: { [weak self] handle in
                        Task { @MainActor in self?.authProcess = handle }
                    },
                    onAuthURL: { [weak self] url in
                        Task { @MainActor in self?.authURL = url }
                    }
                )
                authProcess = nil
                
                phase = .saving
                try await rclone.createDriveAccount(name: name, credentials: credentials, token: token)
                
                phase = .verifying
                do {
                    let info = try await rclone.verifyRemote(name: name)
                    phase = .connected(info)
                } catch {
                    // Don't leave an account behind that will fail on every sync.
                    try? await rclone.deleteRemote(name: name)
                    throw error
                }
            } catch {
                authProcess = nil
                phase = .failed(error.localizedDescription)
            }
        }
    }
    
    /// Stops a sign-in that is waiting on the browser.
    func cancel() {
        authProcess?.terminate()
    }
    
    func reset() {
        guard !isBusy else { return }
        phase = .idle
        authURL = nil
    }
}
