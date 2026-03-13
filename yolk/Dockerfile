# LCDactyl Yolk — Wine runtime for Minecraft Legacy Console Edition (MinecraftConsoles)
#
# Based on Debian bookworm-slim. Installs a 32+64-bit Wine stable environment,
# Xvfb, and bakes in a fully initialised Wine prefix with vcrun2022 so container
# startup is instant.
#
# The image is intentionally minimal: no desktop environment, no audio stack.
# The server is run headless via `wine Minecraft.Client.exe -server ...`

FROM --platform=linux/amd64 debian:bookworm-slim

LABEL maintainer="Zephelinn" \
      description="Yolk for running MinecraftConsoles headless server under Pterodactyl (utilizes Wine as a compat layer.)"

# ── System deps ─────────────────────────────────────────────────────────────
RUN dpkg --add-architecture i386 \
 && apt-get update -y \
 && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg2 \
        software-properties-common \
        apt-transport-https \
        unzip \
        xvfb \
        xauth \
        tar \
        jq \
        fontconfig \
        libfontconfig1 \
        cabextract \
 && rm -rf /var/lib/apt/lists/*

# ── Wine stable (WineHQ) ─────────────────────────────────────────────────────
RUN mkdir -pm755 /etc/apt/keyrings \
 && wget -O /etc/apt/keyrings/winehq-archive.key \
        https://dl.winehq.org/wine-builds/winehq.key \
 && echo "deb [signed-by=/etc/apt/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/debian/ bookworm main" \
        > /etc/apt/sources.list.d/winehq.list \
 && apt-get update -y \
 && apt-get install -y --install-recommends winehq-stable \
 && rm -rf /var/lib/apt/lists/*

# ── Winetricks ───────────────────────────────────────────────────────────────
RUN wget -q -O /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
 && chmod +x /usr/local/bin/winetricks

# ── Container user expected by Pterodactyl ───────────────────────────────────
RUN useradd -m -d /home/container -s /bin/bash container

# ── Bake Wine prefix + vcrun2022 into the image ───────────────────────────────
# IMPORTANT: prefix lives in /opt/wine-prefix, NOT /home/container, because
# Pterodactyl mounts the server volume over /home/container on every start,
# which would wipe a prefix stored there.
ENV WINEPREFIX=/opt/wine-prefix \
    WINEARCH=win64 \
    DISPLAY=:99 \
    WINEDEBUG=-all \
    DXVK_LOG_LEVEL=none

RUN mkdir -p /opt/wine-prefix && chown container:container /opt/wine-prefix

RUN Xvfb :99 -screen 0 1024x768x16 -nolisten tcp & \
    sleep 2 && \
    su container -c " \
        WINEPREFIX=/opt/wine-prefix \
        WINEARCH=win64 \
        DISPLAY=:99 \
        WINEDEBUG=-all \
        WINEDLLOVERRIDES='mscoree,mshtml=' \
        wineboot --init && \
        wineserver --wait && \
        WINEPREFIX=/opt/wine-prefix \
        WINEARCH=win64 \
        DISPLAY=:99 \
        WINEDEBUG=-all \
        winetricks -q vcrun2022 && \
        wineserver --wait \
    " && \
    pkill Xvfb || true

# ── Entrypoint script ────────────────────────────────────────────────────────
COPY --chown=root:root entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER container
WORKDIR /home/container

CMD ["/bin/bash", "/entrypoint.sh"]
