# Google Drive onboarding: findings and improvement ideas

Filed 2026-11-08 after a first install required falling back to the rclone CLI (creating a Google OAuth client and passing client_id/client_secret by hand).

## What actually happens today

`RcloneWrapper.createDriveAccount` runs:

```
rclone config create <name> drive scope drive config_is_local true --non-interactive
```

Reproduced against a scratch config with the bundled rclone v1.76.0:

1. rclone does **not** start OAuth. `--non-interactive` makes it return the next question as JSON and exit 0.
2. The question returned is `client_id_warning`: "rclone's shared Google Drive client_id is being retired and will stop working during 2026. Create your own." Default answer: No.
3. A remote is written with only `type = drive` and `scope = drive`. No token.
4. The app checks `exitCode == 0`, treats this as success, refreshes remotes, and shows the account as connected. The first sync then fails with an auth error.

Even if the warning were answered, the next non-interactive state asks the user to paste a token from `rclone authorize`; the app never handles that either. So the "in-app OAuth flow" added in 1.1.3 cannot complete on current rclone. Upstream issue #11 (`Error 401: invalid_client`) is the same family of failure, from the retired shared client.

## Constraints worth knowing

- **Shared rclone client ID is going away in 2026.** Every Google Drive user of this app will need their own OAuth client, or the app needs to ship one.
- **Shipping an app-owned client is hard for an open-source project.** The `drive` scope is a Google "restricted" scope; publishing to production requires a security assessment. The narrower `drive.file` scope avoids that but only sees files the app created, which breaks bisync against existing Drive folders. An "External / Testing" consent screen caps at 100 test users and issues refresh tokens that **expire after 7 days**.
- **Google "Testing" status bites BYO users too.** If a user leaves their own consent screen in Testing, their sync silently dies a week later. The wizard must tell them to set the publishing status to "In production" (no verification needed for personal use; Google shows an "unverified app" interstitial once).
- rclone's `client_secret` for a desktop app is not actually secret per Google's installed-app model, but it and the token sit in plaintext in `~/.config/rclone/rclone.conf`.

## Improvement ideas, roughly in priority order

### 1. Fix the account-creation flow (bug)
Drive rclone properly instead of firing one `--non-interactive` command:
- Run `rclone authorize drive <client_id> <client_secret>` (or no args for the shared client). rclone opens the browser, serves the localhost callback itself, and prints the token JSON between `--->` and `<---` on stdout.
- Then `rclone config create <name> drive client_id=<id> client_secret=<secret> scope=drive token=<json> --non-interactive`. With a client_id supplied, the retirement warning doesn't fire.
- Alternative: run the rclone state machine explicitly (`--continue --state … --result …`) or talk to `rclone rcd` over the RC API (`config/create` with `opt.nonInteractive`). More code, more control.
- **Verify before declaring success**: run `rclone about <name>:` or `rclone lsjson <name>: --max-depth 0`. Only mark the account connected when that returns 0. Surface stderr otherwise.

### 2. Bring-your-own OAuth client in the Add Account sheet
- Add Client ID and Client Secret fields. Validate the ID ends in `.apps.googleusercontent.com`.
- A collapsible "How to get these" panel with the exact Google Cloud Console steps: new project, enable Google Drive API, OAuth consent screen (External), add yourself as a test user, **set publishing status to In production**, Credentials, Create OAuth client ID, type Desktop app. Buttons that open each console page directly.
- Keep the shared client as an "advanced, may stop working" fallback until rclone removes it.

### 3. Make the wizard a real wizard
Steps: Name, Credentials, Sign in (spinner, cancel, 2-minute timeout, "browser didn't open? copy this link"), Verify (list Drive root, show account email from `rclone about` / `lsjson`), Done. Each step explains what's happening and why.

### 4. Import existing rclone remotes explicitly
The app already lists remotes from `rclone.conf`. Make that a first-class path: "I already use rclone" shows discovered drive remotes and runs the verify step on each. Also offer a "paste token from `rclone authorize` run elsewhere" fallback for headless/advanced setups.

### 5. Token and connection health
- Before each scheduled sync, do a cheap `rclone about` check. On 401/invalid_grant, mark the account "Needs reconnect" in the menu bar and offer a one-click re-auth rather than failing every folder.
- Detect the 7-day Testing-mode expiry pattern (token works, then invalid_grant exactly a week later) and show the "set consent screen to production" hint.

### 6. Secrets hygiene
- Store client_secret and tokens in an rclone config encrypted with `rclone config encryption set`; keep the config password in the macOS Keychain and pass it via `RCLONE_CONFIG_PASS` in `ProcessRunner`'s environment.
- Stop passing the token on the command line in `renameRemote` (visible in `ps`); use `rclone config update` reading from stdin, or copy the config section directly.

### 7. Diagnostics
A "Connection log" in Settings showing the last rclone stdout/stderr for auth and sync. Most support threads upstream are users guessing at errors the app swallowed.

### 8. Longer term: an app-owned client
If the project ever wants true zero-config, the maintainer registers a Google OAuth client, goes through the restricted-scope verification for `drive`, and ships the client ID in the app. Until then, BYO client is the honest default, and the README should say so.

## Status

- 2026-11-09: items 1 and 2 implemented on branch `onboarding-ideas` (`DriveAccountConnector`, `AddAccountSheet`, `RcloneWrapper.authorizeDrive/createDriveAccount/verifyRemote`). `renameRemote` was also fixed to copy every stored key, since the old version dropped `client_id`/`client_secret` and would have broken BYO accounts on rename. The exact `--non-interactive` answers that reach the terminal state are `config_refresh_token=false`, `config_change_team_drive=false`, and (shared client only) `config_shared_client_id=true`.
- Items 3 to 8 remain open. Item 6's "token on the command line" note still applies to `createDriveAccount` and `renameRemote`.

## Suggested first PR
Items 1 and 2 together: fields for client ID/secret, `rclone authorize` driven flow, verify step, real error surfacing. That alone turns a silent failure into a working onboarding. Worth offering upstream (saihgupr/GoogleDriveSync) since it fixes their #11.
