#!/bin/bash
# Launch OpenJKDF2 on your PC for local testing (desktop Linux).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PORT="$ROOT/port/openjkdf2"
CONFDIR="$PORT/conf"
ARCH="$(uname -m)"

USE_DEV=0
USE_STEAM=1
MOTS=0
TEE_LOG=0
EXTRA_ARGS=()

usage() {
    cat <<'EOF'
Usage: ./run.sh [options] [-- game-args...]

Runs the port x86_64 binary (or a dev build) with game data from port/jk1/
or your Steam install.

Options:
  --dev              Use OpenJKDF2/build_linux64/openjkdf2 (compile first)
  --port             Use port/openjkdf2/openjkdf2.<arch> (default)
  --mots             Launch Mysteries of the Sith (OPENJKDF2_MOTS=1)
  --jkdf2-root=PATH  JKDF2 game data (episode/, resource/, ...)
  --mots-root=PATH   MOTS game data
  --steam            Prefer Steam install when port/jk1/ is empty (default)
  --no-steam         Do not auto-detect Steam paths
  --setup-steam      Symlink Steam JKDF2 (+ MOTS) into port/openjkdf2/{jk1,mots}
  --force-gl         OPENJKDF2_FORCE_GL=1
  --force-gles       OPENJKDF2_FORCE_GLES=1
  --x11              SDL_VIDEODRIVER=x11
  --wayland          SDL_VIDEODRIVER=wayland
  --log              Tee stdout/stderr to port/openjkdf2/log.txt
  -h, --help         Show this help

Examples:
  ./run.sh
  ./run.sh --mots
  ./run.sh --dev -- -verboseNetworking
  ./run.sh --setup-steam && ./run.sh

Build the port binary: ./build.sh --native
Build a dev binary:    cd OpenJKDF2 && ./build_linux64.sh
EOF
}

has_jkdf2_data() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    [[ -d "$dir/episode" || -d "$dir/Episode" ]] || return 1
    [[ -d "$dir/resource" || -d "$dir/Resource" ]] || return 1
}

steam_common() {
    local d
    for d in \
        "${STEAM_COMMON:-}" \
        "$HOME/.local/share/Steam/steamapps/common" \
        "$HOME/.steam/steam/steamapps/common" \
        "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common"
    do
        [[ -n "$d" && -d "$d" ]] && { echo "$d"; return 0; }
    done
    return 1
}

find_steam_jkdf2() {
    local common path
    common="$(steam_common)" || return 1
    for path in \
        "$common/Star Wars Jedi Knight" \
        "$common/Star Wars Jedi Knight Dark Forces II"
    do
        has_jkdf2_data "$path" && { echo "$path"; return 0; }
    done
    return 1
}

find_steam_mots() {
    local common path
    common="$(steam_common)" || return 1
    for path in \
        "$common/Jedi Knight Mysteries of the Sith" \
        "$common/Star Wars Jedi Knight Mysteries of the Sith"
    do
        has_jkdf2_data "$path" && { echo "$path"; return 0; }
    done
    return 1
}

link_steam_tree() {
    local src="$1" dst="$2" name
    mkdir -p "$dst"
    for name in episode Episode resource Resource MUSIC player Player controls Controls; do
        [[ -d "$src/$name" ]] || continue
        local link="$dst/${name,,}"
        if [[ -e "$link" && ! -L "$link" ]]; then
            echo "  skip $link (exists, not a symlink)"
            continue
        fi
        ln -sfn "$src/$name" "$link"
        echo "  $link -> $src/$name"
    done
    if [[ -f "$src/resource/jk_.cd" || -f "$src/Resource/jk_.cd" || -f "$src/Resource/JK_.CD" ]]; then
        mkdir -p "$dst/resource"
        for f in "$src"/resource/jk_.cd "$src"/Resource/jk_.cd "$src"/Resource/JK_.CD; do
            [[ -f "$f" ]] && ln -sfn "$f" "$dst/resource/jk_.cd" && echo "  $dst/resource/jk_.cd -> $f" && break
        done
    fi
}

