# rclone

## Your cloud drive, and your backup destination

rclone synchronises and backs up files between your machines and **40+ cloud providers**:

- **Google Drive**, **Dropbox**, **OneDrive**, **pCloud**, **Proton Drive**, **HiDrive**, **iCloud Drive**
- **Backblaze B2**, **Amazon S3** and any S3-compatible storage (MinIO, Cloudflare R2, Wasabi,
  Scaleway, OVHcloud, Storj, Mega…)
- **WebDAV** (so any CalDAV/CardDAV or WebDAV server works too), FTP, SFTP, SMB, WebDAV-compatible
  servers such as Nextcloud
- and ~30 more (see `rclone help backends` inside the app)

This app covers two needs that have no single tool:

1. **A personal cloud drive on the server** — point a remote at Google Drive or S3 and the server
   reads and writes your files.
2. **A backup destination for your browser profiles** — push Firefox and Zen profiles to a remote
   with `rclone sync` (see the profile backup recipe below).

It also **exposes any remote over WebDAV** (`rclone serve webdav`), so other apps — or a phone — can
mount your cloud as a normal WebDAV drive.

## ⚠️ Configuration is done with `rclone config`, not with form fields

rclone's providers each need their own credentials, and the OAuth dance differs per provider, so
the install form only holds the *paths and the WebDAV options*. The remote definitions themselves
live in an `rclone.conf` file that you create yourself.

### Creating the config

Open the app's **container console** from the Runtipi dashboard and run:

```sh
rclone config
```

It asks for the provider (`n` for a new remote, then the provider name), the name you want to give
the remote (e.g. `gdrive`), and the credentials. For Google Drive:

```
n          # new remote
drive      # provider
gdrive     # name
           # leave the client_id empty for the default
           # leave the client_secret empty for the default
y          # accept the browser-based auth
```

The browser-based auth prints a URL and waits for the callback. Run it **from the container**:

```sh
rclone config reconnect gdrive:
```

If the container cannot reach the callback, do the same on your own machine with the same config
file and copy the resulting `rclone.conf` into the app's data directory.

The config lives in the app data directory (`config/rclone.conf` inside the container) and holds the
OAuth tokens — **keep it on a volume and back it up**.

### Checking it worked

```sh
rclone listremotes
rclone lsd gdrive:
rclone about gdrive:
```

## Exposing a remote over WebDAV

Set **Remote to serve over WebDAV** at install time (e.g. `gdrive`) and fill the user and password.
After restarting the app:

```sh
curl -u user:pass -X PROPFIND https://<your-runtipi-domain>/
```

or mount it from a phone or a desktop:

```sh
# Linux (davfs2)
sudo mount -t davfs https://<your-runtipi-domain>/ /mnt/cloud
```

> The WebDAV server is served by Runtipi's Traefik over HTTPS. Firefox and iOS refuse plain HTTP
> for WebDAV, so use the HTTPS address.

## Using it for backups

The container is driven with `docker exec` from the Runtipi dashboard console. A scheduled backup
of a browser profile looks like this:

```sh
# Firefox — the whole profile, minus the regenerable caches
rclone sync /path/to/.mozilla/firefox gdrive:backups/firefox \
  --exclude 'cache2/**' --exclude 'startupCache/**' --exclude 'shader-cache/**' \
  --exclude 'crashes/**' --exclude 'minidumps/**' --exclude 'thumbnails/**' \
  --exclude 'lock' --exclude '.parentlock'

# Zen Browser
rclone sync /path/to/.zen gdrive:backups/zen \
  --exclude 'cache2/**' --exclude 'startupCache/**' --exclude 'shader-cache/**' \
  --exclude 'crashes/**' --exclude 'minidumps/**' --exclude 'thumbnails/**' \
  --exclude 'lock' --exclude '.parentlock'
```

**Close the browser before the backup** — SQLite files (`places.sqlite`, `cookies.sqlite`,
`logins.json`) are only consistent when the browser is not writing to them.

### Restoring

```sh
# 1. Pull the profile back
rclone copy gdrive:backups/zen "$HOME/.zen/restored" --progress

# 2. Point the browser at the restored folder, either by editing profiles.ini
#    (Firefox) or by starting the browser with the profile path:
zen --profile "$HOME/.zen/restored"     # Firefox: firefox --profile "$HOME/.mozilla/firefox/restored"

# 3. Copy profiles.ini next to the restored folder so the browser lists it:
cp "$HOME/.zen/profiles.ini" "$HOME/.zen/profiles.ini.bak"
```

