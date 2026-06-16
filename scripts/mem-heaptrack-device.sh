#!/bin/bash
# Optional: record malloc call stacks on the handheld (needs heaptrack on device).
#
# Most PortMaster CFWs do NOT ship heaptrack. Check first:
#   which heaptrack heaptrack_interpret
#
# If missing, use mem-log-gameplay.sh for RSS, or heaptrack on PC (build_linux64).
#
# Usage:
#   cd /roms/ports/openjkdf2   # or your GAMEDIR
#   bash /path/to/mem-heaptrack-device.sh ./openjkdf2.aarch64
#
# After quitting, copy to PC:
#   scp root@<ip>:/tmp/openjkdf2.ht .
#   heaptrack_gui openjkdf2.ht    # on PC

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: $0 /path/to/openjkdf2[.aarch64] [game args...]" >&2
    exit 1
fi

BIN="$1"
shift

if ! command -v heaptrack >/dev/null 2>&1; then
    echo "heaptrack not found on this device." >&2
    echo "Use scripts/mem-log-gameplay.sh for RSS, or on PC:" >&2
    echo "  pacman -S heaptrack heaptrack_gui" >&2
    echo "  cd OpenJKDF2/build_linux64 && heaptrack -o jk.ht ./openjkdf2" >&2
    exit 1
fi

OUT="/tmp/openjkdf2-$(date +%Y%m%d-%H%M%S).ht"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"

echo "Recording -> $OUT"
echo "Play normally, then quit the game to finish."
exec heaptrack -o "$OUT" "$BIN" "$@"
