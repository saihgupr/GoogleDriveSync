import XCTest
@testable import GoogleDriveSync

final class SecurityHardeningTests: XCTestCase {
    // MARK: - AppleScript escaping

    func testAppleScriptEscaping_noSpecialCharacters_returnsSameString() {
        let input = "/opt/homebrew/bin/rclone"
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        XCTAssertEqual(escaped, input)
    }

    func testAppleScriptEscaping_quotesAreEscaped() {
        let input = #"/usr/local/bin/rclone "config""#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Escaped form is \" - safe for AppleScript interpolation
        XCTAssertTrue(escaped.contains("\\\"config\\\""))
    }

    func testAppleScriptEscaping_backslashesAreEscaped() {
        let input = #"C:\Tools\rclone.exe"#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Every backslash should be doubled
        XCTAssertTrue(escaped.contains("C:\\\\Tools\\\\rclone.exe"))
    }

    func testAppleScriptEscaping_mixedQuotesAndBackslashes() {
        let input = #"C:\Program Files\rclone "beta""#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Escaped form: backslashes doubled, quotes escaped as \"
        XCTAssertTrue(escaped.contains("\\\\Program Files\\\\rclone \\\"beta\\\""))
    }

    func testAppleScriptEscaping_handlesEmptyString() {
        let escaped = RcloneWrapper.escapeForAppleScript("")
        XCTAssertEqual(escaped, "")
    }

    // MARK: - SyncFolderValidator: remote names

