# crw-shield

**Firecrawl v2-compatible scraper with multi-layer anti-bot bypass.**

A Rust HTTP scraper that exposes a Firecrawl v2 API surface (`/v2/scrape`, `/v2/crawl`)
and ships with an anti-bot stack tuned for Akamai, Cloudflare, DataDome, Kasada and
PerimeterX-protected sites.

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

## Performance

Benchmarked on a 30-site panel (3 tiers: 7× L1 unprotected, 12× L2 anti-bot,
11× L3 enterprise CDN). Crw-shield clears **29/30 sites = 96.7%** on cold start,
slightly ahead of [cortex-bridge](https://forgejo.cyrleb.dev/CyrilLeblanc/cortex-bridge)
(28/30 = 93%) on the same panel.

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
- [v0.1.0 release](https://github.com/Mathi5/crw-shield/releases/tag/v0.1.0)
- [cortex-bridge](https://forgejo.cyrleb.dev/CyrilLeblanc/cortex-bridge) — upstream inspiration (MIT)
