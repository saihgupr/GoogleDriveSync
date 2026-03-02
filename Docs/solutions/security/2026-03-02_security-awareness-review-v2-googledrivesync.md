---
date: 2026-03-02
module: GoogleDriveSync macOS app
problem_type: security_hardening
severity: high
summary: Second security-awareness review and hardening pass for GoogleDriveSync, focused on credentials, secrets exposure, and safe guidance.
tags:
  - security
  - credentials
  - rclone
  - desktop
---

## Context

This document records the **second security review** (“Security Awareness Review v2”) of GoogleDriveSync, following the initial `SECURITY_REVIEW.md` and the implementation of the *Security Hardening Plan*.

The first review identified:

- OAuth tokens being exposed in process arguments during remote renames.
- AppleScript injection risk via an unescaped `rclonePath`.
- Lack of validation on paths and remote names.
- Unconstrained rclone executable path.
- Debug logging in Release.
- Mismatched update-check URL and User-Agent.

Those issues were addressed in code and documentation; this second review re-examines the result through a **security-awareness** lens: secrets handling, user guidance, and verification.

## Symptoms / Risks

- Risk of **credential exposure** via:
  - Process command lines (`argv`) visible to other processes.
  - Logs, error messages, or update-check failures.
  - Users attaching `rclone.conf` or unredacted logs to support requests.
- Risk of **code execution / injection** via:
  - Unescaped `rclonePath` embedded in AppleScript.
  - Arbitrary binaries being executed if `rclonePath` is tampered with.
- Risk of **unexpected data access** due to:
  - Unvalidated local or remote paths and remote names being passed to rclone.

## Root Causes (from first review)

- Functional rename logic that re-used tokens by passing them as plain arguments to `rclone config create`, leaking them in `argv`.
- AppleScript wrapper that interpolated `rclonePath` directly into the script.
- Convenience around configuration and paths that assumed benign inputs.
- Minimal guidance for users on what **not** to share when seeking help.

## Solutions Implemented

### 1. Credential and secret handling

- **No hardcoded secrets**: Re-confirmed that no API keys, OAuth tokens, or other credentials are embedded in code or docs.
- **Token in `argv` removed**: Remote “rename” is now implemented as a **display-name-only** operation:
  - `SyncManager` keeps a `DriveSync.RemoteDisplayNames` mapping in `UserDefaults`.
  - `renameRemote(from:to:)` only updates this mapping; rclone config names and tokens are never re-created or re-passed.
- **rclone config ownership clarified**:
  - `SECURITY.md` states clearly that credentials live only in rclone’s config (`~/.config/rclone/rclone.conf`).
  - Users are advised to protect their home directory and config file via permissions and full-disk encryption.

### 2. Execution safety (AppleScript and rclone path)

- **AppleScript escaping**:
  - `RcloneWrapper.openInteractiveConfig()` now uses `escapeForAppleScript(_:)` to safely escape backslashes and quotes before embedding `rclonePath` in AppleScript.
  - This prevents paths from breaking out of the AppleScript string and injecting additional commands.
- **rclone path allowlist**:
  - `AppSettings.validateRclonePath(_:)` now enforces:
    - Path must end with `rclone`.
    - Path must live under an allowlist (`/opt/homebrew/bin/`, `/usr/local/bin/`, `/usr/bin/`, `/opt/local/bin/`, or the app bundle).
    - File must exist, not be a directory, and be executable.
  - `detectRclonePath()` only returns validated paths; `SyncManager` validates stored paths on load and save, falling back to a detected safe path if necessary.

### 3. Input validation for paths and remotes

- **SyncFolder validation**:
  - `SyncFolderValidator.validateLocalPath(_:)` ensures:
    - Non-empty, within a max length.
    - Path exists.
    - Resolved path is under the user’s home directory or `/Volumes/`.
  - `validateRemotePath(_:)` ensures:
    - No `..` segments.
    - No control characters.
    - Reasonable length.
  - `validateRemoteName(_:)` restricts names to alphanumerics plus `_ @ . -`.
- **Call-site enforcement**:
  - `SyncManager.addFolder` and `updateFolder` both validate local path, remote name, and remote path before persisting.
  - `SyncManager.deleteRemote` validates the remote name before calling rclone.

### 4. Logging and update checks

- **Debug-only logging**:
  - All diagnostic `print(...)` calls in `SyncManager`, `RcloneWrapper`, and `GoogleDriveSyncApp` are wrapped in `#if DEBUG`.
  - Release builds avoid logging potentially sensitive file paths, remotes, or internal errors.
