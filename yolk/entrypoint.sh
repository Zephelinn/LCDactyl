#!/bin/bash
# LCDactyl entrypoint — runs inside the Pterodactyl container.
# Pterodactyl automatically injects: SERVER_IP, SERVER_PORT, etc.

export WINEPREFIX=/home/container/.wine
export WINEARCH=win64
export DISPLAY=:99

# Suppress all Wine/DXVK/VKD3D debug noise
export WINEDEBUG=-all
export DXVK_LOG_LEVEL=none
export VKD3D_DEBUG=none

# Fix Fontconfig: give it a writable cache dir
export FONTCONFIG_PATH=/etc/fonts
export XDG_CACHE_HOME=/home/container/.cache
mkdir -p /home/container/.cache/fontconfig

# Fix PulseAudio noise
export PULSE_RUNTIME_PATH=/home/container/.pulse
export XDG_RUNTIME_DIR=/home/container/.runtime
mkdir -p /home/container/.pulse /home/container/.runtime

# Disable audio entirely — no sound hardware in a container
export AUDIODEV=null
export ALSA_CONFIG_PATH=/dev/null
export SDL_AUDIODRIVER=dummy
export WINEDLLOVERRIDES="winealsa.drv=d;wineoss.drv=d;winemci=d"

# ── Graceful shutdown handler ─────────────────────────────────────────────────
# Pterodactyl sends SIGTERM when the stop command (^C) is issued.
# We forward SIGINT to the wine process so the Windows Ctrl handler fires,
# wait up to 15 seconds for a clean exit, then hard-kill wineserver.
cleanup() {
    echo "[LCDactyl] Stopping server..."
    if [ -n "$WINE_PID" ] && kill -0 "$WINE_PID" 2>/dev/null; then
        kill -INT "$WINE_PID" 2>/dev/null
        # Wait up to 15s for wine to exit cleanly
        for i in $(seq 1 15); do
            kill -0 "$WINE_PID" 2>/dev/null || break
            sleep 1
        done
        # Force kill if still running
        kill -0 "$WINE_PID" 2>/dev/null && kill -9 "$WINE_PID" 2>/dev/null
    fi
    # Always terminate wineserver so the container exits immediately
    wineserver -k 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

# ── Start virtual display ─────────────────────────────────────────────────────
Xvfb :99 -screen 0 1024x768x16 -nolisten tcp 2>/dev/null &
sleep 1

# ── Write server.properties from Pterodactyl env vars ────────────────────────
# SERVER_IP and SERVER_PORT are injected automatically by the Wings daemon.
cat > /home/container/server.properties << EOF
server-ip=${SERVER_IP:-0.0.0.0}
server-port=${SERVER_PORT:-25565}
max-players=${LCE_MAX_PLAYERS:-8}
difficulty=${LCE_DIFFICULTY:-1}
gamemode=${LCE_GAMEMODE:-0}
pvp=${LCE_PVP:-true}
EOF
echo "[LCDactyl] server.properties -> ip=${SERVER_IP:-0.0.0.0} port=${SERVER_PORT:-25565} max-players=${LCE_MAX_PLAYERS:-8}"

# ── Verify the executable exists ──────────────────────────────────────────────
if [ ! -f "/home/container/Minecraft.Client.exe" ]; then
    echo "[LCDactyl] ERROR: Minecraft.Client.exe not found. Did the install script complete?"
    exit 1
fi

# ── Launch ────────────────────────────────────────────────────────────────────
echo "[LCDactyl] Starting Minecraft Legacy Console Edition..."
cd /home/container

# Run wine in background so we can trap signals, filter noisy stderr
wine Minecraft.Client.exe -server ${EXTRA_FLAGS} 2>&1 | grep -v \
    -e "Fontconfig error" \
    -e "fixme:" \
    -e "err:vulkan" \
    -e "err:wgl" \
    -e "err:d3d" \
    -e "vkd3d:" \
    -e "ALSA lib" \
    -e "pulse" \
    -e "snd_" \
    -e "Unknown PCM" \
    -e "Failed to create secure directory" \
    -e "^$" &
WINE_PID=$!

# Wait for wine to exit (or for a signal to trigger cleanup)
wait $WINE_PID
EXIT_CODE=$?

# Wine exited on its own — still clean up wineserver
wineserver -k 2>/dev/null
exit $EXIT_CODE
