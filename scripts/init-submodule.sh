#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$ROOT/OpenJKDF2"

if [[ -d "$ROOT/.git" ]]; then
    git -C "$ROOT" submodule update --init --recursive
elif [[ ! -f "$ENGINE/build_aarch64.sh" ]]; then
    cat >&2 <<EOF
Engine submodule missing.

  git clone --recurse-submodules <this-repo-url>
  # or, in an existing clone:
  git submodule update --init --recursive

Manual fallback:
  git clone https://github.com/juanvillacortac/OpenJKDF2.git OpenJKDF2
  cd OpenJKDF2 && git submodule update --init --recursive
EOF
    exit 1
fi

if [[ ! -f "$ENGINE/build_aarch64.sh" ]]; then
    echo "ERROR: $ENGINE/build_aarch64.sh not found after submodule init." >&2
    exit 1
fi
