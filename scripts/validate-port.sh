#!/bin/bash
# Validate port structure and (optionally) a built binary before release.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT_ROOT="$ROOT/port"
GAMEDIR="$PORT_ROOT/openjkdf2"
LAUNCHER="$PORT_ROOT/Star Wars Jedi Knight - Dark Forces II.sh"
HELPERS_DIR="$GAMEDIR/helpers"
LAUNCH_HELPERS="$HELPERS_DIR/gamepad.inc"
LIBS="$GAMEDIR/libs.aarch64"
LIBS_X64="$GAMEDIR/libs.x86_64"
BINARY="$GAMEDIR/openjkdf2.aarch64"
BINARY_X64="$GAMEDIR/openjkdf2.x86_64"
STRICT=0

for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        -h|--help)
            echo "Usage: $0 [--strict]"
            echo "  --strict  Fail if binary or game files are missing"
            exit 0
            ;;
    esac
done

PASS=0
WARN=0
FAIL=0

ok()   { echo "  [OK]   $*"; PASS=$((PASS + 1)); }
warn() { echo "  [WARN] $*"; WARN=$((WARN + 1)); }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }

section() { echo ""; echo "== $* =="; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

readelf_bin() {
    if have_cmd aarch64-linux-gnu-readelf; then
        echo aarch64-linux-gnu-readelf
    elif have_cmd readelf; then
        echo readelf
    else
        echo ""
    fi
}

file_bin() {
    if have_cmd file; then
        echo file
    else
        echo ""
    fi
}

section "Port structure"
[[ -f "$LAUNCHER" ]] && ok "Launcher: $(basename "$LAUNCHER")" || bad "Missing launcher: $LAUNCHER"
[[ -f "$LAUNCH_HELPERS" ]] && ok "helpers/gamepad.inc" || bad "Missing $LAUNCH_HELPERS"
[[ ! -f "$GAMEDIR/launch.run" ]] && ok "no launch.run (logic in PortMaster .sh wrappers)" || warn "Remove obsolete launch.run"
[[ -d "$GAMEDIR" ]] && ok "openjkdf2/ folder" || bad "Missing $GAMEDIR"
[[ -f "$PORT_ROOT/port.json" ]] && ok "port.json present" || warn "Missing port/port.json"
[[ -f "$PORT_ROOT/gameinfo.xml" ]] && ok "gameinfo.xml present" || warn "Missing port/gameinfo.xml"
[[ -f "$PORT_ROOT/README.md" ]] && ok "README.md present" || warn "Missing port/README.md"
[[ -f "$PORT_ROOT/screenshot.png" || -f "$PORT_ROOT/screenshot.jpg" ]] && ok "screenshot present" || warn "Missing screenshot (see port/ASSETS.md)"

section "PortMaster script (.sh)"
if [[ -f "$LAUNCHER" ]]; then
    if bash -n "$LAUNCHER" 2>/dev/null; then
        ok "Valid bash syntax"
    elif grep -q $'\r' "$LAUNCHER" 2>/dev/null; then
        bad "Launcher has CRLF line endings — run: sed -i 's/\\r\$//' \"$LAUNCHER\""
    else
        bad "Syntax error in launcher"
    fi

    for token in control.txt get_controls bind_directories pm_finish GPTOKEYB helpers/gamepad.inc DEVICE_RAM; do
        grep -q "$token" "$LAUNCHER" && ok "Wrapper uses $token" || warn "Wrapper missing $token"
    done
    grep -q '/\$directory/ports/openjkdf2' "$LAUNCHER" && ok "Wrapper uses \$directory GAMEDIR" || warn "Wrapper missing \$directory GAMEDIR"

    if [[ -f "$LAUNCH_HELPERS" ]]; then
        bash -n "$LAUNCH_HELPERS" 2>/dev/null && ok "helpers/gamepad.inc valid bash syntax" || bad "Syntax error in gamepad.inc"
    fi

    grep -q 'gl4es' "$LAUNCHER" && warn "Launcher mentions gl4es (this port uses native GLES)" || ok "No GL4ES in launcher"

    if [[ -f "$GAMEDIR/openjkdf2.gptk" ]]; then
        ok "openjkdf2.gptk (gptokeyb kill-only, native SDL gamepad)"
    else
        warn "Missing openjkdf2.gptk"
    fi
    if grep -q 'openjkdf2.gptk' "$LAUNCHER" 2>/dev/null && grep -q 'GPTOKEYB' "$LAUNCHER" 2>/dev/null; then
        ok "gptokeyb with openjkdf2.gptk"
    else
        warn "No gptokeyb/openjkdf2.gptk in wrapper"
    fi
fi

section "Engine submodule"
[[ -f "$ROOT/OpenJKDF2/build_aarch64.sh" ]] && ok "OpenJKDF2 submodule present" || bad "Missing OpenJKDF2/ — run: git submodule update --init"
[[ -f "$ROOT/.gitmodules" ]] && ok ".gitmodules configured" || warn "No .gitmodules (engine may be a manual clone)"

section "Port layout (user installs game files)"
for dir in jk1 mots expansions mods conf licenses; do
    [[ -d "$GAMEDIR/$dir" ]] && ok "$dir/ present" || warn "Missing $dir/ (run ./scripts/setup-port-layout.sh)"
done
[[ -f "$GAMEDIR/jk1/README.txt" ]] && ok "jk1/README.txt install instructions" || warn "Missing jk1/README.txt"

if [[ -d "$GAMEDIR/jk1/episode" && -d "$GAMEDIR/jk1/resource" ]]; then
    ok "jk1/ has game data (dev copy)"
else
    warn "jk1/episode and jk1/resource absent (expected in repo — user adds on device)"
fi

section "bundled libraries"
if [[ -d "$LIBS" ]]; then
    for f in "$LIBS"/libSDL2*.so* "$LIBS"/libSDL2_mixer*.so*; do
        [[ -e "$f" ]] || continue
        bad "Do not bundle SDL in libs.aarch64 (use system libs): $(basename "$f")"
    done
    [[ -f "$LIBS/libopenal.so" ]] && ok "libs.aarch64/libopenal.so present" \
        || warn "libs.aarch64/libopenal.so missing (run ./build.sh)"
fi
if [[ -d "$LIBS_X64" ]]; then
    for f in "$LIBS_X64"/libSDL2*.so* "$LIBS_X64"/libSDL2_mixer*.so*; do
        [[ -e "$f" ]] || continue
        bad "Do not bundle SDL in libs.x86_64 (use system libs): $(basename "$f")"
    done
fi

section "aarch64 binary"
if [[ -f "$BINARY" ]]; then
    [[ -x "$BINARY" ]] && ok "openjkdf2.aarch64 is executable" || warn "openjkdf2.aarch64 not +x"
    FILE_CMD="$(file_bin)"
    RELF="$(readelf_bin)"
    if [[ -n "$FILE_CMD" ]]; then
        arch="$("$FILE_CMD" "$BINARY" 2>/dev/null || true)"
        echo "$arch" | grep -qi 'aarch64' && ok "Architecture: aarch64" || bad "Not aarch64: $arch"
        echo "$arch" | grep -qi 'ELF' && ok "ELF binary" || bad "Not an ELF binary"
    fi
    if [[ -n "$RELF" ]]; then
        while IFS= read -r lib; do
            case "$lib" in
                libSDL2-2.0.so.0|libSDL2_mixer-2.0.so.0)
                    warn "NEEDED $lib (system lib on device, not bundled)"
                    ;;
                libopenal.so.1)
                    [[ -f "$LIBS/libopenal.so" ]] && ok "NEEDED $lib → libs.aarch64/libopenal.so" \
                        || bad "NEEDED $lib but missing libs.aarch64/libopenal.so"
                    ;;
                libGLESv2.so|libEGL.so)
                    ok "NEEDED $lib (system GLES on device)"
                    ;;
            esac
        done < <("$RELF" -d "$BINARY" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' || true)
    fi
else
    warn "openjkdf2.aarch64 not built — run ./build.sh"
    [[ $STRICT -eq 1 ]] && bad "Strict mode: binary required"
fi

section "x86_64 binary"
if [[ -f "$BINARY_X64" ]]; then
    [[ -x "$BINARY_X64" ]] && ok "openjkdf2.x86_64 is executable" || warn "openjkdf2.x86_64 not +x"
    FILE_CMD="$(file_bin)"
    RELF="$(readelf_bin)"
    if [[ -n "$FILE_CMD" ]]; then
        arch="$("$FILE_CMD" "$BINARY_X64" 2>/dev/null || true)"
        echo "$arch" | grep -qi 'x86-64' && ok "Architecture: x86_64" || bad "Not x86_64: $arch"
        echo "$arch" | grep -qi 'ELF' && ok "ELF binary" || bad "Not an ELF binary"
    fi
    if [[ -n "$RELF" ]]; then
        while IFS= read -r lib; do
            case "$lib" in
                libSDL2-2.0.so.0|libSDL2_mixer-2.0.so.0)
                    warn "NEEDED $lib (system lib on device, not bundled)"
                    ;;
                libopenal.so.1)
                    [[ -f "$LIBS_X64/libopenal.so" ]] && ok "NEEDED $lib → libs.x86_64/libopenal.so" \
                        || warn "NEEDED $lib but missing libs.x86_64/libopenal.so"
                    ;;
                libGL.so.1)
                    ok "NEEDED $lib (system OpenGL on RetroDECK/PC)"
                    ;;
            esac
        done < <("$RELF" -d "$BINARY_X64" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' || true)
    fi
else
    warn "openjkdf2.x86_64 not built — run ./scripts/build-engine-x86_64-docker.sh"
    [[ $STRICT -eq 1 ]] && bad "Strict mode: x86_64 binary required"
fi

section "Cross-compile tools"
have_cmd aarch64-linux-gnu-gcc && ok "aarch64-linux-gnu-gcc" || warn "No cross-compiler (needed to rebuild)"
have_cmd aarch64-linux-gnu-readelf && ok "aarch64-linux-gnu-readelf" || warn "No aarch64 readelf"

section "Summary"
echo "  OK: $PASS  |  WARN: $WARN  |  FAIL: $FAIL"
echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "Port repo looks good."
    echo "  ./build.sh              → compile + zip"
    echo "  dist/openjkdf2.zip      → install on device"
    echo "  User copies game files → openjkdf2/jk1/"
    exit 0
else
    echo "Fix errors before release."
    exit 1
fi
