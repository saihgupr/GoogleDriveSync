# GoogleDriveSync
<img src="Images/app-icon.png" width="80" align="right" />

**A native macOS menu bar app for seamless Google Drive syncing**

GoogleDriveSync brings Google Drive syncing to your Mac the way it should be. Simple, reliable, and living right in your menu bar. No complex setup, no external dependencies, just sync your folders.

<p align="center">
  <img src="Images/SCR-20260203-jwxr.jpeg" width="700" alt="GoogleDriveSync Menu Bar" />
</p>

<p align="center">
  <img src="Images/Screenshot%202026-02-03%20at%2010.49.20%E2%80%AFAM.png" width="45%" />
  <img src="Images/Screenshot%202026-02-03%20at%2010.49.23%E2%80%AFAM.png" width="45%" />
</p>

<p align="center">
  <img src="Images/Screenshot%202026-02-03%20at%2010.49.26%E2%80%AFAM.png" width="45%" />
  <img src="Images/Screenshot%202026-02-03%20at%2011.36.49%E2%80%AFAM.png" width="45%" />
</p>

## Why GoogleDriveSync?

### Lightweight and Efficient
At just ~4MB, GoogleDriveSync is a fraction of the size of Google's official Drive app (~800MB). No bloat, no unnecessary background processes—just the syncing you need.

### Multiple Google Accounts, One Simple Interface
Sync folders across multiple Google Drive accounts without juggling credentials or switching profiles. Perfect for keeping work and personal files separate, or managing multiple clients.

### Built for macOS
This isn't a cross-platform afterthought—it's a native Mac app designed to work the way Mac apps should. Lives in your menu bar, handles volume remounts gracefully, and just works.

### Zero Configuration
No daemons to configure, no config files to edit, no terminal commands to memorize. Install, authorize, pick your folders, done.

## Features

- **Flexible Folder Syncing** — Sync as many local folders as you need to any path on Google Drive. Mix and match accounts and destinations however you want.

- **Multiple Google Accounts** — Add and manage multiple Google Drive accounts simultaneously. Each folder can sync to a different account.

- **Smart Syncing** — Powered by rclone for reliable, efficient transfers. Set automatic sync intervals from 15 minutes to daily, or trigger manual syncs whenever you need.

- **Handles the Quirks** — Automatically detects when macOS remounts external volumes with different names (like `/Volumes/Drive` → `/Volumes/Drive-1`) and keeps syncing without missing a beat.

- **Real-Time Feedback** — Watch your sync progress live with transfer speeds, file counts, and completion status. Full error reporting when something goes wrong.

- **Auto Updates** — Checks for updates on launch so you're always running the latest version.

## Requirements

- macOS 14.0 or later
- Google Drive account(s)

## Installation

### Option 1: Download (Recommended)

Head to the [Releases page](https://github.com/saihgupr/GoogleDriveSync/releases) and grab the latest version. Launch it and you're ready to go. Updates happen automatically from then on.

### Option 2: Build from Source

If you want to build it yourself:

1. Clone this repo
2. Open `GoogleDriveSync.xcodeproj` in Xcode
3. Hit `⌘R` to build and run
4. The app appears in your menu bar

## Getting Started

### Setting Up Google Drive

First time running GoogleDriveSync? You'll need to authorize access to your Google Drive account(s).

1. Click the cloud icon in your menu bar
2. If no accounts are set up, you'll see a prompt to get started
3. Follow the terminal-based authorization flow to connect your Google account
4. Repeat for any additional accounts you want to add

### Adding Folders to Sync

1. Click the menu bar icon
2. Open **Settings** → **Add Folder**
3. Choose a **Local Folder** you want to sync
4. Pick which **Google Drive Account** to use
5. Set your **Destination Folder** on Drive:
   - Leave it blank to sync to the root of your Drive
   - Or specify a path like `Backups/Mac` or `Projects/2026`
6. Click **Add** and you're done

## Using GoogleDriveSync

**Sync Everything** — Click **Sync All** from the menu bar to run a sync across all your configured folders.

**Sync Individual Folders** — Use the dropdown `⌄` next to any folder and select **Sync Now** to sync just that one.

**Watch It Happen** — The menu bar shows live sync status with progress, transfer speeds, and file counts so you know exactly what's happening.

**Automatic Syncing** — Set up automatic sync intervals in Settings—choose from 15 min, 30 min, 1 hour, 4 hours, or daily. Or keep it manual if you prefer.

## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Support & Feedback

If you encounter any issues or have feature requests, please [open an issue](https://github.com/saihgupr/GoogleDriveSync/issues) on GitHub.

I decided to make this app open-source and free for everyone to use. If you like this project, consider giving it a star ⭐ or making a donation.

---

Built with ❤️ by [Saihgupr](https://github.com/saihgupr) for Mac users.