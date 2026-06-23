# crw-shield

**Firecrawl v2-compatible scraper with multi-layer anti-bot bypass.**

A Rust HTTP scraper that exposes a Firecrawl v2 API surface (`/v2/scrape`, `/v2/crawl`)
and ships with an anti-bot stack tuned for Akamai, Cloudflare, DataDome, Kasada,
PerimeterX and Fastly Edge-protected sites.

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
POST /hitl/result             — submit human-solved challenge
```

## Links

- [GitHub](https://github.com/Mathi5/crw-shield)
- [v0.2.1 release](https://github.com/Mathi5/crw-shield/releases/tag/v0.2.1)
- [cortex-bridge](https://forgejo.cyrleb.dev/CyrilLeblanc/cortex-bridge) — upstream inspiration (MIT)
