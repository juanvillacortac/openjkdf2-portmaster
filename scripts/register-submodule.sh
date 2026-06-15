#!/bin/bash
# One-time setup: turn an existing OpenJKDF2 clone into a git submodule.
# Run from the port repo root after `git init`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE="$ROOT/OpenJKDF2"
URL="https://github.com/juanvillacortac/OpenJKDF2.git"

cd "$ROOT"

[[ -d .git ]] || { echo "Run: git init" >&2; exit 1; }

if git config -f .gitmodules --get-regexp path 2>/dev/null | grep -q 'OpenJKDF2'; then
    echo "Submodule already registered in .gitmodules"
    git submodule update --init --recursive
    exit 0
fi

if [[ -d "$ENGINE/.git" ]]; then
    echo "Registering existing $ENGINE as submodule..."
    git submodule add --force "$URL" OpenJKDF2 2>/dev/null || {
        git submodule absorbgitdirs OpenJKDF2 2>/dev/null || true
    }
else
    git submodule add "$URL" OpenJKDF2
fi

git submodule update --init --recursive
echo "Done. Commit .gitmodules and OpenJKDF2 submodule pointer."
