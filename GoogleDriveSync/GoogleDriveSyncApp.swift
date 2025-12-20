//
//  GoogleDriveSyncApp.swift
//  GoogleDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import SwiftUI
import ServiceManagement

@main
struct GoogleDriveSyncApp: App {
    @StateObject private var syncManager = SyncManager()
    @Environment(\.openSettings) private var openSettings
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(syncManager)
        } label: {
            Image(systemName: syncManager.statusIcon)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environmentObject(syncManager)
        }
    }
}
