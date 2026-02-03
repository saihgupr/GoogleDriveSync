//
//  GoogleDriveSyncApp.swift
//  GoogleDriveSync
//
//  Created by saihgupr on 2024-12-11.
//

import SwiftUI
import ServiceManagement
import UserNotifications

@main
struct GoogleDriveSyncApp: App {
    @StateObject private var syncManager = SyncManager()
    @Environment(\.openSettings) private var openSettings
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
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

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        
        // Register notification categories
        let errorAction = UNNotificationAction(identifier: "SHOW_LOGS", title: "Show Logs", options: .foreground)
        let errorCategory = UNNotificationCategory(
            identifier: "SYNC_ERROR",
            actions: [errorAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: .customDismissAction
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([errorCategory])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and play sound even if app is in foreground
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        if response.notification.request.content.categoryIdentifier == "SYNC_ERROR" {
            // In a real app, we might want to open a logs view or the specific folder
            // For now, opening the main window/settings is a reasonable default
            // Since this is a menu bar app, we might need a way to open the window
        }
        completionHandler()
    }
}
