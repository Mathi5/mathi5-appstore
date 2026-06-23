# crw-shield

**Firecrawl v2-compatible scraper with multi-layer anti-bot bypass.**

A Rust HTTP scraper that exposes a Firecrawl v2 API surface (`/v2/scrape`, `/v2/crawl`)
and ships with an anti-bot stack tuned for Akamai, Cloudflare, DataDome, Kasada,
PerimeterX and Fastly Edge-protected sites.

## What's new in 0.4.1

- **Logs silenced unconditionally** — the cosmetic
  `WS Invalid message: data did not match any variant of untagged enum Message`
  warning from `chromiumoxide_cdp` (Chrome 120+ sends CDP events the parser
  doesn't recognise) was silenced in v0.2.1 via the default `EnvFilter`,
  but `RUST_LOG=info` in docker-compose overrode the default and re-enabled
  the noise. v0.4.1 builds the filter in two steps: honour the user's
  `RUST_LOG` for everything, then force `chromiumoxide=off` and
  `chromiumoxide_cdp=off` on top — the silence is now non-overridable.
- **`skipJs` field now wired** — v0.4.0 silently ignored the Firecrawl v2
  `skipJs` field, so SPA scrapes (YouTube `/watch`, modern client-side
  routes) returned `success=true` with markdown containing only the JS
  bootstrap shell. v0.4.1 adds a `skipJs: bool` field (default `true`, opt
  in to JS rendering via `skipJs: false`) and escalates to headless
  Chromium whenever the caller opts in. Callers wanting YouTube or other
  SPAs to render properly must pass `"skipJs": false`.

## What's new in 0.4.0

- **Self-service HITL solve UI** — when the ladder exhausts and an auto-enqueued HITL
  challenge is created, the server now exposes a minimal HTML form at
  `GET /v2/scrape/hitl/{id}/solve-ui`. Open it in a normal browser, paste the cookies
  you copied from Chrome DevTools (or a JSON array), hit Solve. No SSH, no `curl`,
  no JSON-templating required. The form accepts both `document.cookie`-style output
  (`name=value; name2=value2`) and a raw JSON array of cookie objects.
- **Discord webhook now embeds a clickable solve link** — same `DISCORD_WEBHOOK_HITL_URL`
  env var, but the message now contains a "Solve in browser" link that points at the
  solve UI. Operators on any device that can reach the server can paste cookies
  without ever SSH-ing in.
- **`CRW_PUBLIC_URL` env var** — controls the host used in operator-facing links. The
  default `0.0.0.0:3002` isn't routable from Discord clicks, so set this to the URL
  you actually use in your browser (e.g. `http://192.168.1.42:3002` or
  `https://crw.example.com`). Falls back to `HOST:PORT` when unset.
- **Cookie jar writable-path fallback** — on unprivileged installs (e.g. local dev
  without `/var/lib` root), the cookie persistence now falls back to
  `$XDG_DATA_HOME/crw-shield/cookies.json` instead of failing with a silent
  `Permission denied` every 60s.
- **Test hardening** — HITL integration tests are now serialized with a
  `tokio::sync::Mutex` to fix intermittent 404s under parallel cargo test runners.
- **No breaking changes** — `/v2/scrape`, `/v2/crawl`, `/v2/scrape/hitl/{id}/solve`,
  and the existing form-field schema are unchanged. Existing v0.3 installs can update
  in place.

## What's new in 0.3.0

- **Cookie jar disk persistence** — solved-challenge cookies (`cf_clearance`,
  `__cf_bm`, `dd`, vendor-specific session tokens) now survive container
  restarts. New `CookieJar::save_to_path()` / `load_from_path()` with atomic
  writes (`.tmp` + rename) and on-load expiry filtering. The server seeds the
  shared jar from `/var/lib/crw-shield/cookies.json` at startup and
  snapshots it back every 60 seconds. Override the path via
  `COOKIE_PERSISTENCE_PATH`; empty value = in-memory only.
- **HITL solve endpoint** — `POST /v2/scrape/hitl/:id/solve` accepts
  `{cookies: [{name, value, domain, max_age_secs}]}`, injects them into the
  shared jar, marks the queue entry `solved`, and snapshots to disk
  immediately. Closes the loop on the existing `hitl_enqueue` /
  `hitl_result` pair — previously there was no way to mark an entry solved.
- **Discord webhook notification on HITL** — set `DISCORD_WEBHOOK_HITL_URL`
  to a webhook URL and every auto-enqueued HITL pings the channel with the
  challenge kind, URL, id, and a ready-to-paste `curl` solve command.
  Fire-and-forget (`tokio::spawn`, 5s timeout) so a Discord outage never
  blocks scrapes.

## What's new in 0.2.1

- **Fastly Compute@Edge detection** (LeMonde.fr and other sites migrated in
  2026). The new `providers.fastly_edge_challenge` entry in `providers.toml`
  recognizes the `/_fs-ch-{HASH}/` asset path, the `<title>Client Challenge</title>`
  page, the `loading-error` div, and the "A required part of this site couldn't
  load" message. Previously these returned as `CleanSuccess` with the empty
  challenge page as the markdown — now the ladder correctly escalates to CDP.
  Tokens: `client challenge`, `/_fs-ch-`, `loading-error`, `a required part of
  this site couldn`, `please check your connection, disable any ad blockers`,
  `javascript is disabled in your browser`, `fastly edge`, `fastly compute`.
- **Log noise silenced** — chromiumoxide's `WS Invalid message: data did not
  match any variant of untagged enum Message` warnings (cosmetic, fired on
  every CDP fetch because chromiumoxide doesn't deserialize some standard
  Chrome DevTools Protocol events) are now muted by default via
  `EnvFilter::new("info,chromiumoxide=off,chromiumoxide_cdp=off")` in
  `crates/server/src/main.rs`. Override with `RUST_LOG=info,chromiumoxide=warn`
  to see them again.
- **No breaking changes** — same `/v2/scrape`, `/v2/crawl`, `/hitl/result` API
  and form-field schema. Existing Runtipi installs can update in place.

## What's new in 0.2.0

- **Firecrawl html-extractor integration** (Phase D) — `/v2/scrape` now optionally
  routes article/doc page-types through Firecrawl's `html-extractor` algorithm
  (behind the `firecrawl-extractor` cargo feature, enabled by default in the
  shipped image). Produces **+32.5% bytes / +33% content-quality** vs the v0.1.0
  extractor on a 30-site panel (291 KB total vs 220 KB). Per-site:
  23/30 strict-match wins (mostly GitHub issues / Wikipedia / Reddit / Stack
  Overflow), 4 perimeter-regressions on Akamai/Cloudflare-heavy pages.
- **Situation-aware routing** (Phase D.1) — anti-bot pages skip the v4 path
  entirely (they were never the intended target of html-extractor). Markdown
  equality on these sites is preserved vs v0.1.0.
- **No breaking changes** — `/v2/scrape`, `/v2/crawl`, `/hitl/result` and the
  form-field schema are unchanged. Existing Runtipi installs can update in
  place.

## What it does

- **TLS ClientHello fingerprinting** via `wreq` + BoringSSL — emits byte-perfect Chrome,
  Firefox and Safari TLS handshakes so anti-bot WAFs see a real browser.
- **Behaviour-aware timing** — random jitter on every request, with optional
  `RATE_LIMIT_MIN_MS` / `RATE_LIMIT_JITTER_MS` knobs (default 0/0 = no rate limiting).
- **L0–L3 profile rotation** — when a block is detected, the L2 handler escalates
  through a ladder of 5 browser profiles (chrome_120, chrome_117, chrome_107,
  firefox_117, safari_16_0) before falling back to HITL.
- **Opt-in FlareSolverr escalation** — explicit per-host allowlist
  (`FLARESOLVERR_HOSTS`) so forcing FS globally doesn't regress your
  Cloudflare-comfortable traffic.
- **HITL endpoint** — `/hitl/result` for queueing and consuming human-solved
  challenges. Returns 503 with a queue ticket when the ladder is exhausted.
- **Firecrawl html-extractor** (default-on) — for clean article/doc pages,
  `/v2/scrape` now uses Firecrawl's `html-extractor` for higher-quality main
  content extraction. Anti-bot pages fall back to the v3 extractor.

## Performance

Benchmarked on a 30-site panel (3 tiers: 7× L1 unprotected, 12× L2 anti-bot,
11× L3 enterprise CDN). Crw-shield clears **29/30 sites = 96.7%** on cold start,
slightly ahead of [cortex-bridge](https://forgejo.cyrleb.dev/CyrilLeblanc/cortex-bridge)
(28/30 = 93%) on the same panel. With the Phase D html-extractor, output volume
on successful scrapes rises from 220 KB to 291 KB (+32.5%), with strict content
quality (markdown equality vs Firecrawl) winning on 23/30 sites.

## Configuration

The app asks for the following install-time values:

| Field | Purpose |
|-------|---------|
| **Auth token** | Bearer token for `/v2/scrape` and `/v2/crawl` |
| **FlareSolverr URL** | FlareSolverr endpoint (e.g. `http://flaresolverr:8191`) |
| **FlareSolverr allowlist** | Comma-separated hosts (supports `*.example.com`) |
| **Enable TLS proxy** | Spawns a Go sidecar for byte-perfect TLS handshakes |
| **Public URL** | Operator-facing URL used in Discord solve links (e.g. `http://192.168.1.42:3002`) |
| **Discord webhook URL** | Channel webhook that receives HITL notifications |
| **Rate limit min / jitter** | Per-host throttle, in ms |

Advanced configuration (SearXNG, behavioural simulation, STEALTH_ENABLED,
PROXY_URL, full TLS proxy knob set) is documented in the project README.

## Architecture

- **Single Rust binary** — no embedded Chromium by default. Image is ~1.3 GB
  with the optional `chromiumoxide` driver for JS-heavy sites.
- **Multi-stage Dockerfile** — Go sidecar (`tls-impersonate-proxy`,
  bogdanfinn/tls-client) built in a parallel stage and dropped into the
  runtime image.
- **MIT licensed** with portions derived from cortex-bridge.

## Endpoints

```
GET  /health                  — health check
POST /v2/scrape               — single-URL scrape (Firecrawl v2 schema)
POST /v2/crawl                — multi-URL crawl (async, returns job id)
GET  /v2/crawl/:id            — poll crawl job
POST /v2/scrape/hitl/:id/solve — submit human-solved challenge (JSON)
GET  /v2/scrape/hitl/:id/solve-ui — render the cookie-paste HTML form
POST /v2/scrape/hitl/:id/solve-ui — submit cookies via the form
GET  /v2/scrape/hitl/result?id=<uuid> — poll HITL queue status (returns challenge kind/url/id + status pending|solved)
```

## Links

- [GitHub](https://github.com/Mathi5/crw-shield)
- [v0.4.1 release](https://github.com/Mathi5/crw-shield/releases/tag/v0.4.1)
- [cortex-bridge](https://forgejo.cyrleb.dev/CyrilLeblanc/cortex-bridge) — upstream inspiration (MIT)
