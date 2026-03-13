# LCDactyl

A Pterodactyl egg for running a Minecraft Legacy Console Edition dedicated server, powered by [MinecraftConsoles](https://github.com/smartcmd/MinecraftConsoles) and Wine.

---

## What is this?

MinecraftConsoles is an open-source reimplementation of the Minecraft Legacy Console Edition (TU19 / v1.6.0560.0) client for Windows. It supports a `-server` flag that runs a headless dedicated server — no display, no input, just a TCP game server.

LCDactyl wraps that in a Pterodactyl egg so you can host it like any other game server. Wine handles the Windows binary, Xvfb gives it a virtual display for the D3D11 init, and a custom Docker image ties it all together.

---

## Requirements

- Pterodactyl Panel + Wings
- A node that can pull from `ghcr.io`
- The server binary is a Windows x64 executable — no Windows machine needed, Wine handles it

---

## Setup

### 1. Import the egg

Download [`egg-minecraft-lce.json`](./egg-minecraft-lce.json) and import it into your panel under **Admin → Nests → Import Egg**.

### 2. Create a server

Create a new server using the **Minecraft Legacy Console Edition** egg. The install script will automatically download the latest nightly build from the [MinecraftConsoles releases](https://github.com/smartcmd/MinecraftConsoles/releases/tag/nightly).

### 3. Start it

Hit start. The server reads `server.properties` on launch — the panel writes it automatically from your egg variables.

---

## Docker Image

The egg uses `ghcr.io/zephelinn/lcdactyl:latest`.

Source is in [`yolk/`](./yolk/). The image is built on Debian bookworm-slim with:

- WineHQ Stable (64-bit prefix)
- Xvfb (virtual framebuffer for D3D11)
- winetricks + vcrun2022 (Visual C++ 2022 runtime)
- Wine prefix baked in at build time so container startup is instant

To build and push your own:

```bash
docker build --platform linux/amd64 -t ghcr.io/<you>/lcdactyl:latest ./yolk/
docker push ghcr.io/<you>/lcdactyl:latest
```

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `LCE_MAX_PLAYERS` | `8` | Max players (1–8) |
| `LCE_DIFFICULTY` | `1` | 0=Peaceful 1=Easy 2=Normal 3=Hard |
| `LCE_GAMEMODE` | `0` | 0=Survival 1=Creative |
| `LCE_PVP` | `true` | Enable PvP |
| `EXTRA_FLAGS` | _(empty)_ | Extra flags passed to `Minecraft.Client.exe` |
| `RELEASE_TAG` | `nightly` | GitHub release tag to install |

Server IP and port are pulled directly from your Pterodactyl allocation — you don't set those manually.

---

## server.properties

The entrypoint writes `server.properties` on every start from your panel variables. You can also edit it directly in the file manager. Supported keys beyond the basics:

```properties
server-ip=
server-port=25565
max-players=8
difficulty=1
gamemode=0
pvp=true
```

---

## File Manager

`.dll`, `.exe`, `.pdb` and other binary files are hidden from the panel file manager via `file_denylist`. You'll only see `server.properties`, your world save directory, and any other data files.

---

## Credits

- [smartcmd/MinecraftConsoles](https://github.com/smartcmd/MinecraftConsoles) — the actual server implementation
- [WineHQ](https://www.winehq.org/) — Windows compatibility layer
- [Pterodactyl](https://pterodactyl.io/) — game server panel
