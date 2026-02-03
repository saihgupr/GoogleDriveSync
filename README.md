# GoogleDriveSync

A native macOS menu bar app for syncing local folders with Google Drive.

<p align="center">
  <img src="Images/SCR-20260203-jwxr.jpeg" width="600" style="margin-bottom: 20px;" /><br>
  <table width="100%" style="border: none;">
    <tr>
      <td width="33%" align="center"><img src="Images/Screenshot%202026-02-03%20at%2010.49.20%E2%80%AFAM.png" width="100%" /></td>
      <td width="33%" align="center"><img src="Images/Screenshot%202026-02-03%20at%2010.49.23%E2%80%AFAM.png" width="100%" /></td>
      <td width="33%" align="center"><img src="Images/Screenshot%202026-02-03%20at%2010.49.26%E2%80%AFAM.png" width="100%" /></td>
    </tr>
  </table>
</p>

## Features

- **Menu Bar Integration** - Lives in your menu bar for quick access.
- **Multiple Folder Sync** - Sync as many local folders to Google Drive as you want.
- **Zero Configuration** - No complex setup or external dependencies required.
- **Smart Path Resolution** - Automatically handles macOS mount point changes (e.g., finding `/Volumes/Drive-1` if `/Volumes/Drive` is stuck).
- **Multiple Accounts** - Connect and use multiple Google Drive accounts simultaneously.
- **Automatic Sync** - Configurable sync intervals (manual, 15min, 30min, 1hr, 4hr, daily).
- **Auto-Update** - Automatically checks for new versions on launch.
- **Detailed Error Reporting** - Inspect sync errors directly from the UI.
- **Reliable Backend** - Uses the industry-standard `rclone` engine for robust file transfer.

## Requirements

- macOS 14.0 or later
- Google Drive account

## Installation

### 1. Download

1. Download the latest release from the [Releases page](https://github.com/saihgupr/GoogleDriveSync/releases).
2. Monitor the app for updates (it will auto-check on launch).

### 2. Build from Source (Optional)

1. Open `GoogleDriveSync.xcodeproj` in Xcode.
2. Build and run (⌘R).
3. The app will launch in your menu bar.

### 2. Connect Google Drive

The app needs to authorize with your Google Drive account.

1. Open the app.
2. If no accounts are configured, you will be prompted to run the setup.
3. Follow the terminal prompts to log in to Google Drive.

## Usage

1. Click the cloud icon in your menu bar.
2. Go to **Settings** -> **Add Folder**.
3. **Select Local Folder**: Choose the folder on your Mac you want to upload.
4. **Select Account**: Choose your connected Google Drive account.
5. **Destination Folder**:
   - Leave empty to sync to the root of your Drive.
   - Or type a folder name (e.g., `Backups/Mac`) to keep things organized.
6. Click **Add**.

### Syncing

- **Sync All**: Runs sync for all configured folders.
- **Individual Sync**: Click the `⌄` dropdown on any folder and select **Sync Now**.
- **Progress**: Real-time progress and speed stats are shown in the menu.

### Troubleshooting

- **Red Triangle Icon**: If a sync fails, click the red warning icon in Settings to see the exact error message.
- **Smart Paths**: If you are syncing an external drive and it gets remounted (e.g., `Drive-1`), the app will automatically find the correct volume and continue syncing.

## License

MIT
