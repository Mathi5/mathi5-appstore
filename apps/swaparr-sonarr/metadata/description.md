# Swaparr (Sonarr)

**Headless stalled-download cleaner for Sonarr** — one watcher targeting one
Sonarr instance.

Swaparr quietly operates in the background: it scans your Sonarr's active
downloads every `SCAN_INTERVAL`, flags slow or stalled ones with a strike
system, and automatically removes them (optionally from the download client
too) after `MAX_STRIKES`.

- No web UI by design — configuration happens in the install form, activity
  is visible in the app logs (`docker logs` or the Runtipi log view).
- Runs as a companion container next to the other Runtipi apps; it talks to
  your Sonarr over the shared Runtipi network.
- `DRY_RUN` sandbox mode lets you watch first cycles with zero destructive
  action — recommended first: keep it ON (set at install), check the logs,
  then re-configure with it OFF.

## Pairing

Watchers are per-instance (upstream's own compose ships a container per app).
Install it alongside **Swaparr (Radarr)** from the same store to cover both
your Sonarr and Radarr, each with its own settings.

## Pointing at the right Sonarr

The URL must be reachable **from the Swaparr container**:

- prefer the container name + **internal** port: `http://sonarr:8989`
  (apps from Runtipi stores reach each other over `tipi_main_network`);
- or a LAN IP + **host** port: `http://192.168.1.10:8098`.

`localhost` / `127.0.0.1` will **not** work. Get the API key in
Sonarr → Settings → General → API Key.

## First start notes

On startup Swaparr validates the connection: a wrong URL gives
"A connection to the sonarr API could not be established", a wrong key gives
"The provided APIKEY is not valid" — fix the form and restart the app. When
the queue is clean you will see "No downloads found" and a re-check every
scan interval.