#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$ROOT/OpenJKDF2"

[[ -f "$ENGINE/build_linux64.sh" ]] || {
    echo "Run ./scripts/init-submodule.sh first." >&2
    exit 1
}

echo "== Building OpenJKDF2 (x86_64 / linux64) =="
cd "$ENGINE"
./build_linux64.sh

[[ -f "$ENGINE/build_linux64/openjkdf2" ]] || {
    echo "ERROR: build did not produce build_linux64/openjkdf2" >&2
    exit 1
}

"$ROOT/scripts/verify-glibc.sh" "$ENGINE/build_linux64/openjkdf2"

echo "Built: $ENGINE/build_linux64/openjkdf2"
