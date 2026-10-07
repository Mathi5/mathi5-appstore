# Firecrawl

**Self-hosted web scraping API: turn any website into clean, LLM-ready markdown.**

Firecrawl exposes a REST API (v2, compatible with the official SDKs) to scrape single pages
(`/v2/scrape`), crawl entire sites (`/v2/crawl`), map site structures (`/v2/map`) and search
the web (`/v2/search`, requires a SearXNG endpoint).

This packaging bundles the five upstream services:

- **api** — the main Node.js service (REST API + workers + extract worker)
- **playwright-service** — headless browser microservice for JS-heavy pages
- **redis** — short-lived queue & rate-limit state
- **rabbitmq** — job queue transport
- **nuq-postgres** — durable queue state (persisted under the app data dir)

## Quick start

After install, grab your API key from the form (auto-generated `TEST_API_KEY`) and call:

```bash
curl -X POST http://<runtipi-host>:<port>/v2/scrape \
  -H "Authorization: Bearer <YOUR_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "formats": ["markdown"]}'
```

Without a key the SDKs still require sending *a* Bearer string; note that
self-hosted Firecrawl (`USE_DB_AUTHENTICATION=false`, this packaging) does
**not** enforce the key server-side — any request is accepted. API protection
is a network-level concern: keep the app on the LAN, or expose it behind
an authenticated reverse proxy.
A Bull board admin UI is available at `/admin/<BULL_AUTH_KEY>/queues`.

## Configuration

| Field | Default | Notes |
|-------|---------|-------|
| API key (`TEST_API_KEY`) | random 24 chars | Bearer token sent by SDKs (NOT enforced server-side in self-hosted mode — the key column only documents the client convention) |
| Bull admin key (`BULL_AUTH_KEY`) | random | Secret path segment for `/admin/<key>/queues` |
| LLM base URL / API key / model | empty | Optional; enables LLM features (extract agent). Point at any OpenAI-compatible endpoint |
| Antibot proxy (`PROXY_SERVER`) | empty | Optional; routes Firecrawl's own fetches (native + Playwright SSRF-proxy chain) through an HTTP proxy. Point it at the **Trawl** app's forward proxy with `http://trawl:8192` (container name + INTERNAL port): Trawl's MITM proxy detects challenges, solves them (Camoufox) and streams the resolved page back. Requires: Trawl's forward proxy enabled, **both** apps' `ALLOW_LOCAL_WEBHOOKS` toggles ON (SSRF guard otherwise kills private-host fetches), Firecrawl scrapes must be called with `skipTlsVerification` (it is the v2 default when no custom headers and no actions are set) since Trawl re-signs certificates. |
| SearXNG endpoint | empty | Optional; enables `/v2/search` via SearXNG instead of the DuckDuckGo fallback. For a SearXNG installed as a Runtipi app use **`http://searxng:8080`** — container name + INTERNAL port (both apps' main services join `tipi_main_network`, so the name resolves; port 8127 is the host-published port and does NOT exist inside the container) |
| SearXNG categories | `general` | Only used when the endpoint is set |
| Max CPU / Max RAM ratio | `0.8` | Worker backpressure: workers refuse new jobs when host CPU or RAM usage exceeds the ratio. Raise to `1` if scrapes stay queued on a busy host |

LLM and search features are strictly optional — scraping, crawling and mapping work without them.

> **Note**: on small hosts you may see `Can't accept connection due to RAM/CPU load`
> in the api logs while the 8 nuq workers start up — that's normal backpressure
> (default threshold: 80 % CPU or RAM). If it never clears and scrapes stay
> queued, raise the Max CPU / Max RAM settings above.

## What's new in 2.11.3 (October 2026 config rev.)

- **New optional field — Antibot proxy (`PROXY_SERVER`)**: point it at the [Trawl](../trawl) app's
  forward proxy (`http://trawl:8192`) to route Firecrawl's fetches through a challenge-solving
  engine (Cloudflare JS, Turnstile, reCAPTCHA…). Firecrawl keeps its markdown/crawl pipeline;
  Trawl hands it the resolved page. Full wiring guide in the Trawl app description.
- **New optional field — SSRF guard release (`ALLOW_LOCAL_WEBHOOKS`)**: needs to be ON when
  `PROXY_SERVER` points at a private-network peer (or when delivering webhooks to LAN IPs).
  Default OFF — keep it that way unless one of the two applies.
- Self-hosted auth doc corrected upstream: with `USE_DB_AUTHENTICATION=false` no Bearer key is
  enforced server-side (protection is network-level — keep the app on the LAN or behind an
  authenticated reverse proxy).

## Upstream images

Pinned from the official Firecrawl GHCR images at the time of packaging (see
`docker-compose.yml` for the exact tags). Bump requests welcome via pull request.