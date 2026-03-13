#!/bin/bash
# LCDactyl entrypoint — runs inside the Pterodactyl container.
# Pterodactyl automatically injects: SERVER_IP, SERVER_PORT, etc.

export WINEPREFIX=/home/container/.wine
export WINEARCH=win64
export DISPLAY=:99

# Suppress Wine internals noise.
export WINEDEBUG=-all
export DXVK_LOG_LEVEL=none
export VKD3D_DEBUG=none

# Fontconfig writable cache
export XDG_CACHE_HOME=/home/container/.cache
mkdir -p /home/container/.cache/fontconfig

# Silence PulseAudio/ALSA
export PULSE_RUNTIME_PATH=/home/container/.pulse
export XDG_RUNTIME_DIR=/home/container/.runtime
mkdir -p /home/container/.pulse /home/container/.runtime
export AUDIODEV=null
export ALSA_CONFIG_PATH=/dev/null
export SDL_AUDIODRIVER=dummy
export WINEDLLOVERRIDES="winealsa.drv=d;wineoss.drv=d;winemci=d"

# ── Restore Wine prefix if wiped by Pterodactyl volume mount ─────────────────
if [ ! -f "${WINEPREFIX}/system.reg" ]; then
    echo "[LCDactyl] Restoring Wine prefix from image template..."
    cp -a /opt/wine-template /home/container/.wine
    echo "[LCDactyl] Wine prefix restored."
fi

# ── Start virtual display ─────────────────────────────────────────────────────
Xvfb :99 -screen 0 1024x768x16 -nolisten tcp 2>/dev/null &
sleep 1

# ── Write server.properties ───────────────────────────────────────────────────
# SERVER_PORT is injected by Pterodactyl Wings from the server's allocation.
# -port on the CLI is also required: g_Win64DedicatedServerPort defaults to 25565
# and takes precedence over server.properties when > 0, so without -port the
# server always binds 25565 regardless of what's in server.properties.
cat > /home/container/server.properties << EOF
server-ip=0.0.0.0
server-port=${SERVER_PORT:-25565}
max-players=${LCE_MAX_PLAYERS:-8}
difficulty=${LCE_DIFFICULTY:-1}
gamemode=${LCE_GAMEMODE:-0}
pvp=${LCE_PVP:-true}
EOF
echo "[LCDactyl] server.properties -> port=${SERVER_PORT:-25565} max-players=${LCE_MAX_PLAYERS:-8}"

# ── Verify the executable exists ──────────────────────────────────────────────
if [ ! -f "/home/container/Minecraft.Client.exe" ]; then
    echo "[LCDactyl] ERROR: Minecraft.Client.exe not found. Did the install script complete?"
    exit 1
fi

# ── Graceful shutdown handler ─────────────────────────────────────────────────
# Pterodactyl sends SIGTERM on stop. Forward SIGINT to Wine (triggers the
# Windows Ctrl+C handler -> HaltServer -> world save), wait up to 20s,
# then force kill wineserver so the container exits cleanly.
cleanup() {
    echo "[LCDactyl] Stopping server..."
    if [ -n "$WINE_PID" ] && kill -0 "$WINE_PID" 2>/dev/null; then
        kill -INT "$WINE_PID" 2>/dev/null
        for i in $(seq 1 20); do
            kill -0 "$WINE_PID" 2>/dev/null || break
            sleep 1
        done
        kill -0 "$WINE_PID" 2>/dev/null && kill -9 "$WINE_PID" 2>/dev/null
    fi
    wineserver -k 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── Launch ────────────────────────────────────────────────────────────────────
echo "[LCDactyl] Starting Minecraft Legacy Console Edition..."
cd /home/container

wine Minecraft.Client.exe -server -port ${SERVER_PORT:-25565} -ip 0.0.0.0 ${EXTRA_FLAGS} &
WINE_PID=$!

wait $WINE_PID
EXIT_CODE=$?

wineserver -k 2>/dev/null
exit $EXIT_CODE
