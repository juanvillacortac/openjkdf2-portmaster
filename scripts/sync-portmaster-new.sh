#!/bin/bash
# Sync jkdf2/port → ~/PortMaster-New/ports/openjkdf2/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_PORT="$ROOT/port"
DEST="${PORTMASTER_NEW:-$HOME/PortMaster-New}/ports/openjkdf2"

if [[ ! -d "$SRC_PORT/openjkdf2" ]]; then
    echo "ERROR: Missing $SRC_PORT/openjkdf2" >&2
    exit 1
fi
if [[ ! -d "$(dirname "$DEST")" ]]; then
    echo "ERROR: PortMaster-New not found at $(dirname "$DEST")" >&2
    echo "Set PORTMASTER_NEW to your PortMaster-New clone." >&2
    exit 1
fi

mkdir -p "$DEST"

# PortMaster metadata + launchers (root of ports/openjkdf2/)
for f in \
    port.json README.md gameinfo.xml \
    screenshot.jpg screenshot.png cover.jpg cover.png \
    "Star Wars Jedi Knight - Dark Forces II.sh" \
    "Star Wars Jedi Knight - Mysteries of the Sith.sh"
do
    [[ -f "$SRC_PORT/$f" ]] && cp -a "$SRC_PORT/$f" "$DEST/"
done

# openjkdf2/ game tree — never copy libs .gitkeep placeholders
rsync -a \
    --exclude 'log.txt' \
    --exclude 'startup.log' \
    --exclude 'jk1/openjkdf2_cvars.json' \
    --exclude 'jk1/registry.json' \
    --exclude 'conf/mp.conf' \
    --exclude 'conf/mp.conf.bk' \
    --exclude 'libs.aarch64/.gitkeep' \
    --exclude 'libs.x86_64/.gitkeep' \
    --exclude 'libs.armhf/.gitkeep' \
    "$SRC_PORT/openjkdf2/" "$DEST/openjkdf2/"

# Remove stale libs .gitkeep and legacy helper names
rm -f \
    "$DEST/openjkdf2/libs.aarch64/.gitkeep" \
    "$DEST/openjkdf2/libs.x86_64/.gitkeep" \
    "$DEST/openjkdf2/libs.armhf/.gitkeep" \
    "$DEST/openjkdf2/run-dedicated.sh" \
    "$DEST/openjkdf2/run-mpserver.sh" \
    "$DEST/openjkdf2/run-mpserver.run" \
    "$DEST/openjkdf2/mpserver-entrypoint.sh" 2>/dev/null || true

chmod +x \
    "$DEST/openjkdf2/run-dedicated.run" \
    "$DEST/openjkdf2/helpers/mpserver-entrypoint.run" 2>/dev/null || true

echo "Synced to: $DEST"
echo "  openjkdf2.aarch64: $(ls -lh "$DEST/openjkdf2/openjkdf2.aarch64" 2>/dev/null | awk '{print $5}' || echo missing)"
echo "Next: cd \"\${PORTMASTER_NEW:-$HOME/PortMaster-New}\" && git add ports/openjkdf2 && git commit && git push fork openjkdf2-port"
