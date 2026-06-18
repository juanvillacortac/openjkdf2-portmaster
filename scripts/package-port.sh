#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_A64="$ROOT/OpenJKDF2/build_aarch64"
BUILD_X64="$ROOT/OpenJKDF2/build_linux64"
PORT="$ROOT/port/openjkdf2"

if [ ! -f "$BUILD_A64/openjkdf2" ]; then
    echo "aarch64 binary missing. Run: ./build.sh" >&2
    exit 1
fi

if [ ! -f "$BUILD_X64/openjkdf2" ]; then
    echo "x86_64 binary missing. Run: ./scripts/build-engine-x86_64-docker.sh" >&2
    exit 1
fi

mkdir -p "$PORT/libs.aarch64" "$PORT/libs.x86_64"

"$ROOT/scripts/setup-port-layout.sh"

cp "$BUILD_A64/openjkdf2" "$PORT/openjkdf2.aarch64"
chmod +x "$PORT/openjkdf2.aarch64"

cp "$BUILD_X64/openjkdf2" "$PORT/openjkdf2.x86_64"
chmod +x "$PORT/openjkdf2.x86_64"

copy_lib() {
    local dest="$1"
    local src="$2"
    if [ -f "$src" ]; then
        cp -u "$src" "$dest/"
    fi
}

# Do not bundle SDL/SDL_mixer — PortMaster CFWs ship their own (kmsdrm, audio, etc.).
purge_bundled_sdl_libs() {
    local dest="$1"
    rm -f "$dest"/libSDL2*.so* "$dest"/libSDL2_mixer*.so* 2>/dev/null || true
}

purge_bundled_sdl_libs "$PORT/libs.aarch64"
purge_bundled_sdl_libs "$PORT/libs.x86_64"

# openal (+ GNS on x86_64 if built)
copy_lib "$PORT/libs.aarch64" "$BUILD_A64/openal/libopenal.so"

if [ -f "$BUILD_X64/openal/libopenal.so" ]; then
    copy_lib "$PORT/libs.x86_64" "$BUILD_X64/openal/libopenal.so"
fi

"$ROOT/scripts/verify-glibc.sh" "$PORT/openjkdf2.aarch64" "$PORT/libs.aarch64"
"$ROOT/scripts/verify-glibc.sh" "$PORT/openjkdf2.x86_64" "$PORT/libs.x86_64"

copy_lib "$PORT/libs.aarch64" "$BUILD_A64/GameNetworkingSockets/bin/libGameNetworkingSockets.so"
if [ -f "$BUILD_X64/GameNetworkingSockets/bin/libGameNetworkingSockets.so" ]; then
    copy_lib "$PORT/libs.x86_64" "$BUILD_X64/GameNetworkingSockets/bin/libGameNetworkingSockets.so"
elif [ -f "$BUILD_X64/GameNetworkingSockets/lib/libGameNetworkingSockets.so" ]; then
    copy_lib "$PORT/libs.x86_64" "$BUILD_X64/GameNetworkingSockets/lib/libGameNetworkingSockets.so"
fi

echo "Port staged at: $PORT"
echo "  - openjkdf2.aarch64"
echo "  - openjkdf2.x86_64"
echo "  - libs.aarch64/ ($(ls "$PORT/libs.aarch64" | wc -l) libraries)"
echo "  - libs.x86_64/ ($(ls "$PORT/libs.x86_64" | wc -l) libraries)"
echo ""
echo "Create zip: ./build.sh --package-only   (if engines already built)"
echo "         or: ./scripts/package-release.sh"
