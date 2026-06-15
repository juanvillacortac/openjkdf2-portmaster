#!/bin/bash
# Fail if a binary or shared lib needs glibc newer than the target CFW.
set -euo pipefail

# ArkOS (and many older PortMaster CFWs) ship glibc 2.30.
MAX_GLIBC="${OPENJKDF2_MAX_GLIBC:-2.30}"

ver_to_num() {
    local v="${1#GLIBC_}"
    local maj min
    maj="${v%%.*}"
    min="${v#*.}"
    min="${min%%.*}"
    echo $((maj * 1000 + min))
}

max_required() {
    local f="$1"
    local max=0 sym n
    while IFS= read -r sym; do
        [[ -z "$sym" ]] && continue
        n=$(ver_to_num "$sym")
        (( n > max )) && max=$n
    done < <(strings "$f" 2>/dev/null | grep -E '^GLIBC_[0-9]+\.[0-9]+$' || true)
    echo "$max"
}

check_file() {
    local f="$1"
    local req max_n limit_n

    [[ -f "$f" ]] || return 0
    req=$(max_required "$f")
    max_n=$(ver_to_num "GLIBC_$MAX_GLIBC")
    if (( req > max_n )); then
        local got
        got=$(strings "$f" | grep -E '^GLIBC_[0-9]+\.[0-9]+$' | sort -V | tail -1)
        echo "ERROR: $f requires $got (limit GLIBC_$MAX_GLIBC for ArkOS/older CFW)" >&2
        return 1
    fi
    local got
    got=$(strings "$f" | grep -E '^GLIBC_[0-9]+\.[0-9]+$' | sort -V | tail -1)
    echo "  OK  $(basename "$f"): max $got"
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${1:-$ROOT/OpenJKDF2/build_aarch64/openjkdf2}"
LIBS="${2:-$ROOT/port/openjkdf2/libs.aarch64}"

echo "== glibc check (target <= GLIBC_$MAX_GLIBC, ArkOS) =="
rc=0
check_file "$BIN" || rc=1
if [[ -d "$LIBS" ]]; then
    for so in "$LIBS"/*.so*; do
        [[ -f "$so" ]] || continue
        check_file "$so" || rc=1
    done
fi
exit "$rc"
