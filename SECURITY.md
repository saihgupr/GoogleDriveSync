# Security

## Credentials and configuration

GoogleDriveSync does **not** store OAuth tokens or cloud credentials. All remote credentials are managed by [rclone](https://rclone.org/) in its own config file (typically `~/.config/rclone/rclone.conf`). The app only stores sync folder paths, remote names, and display-name preferences in UserDefaults.

- **Protect rclone’s config:** Restrict access to your home directory and to `~/.config/rclone/`. Anyone with read access to that file can use your configured remotes.
- **Recommendation:** Use full-disk encryption and limit who can run the app or access the terminal session used for `rclone config`.

## App Sandbox

The app runs **without** the macOS App Sandbox. That is intentional so it can:

- Run the rclone subprocess and pass it user-selected folder paths.
- Read and write user-chosen directories and allow rclone to sync them.

We follow least privilege in other ways: input validation, an allowlist for the rclone executable path, and no exposure of tokens in process arguments.

## Update checks

Update checks use the GitHub API over **HTTPS** (`https://api.github.com/...`). The repo URL and User-Agent are set in code; see the app’s configuration for the exact endpoints and identifiers.

## Reporting issues

If you believe you’ve found a security vulnerability, please report it responsibly (e.g. via a private security advisory or contact the maintainers) rather than in a public issue.

- When requesting help, **do not** attach your `rclone.conf` file or unredacted terminal output/logs that may contain tokens or file contents.
- If logs are needed, redact account names, remote names, and any other sensitive details before sharing them in an issue or discussion.

## Security verification checklist (for maintainers)

Before shipping a new release, run this quick security-focused checklist:

- **Process arguments**: Start a sync and open rclone config, then check `ps` or Activity Monitor to confirm that no OAuth tokens or other secrets appear in the `GoogleDriveSync` process command line.
- **Interactive config safety**: Use **Settings → Add Account** to open the interactive rclone config and verify it still works as expected; paths with spaces should behave normally and not break Terminal commands.
- **Path and remote-name validation**: Attempt to add folders or remotes with obviously invalid paths (e.g. containing `..` or control characters) or names (invalid characters), and confirm the UI rejects them cleanly.
- **Update checks**: Trigger a manual update check and confirm that any errors surfaced to the user are high-level (no tokens, no internal URLs) and that logs (in DEBUG builds) do not contain secrets.

