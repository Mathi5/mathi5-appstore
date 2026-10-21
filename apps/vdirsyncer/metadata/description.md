# vdirsyncer — Google Calendar / Contacts ⇄ CalDAV / CardDAV

Two-way sync between your **Google Calendar** and **Google Contacts** and any self-hosted
CalDAV/CardDAV server (Nextcloud, Baïkal, Radicale).

Point your phone's agenda and address book at the self-hosted server, and let vdirsyncer replicate
every change to Google and back — no Google app, no account sharing.

## What this app is

A headless worker running [vdirsyncer](https://github.com/pimutils/vdirsyncer) 0.21.0, packaged with
the **`google` extra** so the `google_calendar` and `google_contacts` storages are available.

> **Why a custom image?** The `google` extra (`aiohttp-oauthlib`) is what the `google_calendar` and
> `google_contacts` storages import. Most published vdirsyncer images do **not** carry it:
>
> | Image | vdirsyncer | `aiohttp_oauthlib` | Multi-arch |
> |---|---|---|---|
> | `iocanel/vdirsyncer` | — | image gone (404) | — |
> | `bfin/vdirsyncer` | — | arm64-only, cannot run on x86 | arm64 |
> | `johannweging/vdirsyncer` | 0.16.2 | **missing** | amd64 |
> | `robvred/vdirsyncer` | 0.16.7 | **missing** | amd64 |
> | `zeonin/vdirsyncer` | 0.18.0 | **missing** (Nix build) | amd64 |
> | `davralin/vdirsyncer` | 0.19.3 | **missing** | amd64 |
> | `bleala/vdirsyncer:2.7.0` | 0.21.0 | **present** | amd64 + arm64 |
>
> Upstream's own documentation for these storages requires `pip install vdirsyncer[google]`.
>
> The image also **generates the vdirsyncer config from this app's form fields**, so the Runtipi
> install form is the only thing to fill in. The upstream images expect a hand-written config file.
>
> Built from `github.com/Mathi5/mathi5-appstore` (`images/vdirsyncer/`), published to GHCR as
> `ghcr.io/mathi5/vdirsyncer-runtipi`.
>
> **Alternative:** `bleala/vdirsyncer:2.7.0` is a public, pinnable, multi-arch image that also ships
> the `google` extra — it injects `aiohttp-oauthlib` into its pipx venv. Use it if you prefer to
> write the vdirsyncer config by hand: it expects the config at `/vdirsyncer/config` and reads
> `VDIRSYNCER_CONFIG`, `AUTODISCOVER`, `AUTOSYNC` and `CRON_TIME`.

## How the sync works

Each pair syncs exactly **two** storages:

```text
Google Calendar  ←→  your CalDAV server
Google Contacts  ←→  your CardDAV server
```

Your phone talks to the CalDAV server directly; vdirsyncer is the bridge that keeps Google and
your server identical in both directions.

## Before you install: you need a CalDAV/CardDAV server

This app does **not** provide the server. Pair it with one of:

- **Nextcloud** — official Runtipi app (`nextcloud`), with the Calendar and Contacts apps enabled
  in the Nextcloud app store. DAV URLs: `https://<domain>/remote.php/dav/`
- **Baïkal** — official Runtipi app (`baikal`), a lightweight CalDAV+CardDAV server.
  DAV URL: `https://<domain>/dav/`
- **Radicale** — not in any app store yet; it would have to be added to your own store.

## Setup

### 1. Create the Google OAuth credentials

1. Open the [Google API Manager](https://console.developers.google.com) and create a project.
2. In that project, enable the **CalDAV** API and the **CardDAV** API. These are the ones to enable —
   *not* the "Calendar" and "Contacts" APIs, which are different and will not work.
3. Configure the OAuth consent screen.
4. Create an **OAuth Client ID** of type **Desktop application**. A "Web application" client no
   longer works (upstream changed this in v0.19.2, issue #1078).
5. Copy the **Client ID** and **Client secret** into the app's install form.

### 2. Fill the install form

- **CalDAV server URL** — e.g. `https://cloud.tipi.lan/remote.php/dav/`
- **CalDAV username / password** — on Nextcloud, use an **app password**
  (Settings → Security → App passwords), not your account password.
- **CardDAV server URL**, **username** and **password** — same server, same credentials.
- Leave the CalDAV fields empty to sync **only** contacts, or the CardDAV fields to sync **only**
  the calendar.

### 3. Authorize against Google (one time)

The Google OAuth flow starts when the container runs `vdirsyncer discover`. The redirect lands on
`http://127.0.0.1:<port>` **inside the container**, so the browser that finishes the sign-in has to
reach it through a tunnel.

On the Runtipi host:

```sh
docker exec -it <vdirsyncer-container> /usr/local/bin/entrypoint.sh discover
```

The command prints a Google authorization URL and the port it listens on:

```
>>> Forward this port to complete the sign-in:
>>> ssh -L 49513:127.0.0.1:49513 <user>@192.168.1.101
```

From your machine (or through that tunnel), open the printed URL, authorize, and Google redirects
to the loopback port. The token is written to `config/google_token` in the app data directory and
the flow never repeats.

> You can also run the discovery by hand from the Runtipi dashboard's container console.

### 4. Let it run

Once the token exists, the container syncs on startup and then every **Sync interval**
(default: 3600 s = hourly). Google rate-limits CalDAV reads, so keep the interval at 5 minutes or
more.

Check the logs from the Runtipi dashboard to follow the sync passes.

## Google caveats

These are upstream's, not ours — read them before you rely on the sync:

- **Google's CardDAV implementation is "a disaster in terms of data safety"** (upstream cites
  [evertpot.com](https://evertpot.com/google-carddav-issues/)). **Always back up your contacts.**
- Google **group labels** are not synced to the vCard `CATEGORIES` property.
- A `BDAY` with partial information (e.g. year missing) is not synced.
- `VTODO` files are rejected by Google's calendar server, so tasks do not sync.
- The calendars Google offers to vdirsyncer are controlled by a private settings page —
  [calendar.google.com/calendar/syncselect](https://calendar.google.com/calendar/syncselect).
  Select the calendars you want to expose there.

## Configuration

| Variable | Purpose |
|---|---|
| `VDIRSYNCER_GOOGLE_CLIENT_ID` | OAuth client ID (Desktop application). |
| `VDIRSYNCER_GOOGLE_CLIENT_SECRET` | OAuth client secret. |
| `VDIRSYNCER_CALDAV_URL` | CalDAV base URL. Empty = no calendar pair. |
| `VDIRSYNCER_CALDAV_USERNAME` / `_PASSWORD` | CalDAV credentials. |
| `VDIRSYNCER_CARDDAV_URL` | CardDAV base URL. Empty = no contacts pair. |
| `VDIRSYNCER_CARDDAV_USERNAME` / `_PASSWORD` | CardDAV credentials. |
| `VDIRSYNCER_INTERVAL` | Seconds between sync passes. Default 3600. |
| `VDIRSYNCER_CONFIG_DIR` | Where the config and the token live. `/config`. |
| `VDIRSYNCER_STATUS_PATH` | vdirsyncer's per-pair status. `/data/status`. |

The generated config file is at `config/config` in the app data directory — edit it directly if you
need finer control (conflict resolution, `metadata`, per-collection selection), then restart the
app. **Note that the app rewrites the file from the form fields on every start**, so keep custom
changes in the form fields or accept that they are overwritten.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `aiohttp-oauthlib not installed` | Wrong image. This app ships the `google` extra — check the app's image tag. |
| `No Google token yet` | Run the `discover` command (see step 3). |
| The authorization URL opens but Google says "redirect mismatch" | The Google OAuth client is a "Web application" instead of a "Desktop application". Recreate it. |
| `Could not find a valid collection` | The CalDAV URL is wrong or the credentials are rejected. On Nextcloud the path is `/remote.php/dav/`. |
| Contacts missing after the first sync | Check the CalDAV/CardDAV *collection* selection in the generated config; run `discover` again after changing it. |

## Links

- vdirsyncer: https://github.com/pimutils/vdirsyncer
- Documentation: https://www.vdirsyncer.pimutils.org/en/stable/config.html
- Google tutorial: https://www.vdirsyncer.pimutils.org/en/stable/tutorials/google.html
- This image: https://github.com/Mathi5/mathi5-appstore/tree/main/images/vdirsyncer
- Alternative image: https://github.com/Bleala/Vdirsyncer-DOCKERIZED
