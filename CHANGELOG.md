# Changelog

All notable changes to this project will be documented in this file.

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
