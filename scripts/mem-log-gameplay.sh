#!/bin/bash
# Log OpenJKDF2 RSS during gameplay over SSH. No extra packages required.
#
# Usage (on the handheld, while the game is running or about to start):
#   bash /tmp/mem-log-gameplay.sh -o /tmp/jk-mem-DF2
#   bash /tmp/mem-log-gameplay.sh -p openjkdf2.aarch64 -o /tmp/jk-mem-DF2
#
# While logging, open another SSH session and mark milestones:
#   touch /tmp/jk-mem-DF2/mark-menu
#   touch /tmp/jk-mem-DF2/mark-loading
#   touch /tmp/jk-mem-DF2/mark-ingame
#
# Then stop with Ctrl+C. Copy the output folder to your PC:
#   scp -r root@<ip>:/tmp/jk-mem-DF2 ./

set -euo pipefail

INTERVAL=1
OUT_BASE="/tmp/jk-mem-$(date +%Y%m%d-%H%M%S)"
PROC_PATTERN='openjkdf2.aarch64'
WAIT_SEC=120
MIN_RSS_KB=32768

usage() {
    sed -n '2,14p' "$0"
    exit "${1:-0}"
}

while getopts ":hi:o:p:w:m:" opt; do
    case "$opt" in
        h) usage 0 ;;
        i) INTERVAL="$OPTARG" ;;
        o) OUT_BASE="$OPTARG" ;;
        p) PROC_PATTERN="$OPTARG" ;;
        w) WAIT_SEC="$OPTARG" ;;
        m) MIN_RSS_KB="$OPTARG" ;;
        *) usage 1 ;;
    esac
done

mkdir -p "$OUT_BASE"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$OUT_BASE/session.log"; }

read_proc_field() {
    local pid="$1" field="$2" line val
    while IFS= read -r line; do
        case "$line" in
            "$field:"*)
                val=${line#*:}
                val=${val%%kB*}
                val=${val// /}
                echo "$val"
                return 0
                ;;
        esac
    done < "/proc/$pid/status"
    echo ""
}

proc_comm() {
    local pid="$1"
    tr -d '\n' < "/proc/$pid/comm" 2>/dev/null || echo ""
}

proc_rss_kb() {
    local pid="$1"
    read_proc_field "$pid" VmRSS
}

is_ignored_pid() {
    local pid="$1" comm cmdline
    comm=$(proc_comm "$pid")
    case "$comm" in
        tee|gptokeyb|bash|sh|python|python3|PortMaster|control.txt) return 0 ;;
    esac
    if [[ ! -r "/proc/$pid/cmdline" ]]; then
        return 1
    fi
    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
    case "$cmdline" in
        *log.txt*|*tee*|*gptokeyb*) return 0 ;;
    esac
    return 1
}

find_pid() {
    local pid comm rss best_pid="" best_rss=0
    if ! command -v pgrep >/dev/null 2>&1; then
        pidof "$PROC_PATTERN" 2>/dev/null | awk '{print $1}'
        return
    fi
    while read -r pid; do
        [[ -n "$pid" ]] || continue
        is_ignored_pid "$pid" && continue
        comm=$(proc_comm "$pid")
        rss=$(proc_rss_kb "$pid")
        rss=${rss:-0}
        # Prefer the real binary name over loose cmdline matches.
        if [[ "$comm" == "$PROC_PATTERN" || "$comm" == openjkdf2 ]]; then
            echo "$pid"
            return
        fi
        if [[ "$rss" -ge "$MIN_RSS_KB" && "$rss" -gt "$best_rss" ]]; then
            best_pid="$pid"
            best_rss="$rss"
        fi
    done < <(pgrep -f "$PROC_PATTERN" 2>/dev/null | sort -u)
    if [[ -n "$best_pid" ]]; then
        echo "$best_pid"
        return
    fi
    # Fallback: highest RSS among non-ignored matches.
    best_pid=""
    best_rss=0
    while read -r pid; do
        [[ -n "$pid" ]] || continue
        is_ignored_pid "$pid" && continue
        rss=$(proc_rss_kb "$pid")
        rss=${rss:-0}
        if [[ "$rss" -gt "$best_rss" ]]; then
            best_pid="$pid"
            best_rss="$rss"
        fi
    done < <(pgrep -f "$PROC_PATTERN" 2>/dev/null | sort -u)
    [[ -n "$best_pid" ]] && echo "$best_pid"
}

dump_smaps_rollup() {
    local pid="$1" tag="$2"
    local out="$OUT_BASE/smaps_rollup-${tag}.txt"
    {
        echo "# tag=$tag pid=$pid time=$(date '+%Y-%m-%dT%H:%M:%S')"
        if [[ -r "/proc/$pid/smaps_rollup" ]]; then
            cat "/proc/$pid/smaps_rollup"
        else
            echo "smaps_rollup not available"
        fi
        echo
        echo "# /proc/$pid/status"
        cat "/proc/$pid/status"
    } > "$out"
    log "snapshot $tag -> $(basename "$out")"
}

