#!/bin/bash
# Cross-compile inside Ubuntu 20.04 (glibc 2.31) for ArkOS / older PortMaster CFWs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${OPENJKDF2_DOCKER_IMAGE:-openjkdf2-aarch64-builder:20.04}"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found. Install Docker or build on Ubuntu 20.04 with aarch64 cross tools." >&2
    exit 1
fi

echo "== Docker image: $IMAGE =="
docker build -t "$IMAGE" -f "$ROOT/docker/Dockerfile.aarch64" "$ROOT/docker"

echo "== Cross-compiling in container (glibc 2.31 sysroot) =="
docker run --rm \
    -v "$ROOT:/work" \
    -w /work \
    -e OPENJKDF2_PORTABLE_BUILD=1 \
    -e HOME=/tmp \
    "$IMAGE" \
    bash -c 'git config --global --add safe.directory "*" && ./scripts/build-engine.sh'

# build tree may be owned by root
if [[ -d "$ROOT/OpenJKDF2/build_aarch64" ]] && [[ ! -w "$ROOT/OpenJKDF2/build_aarch64" ]]; then
    echo "Fixing ownership of build_aarch64 (run: sudo chown -R \$USER OpenJKDF2/build_aarch64)" >&2
fi
