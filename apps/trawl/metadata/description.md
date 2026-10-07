# Trawl

**Self-hosted scraping engine: fetch pages yourself, bypassing JS challenges and captchas.**

TRAWL exposes a FlareSolverr-compatible API (`POST /v1` and `POST /scrape` on port 8191) that
returns the **resolved page content**, not just cookies. Escalation ladder per request:

1. HTTP fetch (plain)
2. HTTP with TLS client impersonation
3. cached browser (Camoufox fingerprint; session cache in memory or Redis)
4. fresh solve in a Camoufox browser (Cloudflare JS, Turnstile, reCAPTCHA, hCaptcha, GeeTest — no paid solver API), optionally escalating through a datacenter (tier 3 proxy field) or residential (tier 4 proxy field) proxy pool

It also serves a native **MCP server** (`/mcp`, opt-in) and an optional challenge-bypassing
**HTTP/HTTPS forward proxy** (port 8192, opt-in) that auto-escalates challenged traffic — the
piece you can point **Firecrawl `PROXY_SERVER`** or Prowlarr at.

## FlareSolverr-compatible usage

Drop-in replacement: point Prowlarr/Jackett/*arr tools at `http://<runtipi-host>:<port>`
(or `http://trawl:8191` container-to-container):

```bash
curl -X POST http://<runtipi-host>:<port>/v1 \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"request.get","url":"https://nowsecure.nl","maxTimeout":60000}'
```

## Using it as Firecrawl's challenge engine

1. In Trawl: enable the forward proxy (form toggle) and keep `MITM_MAX_TIER` at 3.
2. Fetch the CA cert once: `GET http://<trawl-host>:8191/proxy-ca.crt` — it persists under the
   app data dir. Import it into every Firecrawl container (API **and** playwright-service):
   copy to `/usr/local/share/ca-certificates/` and run `update-ca-certificates`, plus set
   `NODE_EXTRA_CA_CERTS` to the cert path for Node/undici.
3. In Firecrawl's form: set **Antibot proxy (PROXY_SERVER)** to
   `http://trawl:8192` (Runtipi apps resolve each other by container name; both mains join
   `tipi_main_network`). Firecrawl then routes its fetches through Trawl, which solves
   challenges and streams the resolved content back — Firecrawl keeps its markdown/crawl pipeline.

> The MITM proxy re-signs HTTPS certificates with its own CA. Only enable the forward proxy on a
> private network (Runtipi LAN), never exposed publicly.

## Configuration

| Field | Default | Notes |
|-------|---------|-------|
| Metrics dashboard | off | token-protected (random 32 chars auto-generated; shown in the install form) |
| Forward proxy (`MITM_ENABLED`) | off | turn on only when routing Firecrawl/Prowlarr through it; import the CA (above) |
| MITM max tier | 3 | escalation cap of the forward proxy (4 = residential, only if configured) |
| Browser pool size | 1 | warm Camoufox instances; each ~500 MB RAM on solve — raise only for concurrent solves |
| Content processes / browser | 2 | keeps a solve burst under ~1.5 GB RAM |
| Tier 3 datacenter proxy | empty | optional HTTP/SOCKS5 upstream proxy (pool: comma-separated) |
| Tier 4 residential proxy | empty | most self-hosts never need it (a clean residential fixed IP passes IP reputation) |
| Session cache driver (`SESSION_CACHE_DRIVER`) | `memory` | sessions cleared on restart → fresh solve on demand (cheap, a few seconds); set `redis` + `REDIS_URL` (another Runtipi Redis app's `redis://<container>:6379`) for cross-restart persistence |
| MCP endpoint | off | enable to give MCP clients (Hermes, OpenWebUI…) scraping tools on `/mcp` |
| Log level | `info` | error / warn / info / debug / silent |

Defaults are tuned for a small homelab box (1 warm browser, 2 content processes, memory cache,
dashboard and MITM off). A solved page typically takes a few seconds at tier 2-3; allow up to
~60 s on first solve of a hard target.

## Not solved by any ladder

Blocks happen at the **IP level** (Cloudflare 1020 / bare 403 per-IP rate limits). Trawl fixes
fingerprint layers only; that is what the tier 3/4 proxy fields are for. It handles supported
JS challenges and captchas — no tool guarantees a bypass.

## Upstream image

`ghcr.io/germondai/trawl:1.7.0` (linux/amd64 + arm64), pinned from the upstream release
[v1.7.0](https://github.com/germondai/trawl/releases/tag/v1.7.0). Bump requests welcome via PR.