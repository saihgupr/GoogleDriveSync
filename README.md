# GoogleDriveSync

A native macOS menu bar app for syncing local folders with Google Drive using rclone.

## Features

- **Menu Bar Integration** - Lives in your menu bar for quick access
- **Multiple Folder Sync** - Sync as many local folders to Google Drive as you want
- **Multiple Google Accounts** - Works with multiple rclone-configured Google Drive remotes
- **Automatic Sync** - Configurable sync intervals (manual, 15min, 30min, 1hr, 4hr, daily)
- **Progress Tracking** - Real-time sync progress with percentage and ETA
- **Quick Actions** - Sync individual folders, open in Finder, or open in Google Drive

## Requirements

- macOS 14.0 or later
- [rclone](https://rclone.org/) (Bundled with the app, no separate installation required)
- Configured Google Drive remote

## Installation

### Configure Google Drive Remote

Since rclone is bundled, you can configure your remote using your system's rclone or the bundled one. The app will respect existing `rclone.conf` files (usually in `~/.config/rclone/rclone.conf`).

If you don't have a remote configured yet, you can do so via terminal:

```bash
# If you have rclone installed via brew
rclone config

```

Follow the prompts to:
1. Create a new remote (choose `n`)
2. Name it (e.g., `your-email@gmail.com`)
3. Select Google Drive as the storage type
4. Complete the OAuth authentication

### Build & Run

1. Open `GoogleDriveSync.xcodeproj` in Xcode
2. Build and run (⌘R)

## Usage

1. Click the cloud icon in your menu bar
2. Go to **Settings** to add folders to sync
3. Click **Add Folder** and select:
   - Local folder to sync
   - Google Drive remote (from rclone config)
   - Remote path on Google Drive
4. Click **Sync All** or use the dropdown menu on individual folders

### Folder Actions

Click the `⌄` dropdown on any folder row to:
- **Sync Now** - Sync this folder immediately
- **Show in Finder** - Open the local folder
- **Open in Google Drive** - Open the folder in your browser
- **Remove** - Remove the folder from sync list

## How It Works

GoogleDriveSync wraps rclone's `sync` command to provide a native macOS experience:

```
rclone sync /local/path remote:path --progress
```

Sync direction is **local → Google Drive** (one-way upload sync).

## License

MIT
