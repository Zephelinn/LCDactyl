#!/bin/bash
# LCDactyl Script
# This will download the MinecraftConsoles nightly build from GitHub Releases
# and extract it to /mnt/server for wine utilization.
#
# Environment variables (set by the egg):
#   RELEASE_TAG  — GitHub release tag to download (default: nightly)

cd /mnt/server || exit 1

RELEASE_TAG="${RELEASE_TAG:-nightly}"
REPO="smartcmd/MinecraftConsoles"

echo "🔥🔥🔥 Installing Minecraft Legacy Console Edition Server 🔥🔥🔥"
echo "  Repository : https://github.com/${REPO}"
echo "  Release    : ${RELEASE_TAG}"
echo ""

# ── Resolve download URL ──────────────────────────────────────────────────────
# The nightly release ships a single zip named LCEWindows64.zip
RELEASE_URL="https://api.github.com/repos/${REPO}/releases/tags/${RELEASE_TAG}"

echo "Fetching release metadata..."
RELEASE_JSON=$(curl -sSL "${RELEASE_URL}")

DOWNLOAD_URL=$(echo "${RELEASE_JSON}" | jq -r '.assets[] | select(.name | endswith(".zip")) | .browser_download_url' | head -n 1)

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
    echo "ERROR: Could not find a .zip asset in release '${RELEASE_TAG}'."
    echo "       Check that the release exists at: https://github.com/${REPO}/releases/tag/${RELEASE_TAG}"
    exit 1
fi

ZIP_NAME=$(basename "${DOWNLOAD_URL}")
echo "Downloading: ${ZIP_NAME}"
echo "  URL: ${DOWNLOAD_URL}"

curl -sSLo "${ZIP_NAME}" "${DOWNLOAD_URL}"

if [ $? -ne 0 ]; then
    echo "ERROR: Download failed."
    exit 1
fi

# ── Extract ───────────────────────────────────────────────────────────────────
echo "Extracting ${ZIP_NAME}..."
unzip -o "${ZIP_NAME}" -d .
rm -f "${ZIP_NAME}"

SUBDIR=$(find . -maxdepth 1 -type d ! -name '.' | head -n 1)
if [ -n "${SUBDIR}" ] && [ -f "${SUBDIR}/Minecraft.Client.exe" ]; then
    echo "Moving files from ${SUBDIR} to /mnt/server..."
    mv "${SUBDIR}"/* .
    rmdir "${SUBDIR}" 2>/dev/null || true
fi

# ── Verify ────────────────────────────────────────────────────────────────────
if [ ! -f "Minecraft.Client.exe" ]; then
    echo "ERROR: Minecraft.Client.exe not found after extraction."
    echo "       The archive layout may have changed upstream."
    ls -la
    exit 1
fi

# ── Default server.properties ─────────────────────────────────────────────────
if [ ! -f "server.properties" ]; then
    echo "Creating server.properties..."
    cat > server.properties << 'EOF'
# Minecraft Legacy Console Edition — Server Properties
server-ip=
server-port=25565
max-players=8
EOF
fi

echo ""
echo "Installation complete twin!"
echo "  Executable : Minecraft.Client.exe"
echo "  Server port: 25565 (TCP)"
echo "  LAN discovery port: 25566 (UDP)"