- **Update-check configuration**:
  - Introduced `UpdateCheckConfig` to centralize:
    - `githubReleasesURL`: `https://api.github.com/repos/saihgupr/GoogleDriveSync/releases/latest`.
    - `userAgent`: derived from bundle name and version (e.g. `GoogleDriveSync/1.0`).

### 5. User-facing documentation and guidance

- **`SECURITY.md`** now includes:
  - Clear description of credential storage in rclone and the importance of protecting `~/.config/rclone/`.
  - Explanation of why the macOS App Sandbox is disabled and how least privilege is maintained otherwise.
  - A section on **Reporting issues** that explicitly tells users:
    - Not to attach `rclone.conf` or unredacted logs/terminal output that may contain tokens or file contents.
    - To redact account names, remote names, and other sensitive details before sharing logs.
  - A **Security verification checklist (for maintainers)** (see next section).
- **`README.md`** adds:
  - A link to `SECURITY.md` under “Security”.
  - Guidance to avoid posting `rclone.conf` or unredacted logs in GitHub issues.

## Testing and Verification

### Automated security-focused tests

A new XCTest file, `GoogleDriveSyncTests/SecurityHardeningTests.swift`, was added to cover:

- **AppleScript escaping**:
  - Inputs with no special characters, quotes only, backslashes only, and mixed quotes/backslashes.
  - Ensures escaped strings are safe for embedding in double-quoted AppleScript.
- **`SyncFolderValidator`**:
  - Remote names:
    - Accepts safe names (`gdrive`, emails, dashed/underscored names, mixed case).
    - Rejects empty names, spaces, emoji, and punctuation like `;`.
  - Remote paths:
    - Accepts simple and nested paths.
    - Rejects paths with `..`, control characters, and overly long strings.
  - Local paths:
    - Rejects empty string, `/`, and clearly non-existent paths (negative tests only to avoid environment dependence).
- **`AppSettings.validateRclonePath(_:)`**:
  - Negative tests only:
    - Rejects non-`rclone` binary names.
    - Rejects paths outside the allowlist (`/tmp/rclone`, `/Users/Shared/rclone`).
- **Display-name-only renames and mapping**:
  - Verifies:
    - `displayName(forRemoteConfigName:)` falls back to config name when no mapping exists.
    - `setRemoteDisplayName` and `renameRemote(from:to:)` correctly update display names without touching rclone config.
- **`UpdateCheckConfig`**:
  - Confirms the GitHub releases URL is `api.github.com` and uses the `GoogleDriveSync` repo.
  - Confirms the User-Agent contains the app name and a `/version` component.

> Note: Tests focus on logic and negative cases to avoid depending on specific filesystem layout or installed rclone binaries.

### Manual verification checklist (from `SECURITY.md`)

Before shipping a release, maintainers should:

- **Process arguments**:
  - Trigger a sync and open rclone config.
  - Inspect `ps` or Activity Monitor and confirm that no OAuth tokens or other secrets appear in `GoogleDriveSync`’s command line.
- **Interactive config safety**:
  - Use the app’s “Add Account”/interactive config flow.
  - Confirm it still works, and that paths with spaces behave correctly.
- **Path and remote-name validation**:
  - Attempt to configure folders/remotes with invalid paths (`..`, control characters) or names (invalid characters).
  - Confirm the UI rejects them with clear but non-sensitive messages.
- **Update checks**:
  - Manually trigger an update check.
  - Confirm:
    - Any errors shown to users are generic and reveal no secrets.
    - In DEBUG builds, logs do not include tokens or sensitive file paths.

## Residual Risks and Mitigations

- **rclone config security**:
  - Still depends on OS-level permissions and full-disk encryption.
  - Mitigated via documentation and user guidance; cannot be fully enforced by the app.
- **App Sandbox disabled**:
  - Required for rclone subprocess and arbitrary folder syncing.
  - Risk is mitigated by:
    - Tight control over `rclonePath`.
    - Input validation for paths and names.
    - Lack of embedded secrets.
- **User behavior**:
  - Users might still paste secrets into logs or issues.
  - Mitigated via explicit documentation and guidance on what not to share.

## Takeaways

- Security hardening is not only about code changes; it also requires:
  - **Clear documentation** that sets user expectations around credentials and logs.
  - **Verification** (tests + manual checklists) to prevent regressions.
- For GoogleDriveSync, the combination of:
  - Display-name-only rename,
  - Safe AppleScript construction,
  - rclone path allowlisting,
  - Input validation,
  - Debug-only logging,
  - And explicit security documentation
  
  significantly reduces the attack surface for credential leakage and code execution, while preserving the app’s core functionality.

