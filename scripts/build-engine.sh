#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$ROOT/OpenJKDF2"

[[ -f "$ENGINE/build_aarch64.sh" ]] || {
    echo "Run ./scripts/init-submodule.sh first." >&2
    exit 1
}

if ! command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
    echo "ERROR: aarch64-linux-gnu-gcc not found (install cross-compiler toolchain)." >&2
    exit 1
fi

if [[ "${OPENJKDF2_PORTABLE_BUILD:-}" != "1" ]] && [[ -f /usr/aarch64-linux-gnu/lib/libc.so.6 ]]; then
    if strings /usr/aarch64-linux-gnu/lib/libc.so.6 | grep -qE 'GLIBC_2\.(3[4-9]|[4-9][0-9])'; then
        echo "WARNING: Host aarch64 sysroot uses glibc >= 2.34 ($(aarch64-linux-gnu-gcc --version | head -1))." >&2
        echo "         Binaries may not run on ArkOS and other older CFWs." >&2
        echo "         Use: ./build.sh   (Docker, Ubuntu 20.04 glibc 2.31) or ./build.sh --native" >&2
        echo "" >&2
    fi
fi

echo "== Building OpenJKDF2 (aarch64) =="
cd "$ENGINE"
./build_aarch64.sh

[[ -f "$ENGINE/build_aarch64/openjkdf2" ]] || {
    echo "ERROR: build did not produce build_aarch64/openjkdf2" >&2
    exit 1
}

"$ROOT/scripts/verify-glibc.sh" "$ENGINE/build_aarch64/openjkdf2"

echo "Built: $ENGINE/build_aarch64/openjkdf2"
