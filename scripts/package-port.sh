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

# GNS links against OpenSSL 1.1; most desktops/handhelds only ship OpenSSL 3.x.
stage_openssl11_libs() {
    local arch="$1"
    local dest="$2"
    local libdir=""

    case "$arch" in
        aarch64)
            for libdir in \
                /usr/aarch64-openssl/lib \
                "$BUILD_A64/openssl/lib" \
                ; do
                [[ -f "$libdir/libcrypto.so.1.1" ]] && break
                libdir=""
            done
            if [[ -z "$libdir" ]] && command -v docker >/dev/null 2>&1; then
                local image="${OPENJKDF2_DOCKER_IMAGE:-openjkdf2-aarch64-builder:20.04}"
                for lib in libcrypto.so.1.1 libssl.so.1.1; do
                    docker run --rm -v "$dest:/out" "$image" \
                        cp "/usr/aarch64-openssl/lib/$lib" "/out/" 2>/dev/null || true
                done
                return 0
            fi
            ;;
        x86_64)
            for libdir in \
                /usr/lib/x86_64-linux-gnu \
                "$BUILD_X64/openssl/lib" \
                ; do
                [[ -f "$libdir/libcrypto.so.1.1" ]] && break
                libdir=""
            done
            if [[ -z "$libdir" ]] && command -v docker >/dev/null 2>&1; then
                local image="${OPENJKDF2_DOCKER_IMAGE_X86_64:-openjkdf2-x86_64-builder:20.04}"
                for lib in libcrypto.so.1.1 libssl.so.1.1; do
                    docker run --rm -v "$dest:/out" "$image" \
                        cp "/usr/lib/x86_64-linux-gnu/$lib" "/out/" 2>/dev/null || true
                done
                return 0
            fi
            ;;
        *)
            echo "Unknown arch for OpenSSL staging: $arch" >&2
            return 1
            ;;
    esac

    if [[ -z "$libdir" ]]; then
        echo "WARNING: OpenSSL 1.1 libs not found for $arch (GNS multiplayer will fail)" >&2
        return 0
    fi

    copy_lib "$dest" "$libdir/libcrypto.so.1.1"
    copy_lib "$dest" "$libdir/libssl.so.1.1"
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
stage_openssl11_libs aarch64 "$PORT/libs.aarch64"
if [ -f "$BUILD_X64/GameNetworkingSockets/bin/libGameNetworkingSockets.so" ]; then
    copy_lib "$PORT/libs.x86_64" "$BUILD_X64/GameNetworkingSockets/bin/libGameNetworkingSockets.so"
elif [ -f "$BUILD_X64/GameNetworkingSockets/lib/libGameNetworkingSockets.so" ]; then
    copy_lib "$PORT/libs.x86_64" "$BUILD_X64/GameNetworkingSockets/lib/libGameNetworkingSockets.so"
fi
stage_openssl11_libs x86_64 "$PORT/libs.x86_64"

echo "Port staged at: $PORT"
echo "  - openjkdf2.aarch64"
echo "  - openjkdf2.x86_64"
echo "  - libs.aarch64/ ($(ls "$PORT/libs.aarch64" | wc -l) libraries)"
echo "  - libs.x86_64/ ($(ls "$PORT/libs.x86_64" | wc -l) libraries)"
echo ""
echo "Create zip: ./build.sh --package-only   (if engines already built)"
echo "         or: ./scripts/package-release.sh"
