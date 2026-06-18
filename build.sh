#!/bin/bash
# Build OpenJKDF2 (submodule) and package a PortMaster-ready zip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Keep launcher/scripts LF-only (CRLF breaks execution on device)
for _sh in "$ROOT/build.sh" "$ROOT"/scripts/*.sh "$ROOT"/port/*.sh "$ROOT"/port/openjkdf2/helpers/gamepad.inc; do
  [[ -f "$_sh" ]] && grep -q $'\r' "$_sh" 2>/dev/null && sed -i 's/\r$//' "$_sh"
done

PACKAGE_ONLY=0
SKIP_ZIP=0
CHECK_ONLY=0
USE_DOCKER=1
BUILD_X86_64=1
BUILD_AARCH64=1

usage() {
    cat <<'EOF'
Usage: ./build.sh [options]

  (no options)     Init submodule, build aarch64 + x86_64 in Docker, stage port, create zip
  --native         Cross-compile aarch64 on host (needs aarch64-linux-gnu toolchain)
  --aarch64-only   Skip x86_64 build (handheld-only zip)
  --x86_64-only   Skip x86_64 build (handheld-only zip)
  --package-only   Skip engine build; reuse existing build trees
  --no-zip         Build and stage port/ but do not create dist/openjkdf2.zip
  --check          Validate port metadata only (no compile, no zip)
  -h, --help       Show this help

Output:
  port/openjkdf2/openjkdf2.aarch64   (gitignored)
  port/openjkdf2/openjkdf2.x86_64    (gitignored, RetroDECK / PC)
  port/openjkdf2/libs.aarch64/       (gitignored, openal only)
  port/openjkdf2/libs.x86_64/        (gitignored)
  dist/openjkdf2.zip                 (gitignored)

Game files are NOT included. End users copy GOG/Steam assets to openjkdf2/jk1/.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --package-only) PACKAGE_ONLY=1 ;;
    --aarch64-only) BUILD_X86_64=0 ;;
    --x86_64-only) BUILD_AARCH64=0 ;;
    --docker) USE_DOCKER=1 ;;
    --native) USE_DOCKER=0 ;;
    --no-zip) SKIP_ZIP=1 ;;
    --check) CHECK_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

"$ROOT/scripts/init-submodule.sh"

if [[ $CHECK_ONLY -eq 1 ]]; then
    "$ROOT/scripts/package-release.sh" --check
    exit 0
fi

if [[ $PACKAGE_ONLY -eq 0 ]]; then
  if [[ $USE_DOCKER -eq 1 ]]; then
    if [[ $BUILD_AARCH64 -eq 1 ]]; then
      "$ROOT/scripts/build-engine-docker.sh"
    fi
    if [[ $BUILD_X86_64 -eq 1 ]]; then
      "$ROOT/scripts/build-engine-x86_64-docker.sh"
    fi
  else
    "$ROOT/scripts/build-engine.sh"
    if [[ $BUILD_X86_64 -eq 1 ]]; then
      "$ROOT/scripts/build-engine-x86_64.sh"
    fi
  fi
fi

"$ROOT/scripts/setup-port-layout.sh"
"$ROOT/scripts/package-port.sh"

if [[ $SKIP_ZIP -eq 0 ]]; then
  "$ROOT/scripts/package-release.sh"
fi
