#!/bin/bash
# Create dist/openjkdf2.zip with PortMaster metadata (no game files).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="$ROOT/port"
OUT="$ROOT/dist"
ZIP_NAME="openjkdf2.zip"
CHECK_ONLY=0
STRICT=0

for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=1 ;;
        --strict) STRICT=1 ;;
        -h|--help)
            echo "Usage: $0 [--check] [--strict]"
            echo "  --check   Validate metadata only"
            echo "  --strict  Require binary and screenshot before zipping"
            exit 0
            ;;
    esac
done

LAUNCHER="$PORT/Star Wars Jedi Knight - Dark Forces II.sh"
if grep -q $'\r' "$LAUNCHER" 2>/dev/null; then
    sed -i 's/\r$//' "$LAUNCHER"
    echo "Normalized launcher line endings (CRLF -> LF)"
fi

section() { echo ""; echo "== $* =="; }
ok()   { echo "  [OK]   $*"; }
warn() { echo "  [WARN] $*"; }
bad()  { echo "  [FAIL] $*"; exit 1; }

section "PortMaster metadata"
[[ -f "$PORT/port.json" ]] && ok "port.json" || bad "Missing $PORT/port.json"
[[ -f "$PORT/gameinfo.xml" ]] && ok "gameinfo.xml" || bad "Missing $PORT/gameinfo.xml"
[[ -f "$PORT/README.md" ]] && ok "README.md" || bad "Missing $PORT/README.md"
[[ -f "$LAUNCHER" ]] && ok "launcher .sh" || bad "Missing launcher"
[[ -f "$PORT/screenshot.png" || -f "$PORT/screenshot.jpg" ]] \
    && ok "screenshot present" \
    || warn "Missing screenshot.png (required for PortMaster catalogue — see port/ASSETS.md)"
[[ -f "$PORT/cover.png" || -f "$PORT/cover.jpg" ]] \
    && ok "cover present" \
    || warn "Missing cover.png (optional; gameinfo.xml references ./cover.png)"

BINARY="$PORT/openjkdf2/openjkdf2.aarch64"
BINARY_X64="$PORT/openjkdf2/openjkdf2.x86_64"
if [[ -f "$BINARY" ]]; then
    ok "openjkdf2.aarch64 staged"
else
    warn "openjkdf2.aarch64 missing — run ./build.sh before releasing"
    [[ $STRICT -eq 1 ]] && bad "Strict mode: binary required"
fi
if [[ -f "$BINARY_X64" ]]; then
    ok "openjkdf2.x86_64 staged"
else
    warn "openjkdf2.x86_64 missing — run ./build.sh (or build-engine-x86_64-docker.sh)"
    [[ $STRICT -eq 1 ]] && bad "Strict mode: x86_64 binary required"
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
    echo ""
    echo "Metadata check done."
    exit 0
fi

[[ -f "$BINARY" ]] || bad "Cannot create zip without openjkdf2.aarch64 (run ./build.sh)"
[[ -f "$BINARY_X64" ]] || bad "Cannot create zip without openjkdf2.x86_64 (run ./build.sh)"

# PortMaster expects screenshot/cover next to port.json; ES uses gameinfo.xml paths.
for asset in screenshot.jpg screenshot.png cover.jpg cover.png; do
    if [[ ! -f "$PORT/$asset" && -f "$PORT/openjkdf2/$asset" ]]; then
        cp "$PORT/openjkdf2/$asset" "$PORT/$asset"
        echo "Copied openjkdf2/$asset → port/$asset (PortMaster layout)"
    fi
done

section "Create release zip"
mkdir -p "$OUT"
ZIP_PATH="$OUT/$ZIP_NAME"
rm -f "$ZIP_PATH"

(
    cd "$PORT"
    FILES=(
        "Star Wars Jedi Knight - Dark Forces II.sh"
        "openjkdf2"
        "port.json"
        "README.md"
        "gameinfo.xml"
    )
    [[ -f "Star Wars Jedi Knight - Mysteries of the Sith.sh" ]] && FILES+=("Star Wars Jedi Knight - Mysteries of the Sith.sh")
    [[ -f screenshot.png ]] && FILES+=("screenshot.png")
    [[ -f screenshot.jpg ]] && FILES+=("screenshot.jpg")
    [[ -f cover.png ]] && FILES+=("cover.png")
    [[ -f cover.jpg ]] && FILES+=("cover.jpg")

    zip -r "$ZIP_PATH" "${FILES[@]}"
)

ok "Created $ZIP_PATH ($(du -h "$ZIP_PATH" | cut -f1))"
echo ""
echo "Install on device:"
echo "  unzip $ZIP_PATH -d /userdata/roms/ports/"
echo "  Copy JKDF2 game files to .../ports/openjkdf2/jk1/"
