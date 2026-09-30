# NeutArr

**Keep your media searches moving — missing media hunter and quality upgrader for your `*arr` stack.**

NeutArr periodically checks your configured apps and triggers searches for:

- missing movies, series, episodes, music, books and other supported media;
- items that have not yet met their configured quality cutoff;
- stalled downloads when Swaparr is enabled.

It works **alongside** your existing stack and uses each app's API to request
searches — it does not replace Sonarr, Radarr, your download client or your
media server. You control how many items are processed, how often it runs and
when each app is allowed to search. Multiple instances of the same app are
supported.

| App | Missing media | Quality upgrades |
|:----|:-------------:|:----------------:|
| Sonarr | Yes | Yes |
| Radarr | Yes | Yes |
| Lidarr | Yes | Yes |
| Readarr | Yes | Yes |
| Whisparr v2 | Yes | Yes |
| Whisparr v3 / Eros | Yes | Yes |
| Swaparr | Stalled-download handling | Not applicable |

## Lineage

NeutArr's code lineage began with Huntarr v6.6.3 (the last clean release before
the original project was abandoned under controversial circumstances) and
continued through ElfHosted's NewtArr fork. This packaging wraps the upstream
project [I-am-PUID-0/NeutArr](https://github.com/I-am-PUID-0/NeutArr) — the
actively maintained continuation — with authentication enabled.

## First-run setup

1. Install the app and open the web UI on the port Runtipi assigns.
2. Enter the **first-run setup token**: either the one you set in the install
   form, or the auto-generated one printed in the app logs (also stored at
   `/config/.setup-token` until account creation). Retrieve it with
   `docker logs <neutarr-container> 2>&1 | grep 'First-run setup token'`.
3. Create your account and choose an authentication mode (local accounts, or
   proxy header auth via the install form's proxy options).
4. Open **Apps**, add each of your `*arr` instances with a name, the
   container-reachable URL and its API key, then use **Test Connection**.
5. Review each app's **Search Settings**, set up **Scheduling** if needed, and
   check **Logs** after the first cycle.

## Reaching your *arr apps from NeutArr

Apps installed from Runtipi (this store or the official one) live on the shared
`tipi_main_network`, so NeutArr can reach them by app name using their
**internal** container ports:

| App | URL to use |
|:----|:-----------|
| Sonarr | `http://sonarr:8989` |
| Radarr | `http://radarr:7878` |
| Lidarr | `http://lidarr:8686` |
| Readarr | `http://readarr:8787` |
| Prowlarr | `http://prowlarr:9696` |

`localhost` / `127.0.0.1` URLs will **not** work — the URL must be reachable
from inside the NeutArr container.

## Security notes

The upstream fork includes a first-run setup token requirement and account
authentication (the original Huntarr's unauthenticated RCE/account-takeover
CVEs are the main reason the lineage forked away). The v6.6.3 base was audited
by ElfHosted — see their
[SECURITY-AUDIT.md](https://github.com/elfhosted/newtarr/blob/main/SECURITY-AUDIT.md)
for the inheritance context; NeutArr continues with auth enabled by default.