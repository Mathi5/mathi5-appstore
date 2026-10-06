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
| SearXNG endpoint | empty | Optional; enables `/v2/search` via SearXNG instead of the DuckDuckGo fallback. Use a **host-port** URL reachable from the app, e.g. `http://<runtipi-host>:<searxng-port>` — container names like `http://searxng:8080` do NOT resolve between apps |
| SearXNG categories | `general` | Only used when the endpoint is set |
| Max CPU / Max RAM ratio | `0.8` | Worker backpressure: workers refuse new jobs when host CPU or RAM usage exceeds the ratio. Raise to `1` if scrapes stay queued on a busy host |

LLM and search features are strictly optional — scraping, crawling and mapping work without them.

> **Note**: on small hosts you may see `Can't accept connection due to RAM/CPU load`
> in the api logs while the 8 nuq workers start up — that's normal backpressure
> (default threshold: 80 % CPU or RAM). If it never clears and scrapes stay
> queued, raise the Max CPU / Max RAM settings above.

## Upstream images

Pinned from the official Firecrawl GHCR images at the time of packaging (see
`docker-compose.yml` for the exact tags). Bump requests welcome via pull request.