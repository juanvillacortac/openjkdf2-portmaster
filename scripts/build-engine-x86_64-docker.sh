#!/bin/bash
# Native x86_64 build inside Ubuntu 20.04 (glibc 2.31) for RetroDECK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${OPENJKDF2_DOCKER_IMAGE_X86_64:-openjkdf2-x86_64-builder:20.04}"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found. Install Docker or run on Ubuntu 20.04 natively." >&2
    exit 1
fi

echo "== Docker image: $IMAGE =="
docker build -t "$IMAGE" -f "$ROOT/docker/Dockerfile.x86_64" "$ROOT/docker"

echo "== Building x86_64 in container (glibc 2.31) =="
docker run --rm \
    -v "$ROOT:/work" \
    -w /work \
    -e OPENJKDF2_PORTABLE_BUILD=1 \
    -e OPENJKDF2_PORTMASTER_BUILD=1 \
    -e HOME=/tmp \
    "$IMAGE" \
    bash -c 'git config --global --add safe.directory /work/OpenJKDF2 && git config --global --add safe.directory /work && ./scripts/build-engine-x86_64.sh'

if [[ -d "$ROOT/OpenJKDF2/build_linux64" ]] && [[ ! -w "$ROOT/OpenJKDF2/build_linux64" ]]; then
    echo "Fixing ownership of build_linux64 (run: sudo chown -R \$USER OpenJKDF2/build_linux64)" >&2
fi