A `tar` snapshot is an equally good backup, and restores in one step:

```bash
# backup
tar czf ~/profil-$(date +%F).tar.gz -C "$HOME/.zen" <profil>-release
# restore
tar xzf ~/profil-2026-10-21.tar.gz -C "$HOME/.zen"
```

### What to back up

The whole profile directory is the safe answer. The critical files if you want to be selective:

| Data | Files |
|---|---|
| Bookmarks, history, downloads | `places.sqlite` (+ `-wal`/`-shm`), `bookmarkbackups/`, `favicons.sqlite` |
| **Passwords** | `logins.json` + `logins-backup.json` + **`key4.db`** — the key is useless without the JSON, and vice versa |
| Cookies | `cookies.sqlite` (+ `-wal`), `webappsstore.sqlite` |
| Extensions | `extensions/`, `extensions.json`, `addons.json`, `extension-store/`, `storage/`, `storage-v2/` |
| Certificates | `cert9.db`, `pkcs11.txt` |
| Preferences | `prefs.js`, `user.js`, `search.json.mozlz4`, `handlers.json`, `containers.json`, `xulstore.json` |
| Sessions | `sessionstore-backups/`, `sessionstore.jsonlz4` (Zen: `zen-sessions.jsonlz4`) |
| UI customisation | `chrome/` (userChrome.css) |
| Zen specific | `zen-themes.json` (your Mods), `zen-sessions.jsonlz4` |

Regenerable, skip them: `cache2/`, `startupCache/`, `shader-cache/`, `crashes/`, `minidumps/`,
`thumbnails/`, `storage/temporary/`, `lock`, `.parentlock`.

> `key3.db` only exists on pre-2019 profiles. `key4.db` is the current one and is enough.

Profile locations (confirmed against the official Zen FAQ, which tells you to look in `~/.zen/`):

- **Firefox** — `~/.mozilla/firefox/<profile>/` (Snap: `~/snap/firefox/common/.mozilla/firefox/`),
  plus `profiles.ini` and `installs.ini` at the root.
- **Zen** — `~/.zen/<profile>/`, the profile folder carrying the `(release)` suffix.
  Flatpak: `~/.var/app/app.zen_browser.zen/zen/`.

Find the active one in `about:profiles`.

> **Sync is not a backup.** Firefox Sync does not carry cookies, installed extensions, local
> preferences or open sessions — you still need a file-level backup for those.

## Bookmarks: floccus, for a continuous sync

A file-level backup is a snapshot. To keep **bookmarks** in sync continuously between your
browsers and a server, use **floccus**:

- Extension page: https://addons.mozilla.org/addon/floccus/
- Repository: https://github.com/floccusaddon/floccus (MPL-2.0, release **v5.11.1**, last commit
  2026-10-18)

It works with **Firefox and Zen Browser** — Zen installs the same AMO extensions, and floccus is a
plain WebExtension. Backends: Nextcloud Bookmarks, Linkwarden, KaraKeep, Google Drive, Dropbox, Git
and any generic WebDAV server.

```sh
# floccus against the WebDAV server this app exposes
# (server URL: https://<your-runtipi-domain>/, user and password from the install form)
```

floccus only synchronises **bookmarks** (and tabs) — passwords, cookies, history and the rest of
the profile still need the file backup above.

## Configuration

| Variable | Purpose |
|---|---|
| `RCLONE_CONFIG` | Path to the rclone config file. `/config/rclone.conf`. |
| `RCLONE_SERVE_REMOTE` | Remote to expose over WebDAV. Empty = no WebDAV server. |
| `RCLONE_SERVE_PORT` | WebDAV port. Default 5572. |
| `RCLONE_SERVE_USER` / `RCLONE_SERVE_PASS` | WebDAV credentials. |
| `RCLONE_SERVE_PATH` | Directory inside the remote to expose. Empty = the whole remote. |

## Notes and limits

- The app exposes a **WebDAV server**, not a web UI. The dashboard is the rclone container console.
- rclone's own `serve` commands (`http`, `ftp`, `sftp`, `webdav`) are all available from the console.
- rclone is a **one-way** synchronisation tool by design: `sync` makes the destination match the
  source and **deletes** what is extra at the destination. Use `copy` if you must not delete
  anything.
- rclone v1.75.x requires a config file per remote; the Runtipi form fields only configure the
  WebDAV side and the paths.

## Links

- Website: https://rclone.org
- Documentation: https://rclone.org/docs/
- Supported backends: https://rclone.org/overview/
- GitHub: https://github.com/rclone/rclone