setup_steam_links() {
    local jk mots
    jk="$(find_steam_jkdf2)" || {
        echo "ERROR: JKDF2 not found in Steam. Install app 32380 or set --jkdf2-root=." >&2
        exit 1
    }
    echo "== Linking JKDF2 into port/openjkdf2/jk1/ =="
    link_steam_tree "$jk" "$PORT/jk1"
    if mots="$(find_steam_mots)"; then
        echo "== Linking MOTS into port/openjkdf2/mots/ =="
        link_steam_tree "$mots" "$PORT/mots"
    else
        echo "MOTS not found in Steam (optional)."
    fi
    echo "Done. Run: ./run.sh"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dev) USE_DEV=1; shift ;;
        --port) USE_DEV=0; shift ;;
        --mots) MOTS=1; shift ;;
        --steam) USE_STEAM=1; shift ;;
        --no-steam) USE_STEAM=0; shift ;;
        --setup-steam) setup_steam_links; exit 0 ;;
        --force-gl) export OPENJKDF2_FORCE_GL=1; shift ;;
        --force-gles) export OPENJKDF2_FORCE_GLES=1; shift ;;
        --x11) export SDL_VIDEODRIVER=x11; shift ;;
        --wayland) export SDL_VIDEODRIVER=wayland; shift ;;
        --log) TEE_LOG=1; shift ;;
        --jkdf2-root=*) export OPENJKDF2_ROOT="${1#*=}"; shift ;;
        --jkdf2-root) export OPENJKDF2_ROOT="$2"; shift 2 ;;
        --mots-root=*) export OPENJKMOTS_ROOT="${1#*=}"; shift ;;
        --mots-root) export OPENJKMOTS_ROOT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --)
            shift
            EXTRA_ARGS+=("$@")
            break
            ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) EXTRA_ARGS+=("$1"); shift ;;
    esac
done

if [[ $USE_DEV -eq 1 ]]; then
    BIN="$ROOT/OpenJKDF2/build_linux64/openjkdf2"
    LIBS="$ROOT/OpenJKDF2/build_linux64"
else
    BIN="$PORT/openjkdf2.$ARCH"
    LIBS="$PORT/libs.$ARCH"
fi

if [[ ! -x "$BIN" ]]; then
    echo "ERROR: Binary not found or not executable: $BIN" >&2
    if [[ $USE_DEV -eq 1 ]]; then
        echo "Build it with: cd OpenJKDF2 && ./build_linux64.sh" >&2
    else
        echo "Build it with: ./build.sh --native   (or ./build.sh for Docker x86_64)" >&2
    fi
    exit 1
fi

if [[ -z "${OPENJKDF2_ROOT:-}" ]]; then
    if has_jkdf2_data "$PORT/jk1"; then
        OPENJKDF2_ROOT="$PORT/jk1"
    elif [[ $USE_STEAM -eq 1 ]] && jk="$(find_steam_jkdf2)"; then
        OPENJKDF2_ROOT="$jk"
        echo "Using Steam JKDF2: $OPENJKDF2_ROOT"
    else
        echo "ERROR: No JKDF2 game data found." >&2
        echo "  ./run.sh --setup-steam" >&2
        echo "  ./run.sh --jkdf2-root=/path/to/jkdf2" >&2
        echo "  Copy GOG/Steam files into port/openjkdf2/jk1/" >&2
        exit 1
    fi
fi

export OPENJKDF2_ROOT

if [[ $MOTS -eq 1 ]]; then
  export OPENJKDF2_MOTS=1
  EXTRA_ARGS+=("-motsCompat")
fi

if [[ -z "${OPENJKMOTS_ROOT:-}" ]]; then
    if has_jkdf2_data "$PORT/mots"; then
        OPENJKMOTS_ROOT="$PORT/mots"
    elif [[ $USE_STEAM -eq 1 ]] && mots="$(find_steam_mots)"; then
        OPENJKMOTS_ROOT="$mots"
    fi
fi
[[ -n "${OPENJKMOTS_ROOT:-}" ]] && export OPENJKMOTS_ROOT

mkdir -p "$CONFDIR/openjkdf2" "$CONFDIR/openjkmots"
export XDG_DATA_HOME="$CONFDIR"

if [[ -d "$LIBS" ]]; then
    export LD_LIBRARY_PATH="$LIBS${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

cd "$PORT"

echo "Binary:  $BIN"
echo "JKDF2:   $OPENJKDF2_ROOT"
[[ -n "${OPENJKMOTS_ROOT:-}" ]] && echo "MOTS:    $OPENJKMOTS_ROOT"
[[ -n "${OPENJKDF2_FORCE_GL:-}" ]] && echo "GL:      force desktop (OPENJKDF2_FORCE_GL)"
[[ -n "${OPENJKDF2_FORCE_GLES:-}" ]] && echo "GL:      force GLES (OPENJKDF2_FORCE_GLES)"
[[ -n "${SDL_VIDEODRIVER:-}" ]] && echo "SDL:     SDL_VIDEODRIVER=$SDL_VIDEODRIVER"
echo

if [[ $TEE_LOG -eq 1 ]]; then
    : >"$PORT/log.txt"
    exec > >(tee "$PORT/log.txt") 2>&1
fi

exec "$BIN" "${EXTRA_ARGS[@]}"
