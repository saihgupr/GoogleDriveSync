---
module: System
date: 2026-03-02
problem_type: security_issue
component: tooling
symptoms:
  - "OAuth token for Google Drive remote could be exposed via rename operations."
  - "AppleScript execution of the rclone binary used an unescaped path, allowing injection via crafted binary names."
  - "Sync configuration accepted unsafe local paths, remote paths, and remote names without validation."
  - "Security-sensitive behavior (token handling, path execution) lacked unit tests and explicit documentation."
root_cause: missing_validation
resolution_type: code_fix
severity: high
tags: [security, oauth-token, apple-script, validation, tests]
---

# Troubleshooting: Security hardening gaps in GoogleDriveSync macOS app

## Problem
The GoogleDriveSync macOS menubar app had several security hardening gaps around OAuth token handling, AppleScript-based `rclone` execution, and configuration validation, with no dedicated tests or documentation to guard against regressions.

## Environment
- Module: System-wide (GoogleDriveSync macOS application)
- Rails Version: N/A (Swift/macOS app using rclone CLI)
- Affected Component: rclone wrapper, sync configuration management, and update check logic
- Date: 2026-03-02

## Symptoms
- OAuth token for the Google Drive remote could be exposed via rename operations that passed the raw remote configuration (including token) through to `rclone`.
- AppleScript execution of the `rclone` binary interpolated the `rclonePath` directly into the AppleScript string without escaping, making it vulnerable to injection via crafted binary names or paths.
- Sync configuration accepted unsafe local paths (e.g., outside safe roots), remote paths with `..` or control characters, and remote names with unexpected characters.
- Security-sensitive code paths (token handling, path execution, update checks) had no focused unit tests or SECURITY.md guidance, making regressions likely.

## What Didn't Work

**Direct solution:** The problem was identified and fixed during a focused security review rather than after user-facing failures, so there were no prior failed remediation attempts.

## Solution

The fix was a coordinated security hardening update across several components:

- **Stop exposing OAuth token via rename:**
  - Changed rename behavior to work purely in terms of user-facing display names stored in `UserDefaults` under a dedicated key (e.g., `DriveSync.RemoteDisplayNames`).
  - The actual remote configuration name (which may embed credentials) is never passed to `rclone` as the "new name"; only the display name is updated in local preferences.
  - `displayName(forRemoteConfigName:)` now returns a custom display name when present, and otherwise falls back to the underlying config name without exposing secrets.

- **Escape `rclonePath` for AppleScript:**
  - Introduced a dedicated `escapeForAppleScript()` helper on `String` in the `RcloneWrapper` so any `rclonePath` interpolated into AppleScript is first sanitized.
  - The helper escapes backslashes and double quotes, preventing crafted binary names from breaking out of the string literal in the AppleScript command.

```swift
// Example: escaping binary path before embedding in AppleScript
extension String {
    func escapeForAppleScript() -> String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
```

- **Centralized sync configuration validation:**
  - Added a `SyncFolderValidator` utility responsible for validating:
    - **Local paths:** must live under allowed roots (e.g., within the current user's home directory or `/Volumes`) and must exist on disk.
    - **Remote names:** restricted to safe characters (alphanumerics plus a small set like `_@.-`), with reasonable length limits.
    - **Remote paths:** forbid `..`, control characters, and overly long paths, while still allowing simple and nested paths.
  - `SyncManager` now calls into this validator before accepting or persisting sync configurations.

- **`rclonePath` allowlist and validation:**
  - Added a validation layer in `AppSettings` (`validateRclonePath`) that only accepts `rclone` binaries from an allowlisted set of expected locations.
  - This reduces the risk of inadvertently executing an attacker-controlled `rclone` binary from an unexpected path.

- **Update check and logging hygiene:**
  - Ensured update checks use the correct GitHub repository URL and a User-Agent derived from the app bundle (name + version).
  - Wrapped debug `print` statements in `#if DEBUG` so no sensitive information is logged in release builds.

- **Unit tests and documentation:**
  - Added `SecurityHardeningTests` to verify:
    - AppleScript escaping behavior.
    - Path and name validation rules.
    - Display-name mapping semantics and rename behavior (no token exposure).
    - Update check configuration (GitHub repo and User-Agent).
  - Created a `SECURITY.md` that documents the threat model, the new invariants (no token exposure, validated paths, allowlisted binaries), and expected development practices.

## Why This Works

1. **Token exposure is eliminated** because rename operations never send the raw remote configuration (which may include OAuth tokens) through to `rclone`. Instead, only a user-defined display name is updated in `UserDefaults`, and the underlying config name remains unchanged and unexposed.
2. **AppleScript injection is prevented** by escaping backslashes and double quotes in `rclonePath` before embedding it in the AppleScript string. This closes off the straightforward path where a maliciously named binary could terminate the string literal and inject additional AppleScript commands.
3. **Configuration-based attacks are mitigated** by centralizing validation:
   - Local paths are constrained to safe roots and checked for existence, reducing the risk of syncing unexpected parts of the filesystem.
   - Remote names and paths are constrained in character set and length, blocking path traversal and control-character-based tricks.
4. **Binary hijacking is harder** because `rclonePath` must pass an allowlist check, making it unlikely that an arbitrary `rclone` binary from an unexpected location will be executed.
5. **Future regressions are less likely** thanks to explicit unit tests around the hardened behaviors and a `SECURITY.md` that documents the invariants and expectations for future contributors.

## Prevention

- Treat any code that touches credentials, filesystem paths, or process execution as security-sensitive and subject it to the same kind of focused review performed here.
- Route all path, remote, and name validation through a single utility (`SyncFolderValidator`) and ensure new features reuse it instead of re-implementing ad hoc checks.
- Keep `rclonePath` validation strict and documented; avoid adding "convenience" bypasses without strong justification and compensating controls.
- Maintain and run unit tests for all security-sensitive behaviors (escaping, validation, token handling) as part of regular CI to catch regressions early.
- Keep `SECURITY.md` up to date whenever new security-relevant features or changes are introduced.

## Related Issues

No related issues documented yet.