    func testValidateRemoteName_allowsSafeCharacters() {
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("gdrive"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("work_email@example.com"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("backup-1.2"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("UPPER_lower-123"))
    }

    func testValidateRemoteName_rejectsSpacesAndInvalidCharacters() {
        XCTAssertFalse(SyncFolderValidator.validateRemoteName(""))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("name with space"))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("weird💾"))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("semi;colon"))
    }

    func testValidateRemoteName_rejectsOverlyLongName() {
        let long = String(repeating: "a", count: 300)
        XCTAssertFalse(SyncFolderValidator.validateRemoteName(long))
    }

    // MARK: - SyncFolderValidator: remote paths

    func testValidateRemotePath_allowsSimpleAndNestedPaths() {
        XCTAssertTrue(SyncFolderValidator.validateRemotePath(""))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("Backups"))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("Backups/MyMac/2026"))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("folder-with-dash/and_underscore"))
    }

    func testValidateRemotePath_rejectsDotDotAndControlCharacters() {
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("../escape"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("folder/../escape"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("line\nbreak"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("tab\tchar"))
    }

    func testValidateRemotePath_rejectsOverlyLongPath() {
        let longComponent = String(repeating: "a", count: 2000)
        XCTAssertFalse(SyncFolderValidator.validateRemotePath(longComponent))
    }

    // MARK: - SyncFolderValidator: local path (negative cases only, to avoid filesystem coupling)

    func testValidateLocalPath_rejectsEmptyAndRoot() {
        XCTAssertFalse(SyncFolderValidator.validateLocalPath(""))
        XCTAssertFalse(SyncFolderValidator.validateLocalPath("/"))
    }

    func testValidateLocalPath_rejectsNonexistentPath() {
        let path = "/this/definitely/does/not/exist/\(UUID().uuidString)"
        XCTAssertFalse(SyncFolderValidator.validateLocalPath(path))
    }

    // MARK: - rclonePath validation (negative cases, to avoid environment coupling)

    func testValidateRclonePath_rejectsNonRcloneBinaryNames() {
        XCTAssertNil(AppSettings.validateRclonePath("/usr/local/bin/not-rclone"))
        XCTAssertNil(AppSettings.validateRclonePath("/opt/homebrew/bin/rclone-helper"))
    }

    func testValidateRclonePath_rejectsDisallowedPrefixes() {
        XCTAssertNil(AppSettings.validateRclonePath("/tmp/rclone"))
        XCTAssertNil(AppSettings.validateRclonePath("/Users/Shared/rclone"))
    }

    // MARK: - Display-name mapping for remotes

    @MainActor
    func testDisplayNameForRemote_defaultsToConfigNameWhenNoCustomName() {
        let manager = SyncManager()
        let name = "test_\(UUID().uuidString.prefix(8))"
        XCTAssertEqual(manager.displayName(forRemoteConfigName: name), name)
    }

    @MainActor
    func testDisplayNameForRemote_usesCustomDisplayNameWhenSet() {
        let manager = SyncManager()
        let configName = "gdrive"
        let customName = "Work Drive"

        manager.setRemoteDisplayName(configName: configName, displayName: customName)

        XCTAssertEqual(manager.displayName(forRemoteConfigName: configName), customName)
    }

    @MainActor
    func testRenameRemote_setsDisplayNameOnly() async {
        let manager = SyncManager()
        let configName = "gdrive"
        let friendlyName = "Personal Drive"

        let success = await manager.renameRemote(from: configName, to: friendlyName)
        XCTAssertTrue(success)
        XCTAssertEqual(manager.displayName(forRemoteConfigName: configName), friendlyName)
    }

    // MARK: - UpdateCheckConfig

    func testUpdateCheckConfig_usesGoogleDriveSyncRepo() {
        let url = UpdateCheckConfig.githubReleasesURL
        XCTAssertEqual(url.host, "api.github.com")
        XCTAssertTrue(url.absoluteString.hasSuffix("/saihgupr/GoogleDriveSync/releases/latest"))
    }

    func testUpdateCheckConfig_userAgentIncludesAppNameAndVersion() {
        let userAgent = UpdateCheckConfig.userAgent
        XCTAssertTrue(userAgent.contains("GoogleDriveSync"))
        XCTAssertTrue(userAgent.contains("/"))
    }
}

import XCTest
@testable import GoogleDriveSync

final class SecurityHardeningTests: XCTestCase {
    // MARK: - AppleScript escaping

    func testAppleScriptEscaping_noSpecialCharacters_returnsSameString() {
        let input = "/opt/homebrew/bin/rclone"
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        XCTAssertEqual(escaped, input)
    }

    func testAppleScriptEscaping_quotesAreEscaped() {
        let input = #"/usr/local/bin/rclone "config""#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Escaped form is \" - safe for AppleScript interpolation
        XCTAssertTrue(escaped.contains("\\\"config\\\""))
    }

    func testAppleScriptEscaping_backslashesAreEscaped() {
        let input = #"C:\Tools\rclone.exe"#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Every backslash should be doubled
        XCTAssertTrue(escaped.contains("C:\\\\Tools\\\\rclone.exe"))
    }

    func testAppleScriptEscaping_mixedQuotesAndBackslashes() {
        let input = #"C:\Program Files\rclone "beta""#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Escaped form: backslashes doubled, quotes escaped as \"
        XCTAssertTrue(escaped.contains("\\\\Program Files\\\\rclone \\\"beta\\\""))
    }

    func testAppleScriptEscaping_handlesEmptyString() {
        let escaped = RcloneWrapper.escapeForAppleScript("")
        XCTAssertEqual(escaped, "")
    }

    // MARK: - SyncFolderValidator: remote names

    func testValidateRemoteName_allowsSafeCharacters() {
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("gdrive"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("work_email@example.com"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("backup-1.2"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("UPPER_lower-123"))
    }

    func testValidateRemoteName_rejectsSpacesAndInvalidCharacters() {
        XCTAssertFalse(SyncFolderValidator.validateRemoteName(""))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("name with space"))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("weird💾"))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("semi;colon"))
    }

    func testValidateRemoteName_rejectsOverlyLongName() {
        let long = String(repeating: "a", count: 300)
        XCTAssertFalse(SyncFolderValidator.validateRemoteName(long))
    }

    // MARK: - SyncFolderValidator: remote paths

    func testValidateRemotePath_allowsSimpleAndNestedPaths() {
        XCTAssertTrue(SyncFolderValidator.validateRemotePath(""))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("Backups"))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("Backups/MyMac/2026"))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("folder-with-dash/and_underscore"))
    }

    func testValidateRemotePath_rejectsDotDotAndControlCharacters() {
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("../escape"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("folder/../escape"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("line\nbreak"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("tab\tchar"))
    }

    func testValidateRemotePath_rejectsOverlyLongPath() {
        let longComponent = String(repeating: "a", count: 2000)
        XCTAssertFalse(SyncFolderValidator.validateRemotePath(longComponent))
    }

    // MARK: - SyncFolderValidator: local path (negative cases only, to avoid filesystem coupling)

    func testValidateLocalPath_rejectsEmptyAndRoot() {
        XCTAssertFalse(SyncFolderValidator.validateLocalPath(""))
        XCTAssertFalse(SyncFolderValidator.validateLocalPath("/"))
    }

    func testValidateLocalPath_rejectsNonexistentPath() {
        let path = "/this/definitely/does/not/exist/\(UUID().uuidString)"
        XCTAssertFalse(SyncFolderValidator.validateLocalPath(path))
    }

    // MARK: - rclonePath validation (negative cases, to avoid environment coupling)

    func testValidateRclonePath_rejectsNonRcloneBinaryNames() {
        XCTAssertNil(AppSettings.validateRclonePath("/usr/local/bin/not-rclone"))
        XCTAssertNil(AppSettings.validateRclonePath("/opt/homebrew/bin/rclone-helper"))
    }

    func testValidateRclonePath_rejectsDisallowedPrefixes() {
        XCTAssertNil(AppSettings.validateRclonePath("/tmp/rclone"))
        XCTAssertNil(AppSettings.validateRclonePath("/Users/Shared/rclone"))
    }

    // MARK: - Display-name mapping for remotes

    @MainActor
    func testDisplayNameForRemote_defaultsToConfigNameWhenNoCustomName() {
        let manager = SyncManager()
        let name = "test_\(UUID().uuidString.prefix(8))"
        XCTAssertEqual(manager.displayName(forRemoteConfigName: name), name)
    }

    @MainActor
    func testDisplayNameForRemote_usesCustomDisplayNameWhenSet() {
        let manager = SyncManager()
        let configName = "gdrive"
        let customName = "Work Drive"

        manager.setRemoteDisplayName(configName: configName, displayName: customName)

        XCTAssertEqual(manager.displayName(forRemoteConfigName: configName), customName)
    }

    @MainActor
    func testRenameRemote_setsDisplayNameOnly() async {
        let manager = SyncManager()
        let configName = "gdrive"
        let friendlyName = "Personal Drive"

        let success = await manager.renameRemote(from: configName, to: friendlyName)
        XCTAssertTrue(success)
        XCTAssertEqual(manager.displayName(forRemoteConfigName: configName), friendlyName)
    }

    // MARK: - UpdateCheckConfig

    func testUpdateCheckConfig_usesGoogleDriveSyncRepo() {
        let url = UpdateCheckConfig.githubReleasesURL
        XCTAssertEqual(url.host, "api.github.com")
        XCTAssertTrue(url.absoluteString.hasSuffix("/saihgupr/GoogleDriveSync/releases/latest"))
    }

    func testUpdateCheckConfig_userAgentIncludesAppNameAndVersion() {
        let userAgent = UpdateCheckConfig.userAgent
        XCTAssertTrue(userAgent.contains("GoogleDriveSync"))
        XCTAssertTrue(userAgent.contains("/"))
    }
}

*** End of File
    
    // MARK: - SyncFolderValidator
    
    func testValidateRemoteName_allowsSafeCharacters() {
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("remote"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("remote_name-1@foo.bar"))
    }
    
    func testValidateRemoteName_rejectsInvalidCharacters() {
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("remote name with spaces"))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("remote/name"))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("remote\nname"))
    }
    
    func testValidateRemotePath_rejectsDotDotAndControlCharacters() {
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("../etc"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("folder/\u{0007}bell"))
    }
    
    func testValidateRemotePath_allowsSimpleSafePath() {
        XCTAssertTrue(SyncFolderValidator.validateRemotePath(""))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("Backups/Mac"))
    }
    
    func testValidateLocalPath_rejectsNonexistentPath() {
        let impossiblePath = "/this/path/should/not/exist/\(UUID().uuidString)"
        XCTAssertFalse(SyncFolderValidator.validateLocalPath(impossiblePath))
    }
    
    // MARK: - rclonePath validation
    
    func testValidateRclonePath_rejectsNonRcloneBinaryNames() {
        XCTAssertNil(AppSettings.validateRclonePath("/usr/local/bin/not-rclone"))
        XCTAssertNil(AppSettings.validateRclonePath("/opt/homebrew/bin/rclone-helper"))
    }
    
    func testValidateRclonePath_rejectsDisallowedPrefixes() {
        XCTAssertNil(AppSettings.validateRclonePath("/tmp/rclone"))
        XCTAssertNil(AppSettings.validateRclonePath("/Users/Shared/rclone"))
    }
    
    // MARK: - AppleScript escaping
    
    func testEscapeForAppleScript_escapesQuotesAndBackslashes() {
        let input = #"C:\Program Files\rclone\rclone "config"""#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        
        XCTAssertFalse(escaped.contains("\""))
        XCTAssertFalse(escaped.contains("\\\""))
        // Escaped string should be safe to drop inside an AppleScript double-quoted string
        XCTAssertFalse(escaped.contains("\n"))
    }
    
    func testEscapeForAppleScript_handlesEmptyString() {
        let escaped = RcloneWrapper.escapeForAppleScript("")
        XCTAssertEqual(escaped, "")
    }
    
    // MARK: - Display-name-only renames
    
    func testDisplayNameRename_updatesDisplayNameOnly() async {
        let manager = SyncManager()
        let configName = "my-remote"
        
        // Initially, display name falls back to config name
        XCTAssertEqual(manager.displayName(forRemoteConfigName: configName), configName)
        
        let renamed = await manager.renameRemote(from: configName, to: "Work Drive")
        XCTAssertTrue(renamed)
        XCTAssertEqual(manager.displayName(forRemoteConfigName: configName), "Work Drive")
    }
}

