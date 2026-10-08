# Dashbrr

**A sleek, modern dashboard for monitoring and managing your media stack.**

Dashbrr gives you a single real-time view over your whole media server
ecosystem, with service health checks and unified management:

| Category | Supported services |
|:---------|:-------------------|
| Media servers | **Plex** (active streams, version), **Jellyfin** (active sessions, play/transcode state, version) |
| Media management | **Sonarr, Radarr, Lidarr, Readarr, Whisparr** (queue visibility, download state, version), **Bazarr** (subtitle backlog, provider status), **Prowlarr** (indexer health, stats), **Overseerr** (pending requests), **Maintainerr** (collection / deletion rules) |
| Downloads | **autobrr** (IRC network health, release stats), **SABnzbd**, **NZBGet**, **Qui** (qBittorrent connectivity and transfer telemetry) |
| Network & infra | **Tailscale** (devices, tags), **Uptime Kuma** (monitor summary), **Traefik** (routers / services / problem routers), plus a **Generic Service** card that renders the top-level fields of any JSON health endpoint |

Data is cached in memory and pushed to the UI live over Server-Sent Events.
The dashboard supports draggable cards and ships a mobile-friendly PWA.

This packaging runs the **official upstream image**
[`ghcr.io/autobrr/dashbrr`](https://github.com/autobrr/dashbrr/pkgs/container/dashbrr)
(linux/amd64 + arm64) with an SQLite database stored in the app's persistent
data directory — no separate PostgreSQL container needed.

## First-run setup

1. Install the app and open the web UI on the port Runtipi assigns.
2. **Register immediately**: registration stays open only until the first
   account exists — whoever registers first controls the instance. Keep the
   app private (LAN or an authenticated reverse proxy) until you have
   registered.
3. Open the settings and add your services: name, URL and API key for each.
   - Apps installed through Runtipi (this store or the official one) are
     reachable by container name with their **internal** ports, e.g.
     `http://sonarr:8989`, `http://radarr:7878`, `http://jellyfin:8096`,
     `http://prowlarr:9696`, `http://overseerr:5055`.
   - Everything else (LAN boxes, bare docker, external APIs): use its
     host/IP + published port.

## Authentication

- **Built-in (default)**: local username/password, registration closes after
  the first account.
- **OpenID Connect (optional)**: fill the OIDC fields in the install form
  (issuer, client ID, client secret, redirect URL). Redirect URL must match
  what your provider expects, e.g. `https://dash.example.com/api/auth/oidc/callback`.

## Notes

- Data (SQLite database) lives under the app data directory:
  `dashbrr.db` in the container's `/data`.
- Logs follow the level chosen at install time (`DASHBRR__LOG_LEVEL`,
  default `info`).