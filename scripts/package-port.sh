#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/OpenJKDF2/build_aarch64"
PORT="$ROOT/port/openjkdf2"

if [ ! -f "$BUILD/openjkdf2" ]; then
    echo "Binary missing. Run: ./build.sh" >&2
    exit 1
fi

mkdir -p "$PORT/libs.aarch64"

"$ROOT/scripts/setup-port-layout.sh"

cp "$BUILD/openjkdf2" "$PORT/openjkdf2.aarch64"
chmod +x "$PORT/openjkdf2.aarch64"

copy_lib() {
    local src="$1"
    if [ -f "$src" ]; then
        cp -u "$src" "$PORT/libs.aarch64/"
    fi
}

# SDL2/SDL2_mixer: system libs on device; bundle openal only
copy_lib "$BUILD/openal/libopenal.so"

"$ROOT/scripts/verify-glibc.sh" "$PORT/openjkdf2.aarch64" "$PORT/libs.aarch64"

if [ -f "$BUILD/GameNetworkingSockets/bin/libGameNetworkingSockets.so" ]; then
    copy_lib "$BUILD/GameNetworkingSockets/bin/libGameNetworkingSockets.so"
fi

echo "Port staged at: $PORT"
echo "  - openjkdf2.aarch64"
echo "  - libs.aarch64/ ($(ls "$PORT/libs.aarch64" | wc -l) libraries)"
echo ""
echo "Create zip: ./build.sh --package-only   (if engine already built)"
echo "         or: ./scripts/package-release.sh"