import XCTest
@testable import GoogleDriveSync

final class SecurityHardeningTests: XCTestCase {
    // MARK: - AppleScript escaping

    func testAppleScriptEscaping_noSpecialCharacters_returnsSameString() {
        let input = "/opt/homebrew/bin/rclone"
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        XCTAssertEqual(escaped, input)
    }

    func testAppleScriptEscaping_quotesAreEscaped() {
        let input = #"/usr/local/bin/rclone "config""#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Escaped form is \" - safe for AppleScript interpolation
        XCTAssertTrue(escaped.contains("\\\"config\\\""))
    }

    func testAppleScriptEscaping_backslashesAreEscaped() {
        let input = #"C:\Tools\rclone.exe"#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Every backslash should be doubled
        XCTAssertTrue(escaped.contains("C:\\\\Tools\\\\rclone.exe"))
    }

    func testAppleScriptEscaping_mixedQuotesAndBackslashes() {
        let input = #"C:\Program Files\rclone "beta""#
        let escaped = RcloneWrapper.escapeForAppleScript(input)
        // Escaped form: backslashes doubled, quotes escaped as \"
        XCTAssertTrue(escaped.contains("\\\\Program Files\\\\rclone \\\"beta\\\""))
    }

    // MARK: - SyncFolderValidator: remote names

