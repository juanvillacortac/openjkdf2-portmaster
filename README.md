# Star Wars Jedi Knight: Dark Forces II — PortMaster Port

PortMaster package for **OpenJKDF2** on aarch64 handhelds (knulli, muOS, ArkOS, Batocera, etc.).

The engine is **not** vendored in this repo. It is included as a [git submodule](https://github.com/juanvillacortac/OpenJKDF2) and built at release time. Game files (GOG/Steam) are **not** included; the end user installs them into `openjkdf2/jk1/` on the device.

## Quick start

```bash
git clone --recurse-submodules https://github.com/juanvillacortac/openjkdf2-aarch64-portmaster.git
cd openjkdf2-aarch64-portmaster
./build.sh
```

**Host requirements (Docker build, default):** `git`, `docker`, and `zip` only. The cross-compiler, CMake, Python, and sysroot live inside the Ubuntu 20.04 container (`docker/Dockerfile.aarch64`). First run builds the image and compiles the engine (~10–30 min, several GB under `OpenJKDF2/build_aarch64/`).

```bash
# Arch / CachyOS
sudo pacman -S --needed git docker zip

# Debian / Ubuntu
sudo apt install git docker.io zip
sudo usermod -aG docker $USER   # log out/in to run docker without sudo
```

Use `./build.sh --native` only if your host already has an aarch64 cross toolchain with glibc ≤ 2.30 (see below).

### First-time setup (this workspace)

If you already have `OpenJKDF2/` cloned locally:

```bash
git init
./scripts/register-submodule.sh   # links existing clone as submodule
git add .gitmodules port/ scripts/ build.sh README.md .gitignore
git commit -m "Initial port repository"
```

Output:

| Path | In git? | Description |
|------|---------|-------------|
| `port/` | yes | Launcher, metadata, folder layout |
| `OpenJKDF2/` | submodule | Engine source (fork) |
| `port/openjkdf2/openjkdf2.aarch64` | no | Built binary |
| `dist/openjkdf2.zip` | no | PortMaster install zip |

## Build options

```bash
./build.sh                 # Docker cross-compile (default) + stage + zip
./build.sh --native        # Host cross-compile (toolchain on your machine)
./build.sh --package-only  # Re-stage binary and zip (engine already built)
./build.sh --no-zip        # Compile and stage only
./build.sh --check         # Validate metadata (no compile)
./scripts/validate-port.sh # Lint port structure
```

### Cross-compilation requirements

**Default (`./build.sh`):** Docker only on the host (`git`, `docker`, `zip`). Everything else is installed in the builder image.

**Native (`./build.sh --native`):** The repo is **mostly standalone**: zlib, libpng, SDL2, SDL_mixer, and OpenAL are built from the engine’s git submodules. You do **not** need JKDF2 game files, GL4ES, or system SDL/OpenAL dev packages for the target.

You **do** need a Linux build host with:

| Tool | Why |
|------|-----|
| `git` | Port repo + recursive engine submodules (`lib/SDL`, etc.) |
| `cmake` (≥ 3.16) | Configure the engine |
| `make` | Build |
| `zip` | Release zip |
| `python3` + `venv` | Codegen step (`cogapp`, created in `build_aarch64/cogapp_venv`) |
| `aarch64-linux-gnu-gcc` + `g++` | Cross compiler |
| Sysroot headers | `glibc` + `linux-api-headers` for `aarch64-linux-gnu` (EGL/GLES link stubs ship in the engine) |

**First build:** ~10–30 min, several GB of build tree under `OpenJKDF2/build_aarch64/`. Needs network once (pip installs `cogapp`).

**Platform:** Linux cross-build only (toolchain hardcoded to `/usr/aarch64-linux-gnu`). Windows/macOS hosts are not supported out of the box.

#### ArkOS / older CFW (glibc compatibility)

**ArkOS ships glibc 2.30.** Cross-compiling on a bleeding-edge host (e.g. Arch/CachyOS with glibc 2.38) produces binaries that fail with `GLIBC_2.32+` / `GLIBCXX_3.4.29` errors.

**`./build.sh` uses Docker by default** (Ubuntu 20.04 cross toolchain). The staged binary is checked to require **GLIBC ≤ 2.30** (current build peaks at **2.29**):

```bash
./build.sh
# or: ./scripts/build-engine-docker.sh
```

Use `./build.sh --native` only if your native aarch64 sysroot is already ≤ 2.30.

#### Arch / CachyOS

```bash
sudo pacman -S --needed git cmake make zip python \
  aarch64-linux-gnu-gcc aarch64-linux-gnu-glibc aarch64-linux-gnu-linux-api-headers
```

#### Debian / Ubuntu

```bash
sudo apt install git cmake build-essential zip python3 python3-venv python3-pip \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  libc6-arm64-cross linux-libc-dev-arm64-cross libc6-dev-arm64-cross
```

#### Fedora

```bash
sudo dnf install git cmake make zip python3 \
  gcc-aarch64-linux-gnu gcc-aarch64-linux-gnu-c++ \
  glibc-devel.aarch64 kernel-headers-aarch64
```

#### Build commands

```bash
git clone --recurse-submodules https://github.com/juanvillacortac/openjkdf2-aarch64-portmaster.git
cd openjkdf2-aarch64-portmaster
./build.sh
# → OpenJKDF2/build_aarch64/openjkdf2
# → port/openjkdf2/openjkdf2.aarch64
# → dist/openjkdf2.zip
```

If submodules were not cloned recursively:

```bash
git submodule update --init --recursive
cd OpenJKDF2 && git submodule update --init --recursive && cd ..
./build.sh
```

## Supported firmware (PortMaster)

Requires **aarch64** and **PortMaster** with native **GLES** (Mali or equivalent). Tested on **knulli**; should also work on other PortMaster CFWs that meet those requirements.

| CFW | Ports folder (typical) | Status | Notes |
|-----|------------------------|--------|-------|
| [knulli](https://knulli.org/) | `/userdata/roms/ports/` | Tested (RG34XX SP) | Requires enabling `ZRAMSWAP` via `System Settings > Services` |
| [muOS](https://muos.dev/) | `/mnt/mmc/ROMS/Ports/` or `/roms/ports/` | Expected | |
| [ROCKNIX](https://rocknix.org/) | `/roms/ports/` | Expected | |
| [ArkOS](https://github.com/christianhaitian/arkos) | `/roms/ports/` or `/roms2/ports/` | Expected | |
| [Batocera](https://batocera.org/) | varies by device | Expected | |
| AmberELEC / JELOS / UnofficialOS | `/roms/ports/` | Expected (aarch64 devices) | |

**Not supported:** 32-bit **armhf** devices (RG351P/M/V, R36S, ODROID-GO Advance/Super, etc.) — this port ships `openjkdf2.aarch64` only.

**Recommended hardware:** Anbernic H700 family (RG35XX Plus/H/SP, RG34XX, RG40XX) or similar aarch64 handheld with 2 GB RAM and Mali GPU.

## Install on device

1. Unzip `dist/openjkdf2.zip` to your CFW’s `ports/` folder (see table above).
2. Copy JKDF2 from GOG/Steam to `openjkdf2/jk1/`.
3. Launch **Star Wars Jedi Knight - Dark Forces II** from PortMaster.

Examples:

```bash
# knulli
unzip dist/openjkdf2.zip -d /userdata/roms/ports/

# ROCKNIX / ArkOS / AmberELEC
unzip dist/openjkdf2.zip -d /roms/ports/
```

If the game fails to start, check `openjkdf2/log.txt` on the device SD card. End-user notes and controls: `port/README.md`.

## Repo layout

```
.
├── build.sh                 # Main build entry point
├── port/                    # PortMaster files (tracked)
│   ├── Star Wars Jedi Knight - Dark Forces II.sh
│   ├── port.json, gameinfo.xml, README.md
│   └── openjkdf2/           # Layout + README placeholders (no binary in git)
├── OpenJKDF2/               # git submodule → fork
├── scripts/
│   ├── init-submodule.sh
│   ├── build-engine.sh
│   ├── setup-port-layout.sh
│   ├── package-port.sh
│   ├── package-release.sh
│   └── validate-port.sh
└── dist/                    # Generated zips (gitignored)
```

## Engine fork

Handheld GLES changes live in [juanvillacortac/OpenJKDF2](https://github.com/juanvillacortac/OpenJKDF2). Upstream: [shinyquagsire23/OpenJKDF2](https://github.com/shinyquagsire23/OpenJKDF2).

To bump the engine version:

```bash
cd OpenJKDF2
git fetch && git checkout <commit>
cd ..
git add OpenJKDF2
./build.sh
```

## PortMaster

- [Packaging guide](https://portmaster.games/packaging.html)
- Screenshot/cover: see `port/ASSETS.md`
