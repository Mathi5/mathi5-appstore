# vdirsyncer with the `google` extra (aiohttp-oauthlib), pinned to a known-good version.
#
# Why not a public image: every public vdirsyncer image we audited ships WITHOUT
# the `google` extra, so the `google_calendar` / `google_contacts` storages raise
# "aiohttp-oauthlib not installed" at runtime. The upstream project's own
# docs for the Google storages require that extra.
#
# Built and published from this repo's release workflow to GHCR.

FROM python:3.13-slim

ARG VDIRSYNCER_VERSION=0.21.0

# ca-certificates: the CalDAV/CardDAV and Google endpoints need the trust store.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# `google` extra pulls aiohttp-oauthlib, which the Google storages import.
RUN pip install --no-cache-dir "vdirsyncer[google]==${VDIRSYNCER_VERSION}"

# Run as a non-root user; the data and config directories are owned by it.
RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin vdirsyncer

COPY --chown=vdirsyncer:vdirsyncer entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER vdirsyncer
WORKDIR /home/vdirsyncer

# The config file and the OAuth token file live in /config. Both are
# bind-mounted from the host so the Google token survives a container rebuild.
# The image declares /data too, so the status path exists even when the app
# is run without a volume (the image runs as a non-root user and cannot
# create a missing mount point itself).
ENV HOME=/home/vdirsyncer \
    XDG_CONFIG_HOME=/home/vdirsyncer/.config \
    XDG_DATA_HOME=/home/vdirsyncer/.local/share \
    XDG_CACHE_HOME=/home/vdirsyncer/.cache \
    VDIRSYNCER_CONFIG_DIR=/config \
    VDIRSYNCER_STATUS_PATH=/data/status

RUN mkdir -p /config /data/status && chown -R vdirsyncer:vdirsyncer /config /data

VOLUME ["/config", "/data"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sync"]
