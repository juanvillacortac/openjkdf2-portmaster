#!/bin/bash
# Create empty PortMaster folder layout under port/openjkdf2/.
# Does NOT copy game files — the end user installs GOG/Steam assets into jk1/ (and mots/).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="$ROOT/port/openjkdf2"

mkdir -p "$PORT/jk1" "$PORT/mots" "$PORT/expansions" "$PORT/mods" "$PORT/conf" "$PORT/licenses" "$PORT/libs.aarch64" "$PORT/libs.x86_64"
mkdir -p "$PORT/jk1/controls"

write_placeholder() {
    local dir="$1"
    local text="$2"
    mkdir -p "$dir"
    local file="$dir/README.txt"
    if [[ ! -f "$file" ]]; then
        printf '%s\n' "$text" >"$file"
        echo "  $(realpath --relative-to="$PORT" "$dir")/README.txt"
    fi
}

echo "== Port layout at $PORT =="

write_placeholder "$PORT/jk1" \
"Jedi Knight: Dark Forces II game files (GOG or Steam).

Copy your install here:
  episode/   JK1.gob, JK1CTF.gob, JK1MP.gob
  resource/  Res1hi.gob, Res2.gob, jk_.cd, video/
  MUSIC/     Track*.ogg (optional but recommended)
  player/    created when you play

Optional: controls/ for jk_.cfg from the original game.

If resource/jk_.cd is missing, copy JK_.CD from GOG as jk_.cd (lowercase).

Switch to Mysteries of the Sith in-game: Main menu -> Expansions & Mods."

write_placeholder "$PORT/jk1/controls" \
"Optional folder for original game control files (jk_.cfg, etc.)."

write_placeholder "$PORT/mots" \
"Mysteries of the Sith: copy episode/, resource/, MUSIC/, and player/ from your MOTS install here.
Switch from JKDF2 in-game: Main menu -> Expansions & Mods -> Launch Mysteries of the Sith."

write_placeholder "$PORT/expansions" \
"Extra campaigns and expansions (.gob). The Expansions & Mods menu picks them up from here."

write_placeholder "$PORT/mods" \
"Mod packs as .gob files. Drop them in this folder."

write_placeholder "$PORT/conf" \
"OpenJKDF2 saves and settings (conf/openjkdf2/). Created when you play."

echo ""
echo "Done. Game data is NOT included — copy GOG/Steam files to jk1/ on the device."
echo "Build and package: ./build.sh"
