# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed
- **Google Drive onboarding**: The Connect Account flow never actually ran the Google sign-in. It issued a single `rclone config create ... --non-interactive`, which on current rclone prints its next question (the shared client ID retirement warning) and exits 0; the app treated that as success and showed an account with no token. The flow now runs `rclone authorize drive` for the browser sign-in, writes the remote with the token and every state-machine answer supplied, and verifies the account with `rclone about` before showing it as connected. Any failure after the remote is created removes it again. Fixes #11.
- **Renaming an account** copied only the token, dropping `client_id`/`client_secret`. It now copies every stored key.

### Added
- **Bring-your-own Google OAuth client**: Client ID and Client Secret fields in the Connect Account sheet, with a step-by-step Google Cloud Console guide, since rclone's shared client is being retired during 2026. The shared client remains available behind a toggle with a warning. Adding a second account reuses the first account's client.
- **Real error messages** during sign-in, with hints for `invalid_client`, `invalid_grant` (consent screen still in "Testing" expires tokens after 7 days), `access_denied`, Drive API not enabled, and the sign-in port being in use.
- Waiting state with a "browser didn't open?" link, cancel, and a 3-minute timeout.
- `docs/GoogleDriveOnboarding.md` with the root-cause analysis and further onboarding ideas.

## [1.1.3] - 2026-03-10

### Added
- **In-App OAuth Flow**: Integrated a browser-based Google Drive authentication flow directly within the app, removing the need for terminal-based rclone setup.
- **Redesigned Add Account Sheet**: A new UI that guides the user through account naming and authentication.
- **Improved Build/Install Logic**: Automated application installation to `/Applications` and launch during deployment.

## [1.1.1] - 2026-03-09

### Added
- **Filtering Support**: Added the ability to exclude specific files and directories from syncing (e.g., `node_modules`, `.git`, `*.tmp`). Includes a new TextEditor UI in the Add/Edit Folder sheets to input ignore patterns.
- **Native Architectures**: Updated the build script (`deploy.sh`) to build separate Apple Silicon (`arm64`) and Intel (`x86_64`) apps instead of a Universal binary, reducing app size and ensuring native performance.
- Added `CHANGELOG.md` to track project updates.

### Fixed
- Fixed an edge case where tracking suffixed volumes (like `/Volumes/media` -> `/Volumes/media-1`) would fail if resolving the original baseline path back from the suffixed path.