dump_top_mappings() {
    local pid="$1" tag="$2"
    local out="$OUT_BASE/top-mappings-${tag}.txt"
    if [[ ! -r "/proc/$pid/smaps" ]]; then
        return 0
    fi
    awk '
        /^[0-9a-f]/ { range=$0 }
        /^Rss:/ {
            rss=$2
            if (rss+0 >= 1024) {
                name=range
                sub(/^[0-9a-f-]+ +[0-9a-f-]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +/, "", name)
                if (name == "") name="[anon]"
                printf "%8d kB  %s\n", rss, name
            }
        }
    ' "/proc/$pid/smaps" | sort -nr | head -40 > "$out"
    log "top mappings $tag -> $(basename "$out") ($(wc -l < "$out") lines)"
}

write_meta() {
    cat > "$OUT_BASE/meta.txt" <<EOF
device=$(uname -a)
proc_pattern=$PROC_PATTERN
min_rss_kb=$MIN_RSS_KB
interval_sec=$INTERVAL
out_base=$OUT_BASE
meminfo_begin:
$(grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo 2>/dev/null || true)
EOF
}

write_meta
CSV="$OUT_BASE/rss-timeseries.csv"
echo "epoch,iso_time,pid,rss_kb,swap_kb,vmdata_kb,marker" > "$CSV"

log "waiting up to ${WAIT_SEC}s for /$PROC_PATTERN/ with RSS >= ${MIN_RSS_KB} kB ..."
PID=""
for ((i = 0; i < WAIT_SEC; i++)); do
    PID=$(find_pid || true)
    if [[ -n "$PID" ]]; then
        rss=$(proc_rss_kb "$PID")
        comm=$(proc_comm "$PID")
        if [[ "${rss:-0}" -ge "$MIN_RSS_KB" || "$comm" == "$PROC_PATTERN" || "$comm" == openjkdf2 ]]; then
            break
        fi
        PID=""
    fi
    sleep 1
done

if [[ -z "$PID" ]]; then
    log "ERROR: game process not found."
    log "Hint: launch the game first, then run:"
    log "  bash $0 -p openjkdf2.aarch64 -o /tmp/jk-mem-DF2"
    log "Or attach manually: ps aux | grep openjkdf2"
    exit 1
fi

comm=$(proc_comm "$PID")
rss=$(proc_rss_kb "$PID")
log "attached pid=$PID comm=$comm rss=${rss}kB out=$OUT_BASE (interval=${INTERVAL}s)"
log "milestones: touch ${OUT_BASE}/mark-<name> from another SSH session"
dump_smaps_rollup "$PID" "00-start"
dump_top_mappings "$PID" "00-start"

MARKER_DIR="$OUT_BASE/markers"
mkdir -p "$MARKER_DIR"

cleanup() {
    if [[ -n "${PID:-}" ]] && [[ -d "/proc/$PID" ]]; then
        dump_smaps_rollup "$PID" "99-stop"
        dump_top_mappings "$PID" "99-stop"
    fi
    {
        echo
        echo "meminfo_end:"
        grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo 2>/dev/null || true
    } >> "$OUT_BASE/meta.txt"
    log "done. copy folder to PC: scp -r <device>:$OUT_BASE ."
}
trap cleanup EXIT INT TERM

while [[ -d "/proc/$PID" ]]; do
    now=$(date +%s)
    iso=$(date '+%Y-%m-%d %H:%M:%S')
    rss=$(read_proc_field "$PID" VmRSS)
    swap=$(read_proc_field "$PID" VmSwap)
    vmdata=$(read_proc_field "$PID" VmData)

    marker=""
    for f in "$OUT_BASE"/mark-*; do
        [[ -e "$f" ]] || continue
        base=$(basename "$f")
        name=${base#mark-}
        if [[ ! -f "$MARKER_DIR/$base.done" ]]; then
            marker="$name"
            touch "$MARKER_DIR/$base.done"
            dump_smaps_rollup "$PID" "$name"
            dump_top_mappings "$PID" "$name"
            log "marker $name rss=${rss}kB"
        fi
    done

    echo "$now,$iso,$PID,${rss:-},${swap:-},${vmdata:-},$marker" >> "$CSV"

    new_pid=$(find_pid || true)
    if [[ -n "$new_pid" && "$new_pid" != "$PID" ]]; then
        log "pid changed $PID -> $new_pid"
        PID="$new_pid"
    fi

    sleep "$INTERVAL"
done

log "process exited"
