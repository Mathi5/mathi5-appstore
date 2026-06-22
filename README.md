# mathi5-appstore

Personal [Runtipi](https://runtipi.io) app store. Currently ships:

| App | Version | Description |
|-----|--------:|-------------|
| [crw-shield](./apps/crw-shield) | 0.2.0 | Firecrawl v2-compatible scraper with multi-layer anti-bot bypass |

## Adding this store to Runtipi

1. Open your Runtipi dashboard.
2. Go to **Settings → App Stores → Add App Store**.
3. Paste this URL: `https://github.com/Mathi5/mathi5-appstore`
4. Name it (e.g. `mathi5`) and save.
5. Click **Update App Stores** to pull the latest app list.
6. Install `crw-shield` from the app store.

The crw-shield image is `ghcr.io/mathi5/crw-shield:0.2.0` (linux/amd64 only for now).

## Adding a new app

```text
apps/
└── <app-id>/
    ├── config.json
    ├── docker-compose.yml
    └── metadata/
        ├── description.md
        └── logo.jpg
```

- `config.json` — app metadata ([reference](https://runtipi.io/docs/reference/config-json))
- `docker-compose.yml` — services with `x-runtipi` metadata
  ([reference](https://runtipi.io/docs/reference/dynamic-compose))
- `metadata/description.md` — long description shown in the Runtipi dashboard
- `metadata/logo.jpg` — square 1:1 image (e.g. 512×512)

Run the local validator before pushing:

```bash
pip install -r scripts/requirements.txt
python scripts/validate.py
```

GitHub Actions runs the same validator on every push and PR to `main`.

## Repository conventions

- This is a **private** store. Keep it that way unless the apps here are intended
  for public consumption.
- Apps in this store are not endorsed by the upstream projects they wrap — they
  are configured for personal use (e.g. specific env var defaults, internal
  service URLs).
