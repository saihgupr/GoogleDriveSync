# GoogleDriveSync

**GoogleDriveSync** is a native macOS menu bar application that syncs local folders to Google Drive using a reliable, zero-configuration workflow.

<p align="center">
  <img src="Images/SCR-20260203-jwxr.jpeg" width="600" /><br>
  <table width="100%" style="border: none;">
    <tr>
      <td width="50%" align="center">
        <img src="Images/Screenshot%202026-02-03%20at%2010.49.20%E2%80%AFAM.png" width="100%" />
      </td>
      <td width="50%" align="center">
        <img src="Images/Screenshot%202026-02-03%20at%2010.49.23%E2%80%AFAM.png" width="100%" />
      </td>
    </tr>
    <tr>
      <td width="50%" align="center">
        <img src="Images/Screenshot%202026-02-03%20at%2010.49.26%E2%80%AFAM.png" width="100%" />
      </td>
      <td width="50%" align="center">
        <img src="Images/Screenshot%202026-02-03%20at%2011.36.49%E2%80%AFAM.png" width="100%" />
      </td>
    </tr>
  </table>
</p>

---

## Features

- **Menu Bar App**  
  Runs entirely from the macOS menu bar for quick access.

- **Multiple Folder Sync**  
  Sync any number of local folders to Google Drive.

- **Zero Configuration**  
  No manual setup, daemons, or external dependencies required.

- **Smart Path Resolution**  
  Automatically handles macOS volume remounts (e.g. `/Volumes/Drive` → `/Volumes/Drive-1`).

- **Multiple Google Accounts**  
  Connect and sync with multiple Google Drive accounts simultaneously.

- **Automatic Sync Scheduling**  
  Manual, 15 min, 30 min, 1 hr, 4 hr, or daily intervals.

- **Auto Updates**  
  Checks for updates automatically on launch.

- **Detailed Error Reporting**  
  View full sync errors directly from the UI.

- **Proven Sync Engine**  
  Powered by `rclone` for reliable and efficient file transfers.

---

## Requirements

- macOS 14.0 or later  
- Google Drive account

---

## Installation

### Download

1. Download the latest release from the [Releases page](https://github.com/saihgupr/GoogleDriveSync/releases).
2. Launch the app — it will automatically check for updates on startup.

---

### Build from Source (Optional)

1. Open `GoogleDriveSync.xcodeproj` in Xcode.
2. Build and run (`⌘R`).
3. The app will appear in the macOS menu bar.

---

## Google Drive Setup

GoogleDriveSync requires authorization to access your Google Drive.

1. Open the app from the menu bar.
2. If no accounts are configured, you will be prompted to begin setup.
3. Follow the terminal-based login flow to authorize your Google account.

---

## Usage

1. Click the cloud icon in the menu bar.
2. Open **Settings** → **Add Folder**.
3. Select a **Local Folder** to sync.
4. Choose a **Google Drive Account**.
5. Set a **Destination Folder**:
   - Leave empty to sync to the Drive root, or
   - Specify a path such as `Backups/Mac`.
6. Click **Add**.

---

### Sync Controls

- **Sync All**  
  Runs sync for all configured folders.

- **Sync Individual Folder**  
  Use the `⌄` dropdown next to a folder and select **Sync Now**.

- **Live Status**  
  View real-time progress, transfer speed, and completion status from the menu.

---

## Troubleshooting

- **Red Warning Icon**  
  Indicates a sync failure. Click the icon in Settings to view the full error message.

- **External Drives**  
  If an external volume is remounted under a different name, the app will automatically locate the correct path and continue syncing.

---

## License

MIT License