    func testValidateRemoteName_allowsSafeCharacters() {
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("gdrive"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("work_email@example.com"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("backup-1.2"))
        XCTAssertTrue(SyncFolderValidator.validateRemoteName("UPPER_lower-123"))
    }

    func testValidateRemoteName_rejectsSpacesAndInvalidCharacters() {
        XCTAssertFalse(SyncFolderValidator.validateRemoteName(""))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("name with space"))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("weird💾"))
        XCTAssertFalse(SyncFolderValidator.validateRemoteName("semi;colon"))
        // Leading/trailing space is trimmed; "leadingSpace" after trim is valid
    }

    func testValidateRemoteName_rejectsOverlyLongName() {
        let long = String(repeating: "a", count: 300)
        XCTAssertFalse(SyncFolderValidator.validateRemoteName(long))
    }

    // MARK: - SyncFolderValidator: remote paths

    func testValidateRemotePath_allowsSimpleAndNestedPaths() {
        XCTAssertTrue(SyncFolderValidator.validateRemotePath(""))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("Backups"))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("Backups/MyMac/2026"))
        XCTAssertTrue(SyncFolderValidator.validateRemotePath("folder-with-dash/and_underscore"))
    }

    func testValidateRemotePath_rejectsDotDotAndControlCharacters() {
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("../escape"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("folder/../escape"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("line\nbreak"))
        XCTAssertFalse(SyncFolderValidator.validateRemotePath("tab\tchar"))
    }

    func testValidateRemotePath_rejectsOverlyLongPath() {
        let longComponent = String(repeating: "a", count: 2000)
        XCTAssertFalse(SyncFolderValidator.validateRemotePath(longComponent))
    }

    // MARK: - SyncFolderValidator: local path (negative cases only, to avoid filesystem coupling)

    func testValidateLocalPath_rejectsEmptyAndRoot() {
        XCTAssertFalse(SyncFolderValidator.validateLocalPath(""))
        XCTAssertFalse(SyncFolderValidator.validateLocalPath("/"))
    }

    func testValidateLocalPath_rejectsNonexistentPath() {
        let path = "/this/definitely/does/not/exist/\(UUID().uuidString)"
        XCTAssertFalse(SyncFolderValidator.validateLocalPath(path))
    }

    // MARK: - Display-name mapping for remotes

    @MainActor
    func testDisplayNameForRemote_defaultsToConfigNameWhenNoCustomName() {
        let manager = SyncManager()
        // Use unique name to avoid UserDefaults pollution from other tests or app usage
        let name = "test_\(UUID().uuidString.prefix(8))"
        XCTAssertEqual(manager.displayName(forRemoteConfigName: name), name)
    }

    @MainActor
    func testDisplayNameForRemote_usesCustomDisplayNameWhenSet() {
        let manager = SyncManager()
        let configName = "gdrive"
        let customName = "Work Drive"

        manager.setRemoteDisplayName(configName: configName, displayName: customName)

        XCTAssertEqual(manager.displayName(forRemoteConfigName: configName), customName)
    }

    @MainActor
    func testRenameRemote_setsDisplayNameOnly() async {
        let manager = SyncManager()
        let configName = "gdrive"
        let friendlyName = "Personal Drive"

        let success = await manager.renameRemote(from: configName, to: friendlyName)
        XCTAssertTrue(success)
        XCTAssertEqual(manager.displayName(forRemoteConfigName: configName), friendlyName)
    }

    // MARK: - UpdateCheckConfig

    func testUpdateCheckConfig_usesGoogleDriveSyncRepo() {
        let url = UpdateCheckConfig.githubReleasesURL
        XCTAssertEqual(url.host, "api.github.com")
        XCTAssertTrue(url.absoluteString.hasSuffix("/saihgupr/GoogleDriveSync/releases/latest"))
    }

    func testUpdateCheckConfig_userAgentIncludesAppNameAndVersion() {
        let ua = UpdateCheckConfig.userAgent
        XCTAssertTrue(ua.contains("GoogleDriveSync"))
        XCTAssertTrue(ua.contains("/"))
    }
}

