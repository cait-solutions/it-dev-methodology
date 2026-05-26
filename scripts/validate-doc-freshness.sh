#!/bin/bash
# validate-doc-freshness.sh — Level 4 structural check: OVERVIEW.md date vs git log
# Bash 3.2+ compatible (no associative arrays, no ${var,,}, no date -d)
#
# Usage: bash scripts/validate-doc-freshness.sh [--root PATH] [--days N] [--ignore-exit]
# Exit 0 = all OVERVIEW files fresh (or no services dir); Exit 1 = stale found; Exit 2 = config error
#
# Checks:
#   STALE  : git log date for docs/services/<svc>/ is newer than OVERVIEW "Обновлён:" field by > N days
#   MISSING: OVERVIEW.md exists but has no "Обновлён:" field (warn, not error)
#   NO_GIT : git log returns empty for service dir (shallow clone or no history — skip gracefully)

ROOT="."
DAYS=14
IGNORE_EXIT=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)        ROOT="$2"; shift 2 ;;
        --days)        DAYS="$2"; shift 2 ;;
        --ignore-exit) IGNORE_EXIT=1; shift ;;
        *) echo "Unknown arg: $1"; exit 2 ;;
    esac
done

SERVICES_DIR="$ROOT/docs/services"

if [ ! -d "$SERVICES_DIR" ]; then
    echo "INFO: $SERVICES_DIR not found — no services to check. Exit 0."
    exit 0
fi

# Check git availability
if ! git -C "$ROOT" rev-parse --git-dir > /dev/null 2>&1; then
    echo "WARN: $ROOT is not a git repository — skipping freshness check."
    exit 0
fi

# Parse ISO date from OVERVIEW "Обновлён:" field
# Handles: "**Обновлён:** 2026-05-13" and "Обновлён: 2026-05-13"
parse_overview_date() {
    overview="$1"
    sed -n 's/.*Обновлён[^0-9]*\([0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\).*/\1/p' "$overview" | head -1
}

# ISO date subtraction in days using only POSIX tools available in Bash 3.2 + Git Bash
# Converts YYYY-MM-DD to days-since-epoch via awk (portable, no date -d needed)
iso_to_days() {
    echo "$1" | awk -F'-' '
    {
        y=$1; m=$2; d=$3
        # Days in each month (non-leap year baseline)
        days_in_month = "0 31 28 31 30 31 30 31 31 30 31 30 31"
        split(days_in_month, dim, " ")
        # Leap year adjustment for Feb
        if ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0) dim[3] = 29
        total = (y - 1) * 365 + int((y-1)/4) - int((y-1)/100) + int((y-1)/400)
        for (i = 1; i < m; i++) total += dim[i]
        total += d
        print total
    }'
}

# ──────────────────────────────────────────────
STALE_COUNT=0
WARN_COUNT=0
CHECKED=0

for svc_dir in "$SERVICES_DIR"/*/; do
    [ -d "$svc_dir" ] || continue
    svc_name=$(basename "$svc_dir")
    overview="$svc_dir/OVERVIEW.md"

    [ -f "$overview" ] || continue

    CHECKED=$((CHECKED + 1))

    # 1. Parse Обновлён date
    overview_date=$(parse_overview_date "$overview")
    if [ -z "$overview_date" ]; then
        echo "WARN  [$svc_name] OVERVIEW.md has no 'Обновлён: YYYY-MM-DD' field"
        WARN_COUNT=$((WARN_COUNT + 1))
        continue
    fi

    # 2. Get last git commit date for this service's docs dir (relative to ROOT)
    rel_svc_dir="docs/services/$svc_name"
    git_date=$(git -C "$ROOT" log -1 --format="%as" -- "$rel_svc_dir" 2>/dev/null)
    if [ -z "$git_date" ]; then
        echo "INFO  [$svc_name] no git history for $rel_svc_dir — skipping"
        continue
    fi

    # 3. Compare: if git_date > overview_date by more than DAYS → STALE
    overview_days=$(iso_to_days "$overview_date")
    git_days=$(iso_to_days "$git_date")
    diff=$((git_days - overview_days))

    if [ "$diff" -gt "$DAYS" ]; then
        echo "STALE [$svc_name] OVERVIEW says $overview_date but docs last changed $git_date (drift: ${diff}d > ${DAYS}d threshold)"
        STALE_COUNT=$((STALE_COUNT + 1))
    elif [ "$diff" -gt 0 ]; then
        echo "OK    [$svc_name] OVERVIEW $overview_date, docs $git_date (drift: ${diff}d ≤ ${DAYS}d — within threshold)"
    else
        echo "OK    [$svc_name] OVERVIEW $overview_date, docs $git_date"
    fi
done

echo ""
echo "Checked: $CHECKED services | STALE: $STALE_COUNT | WARN: $WARN_COUNT"

if [ "$STALE_COUNT" -gt 0 ]; then
    echo "→ Update 'Обновлён:' field in STALE OVERVIEW files before planning."
    if [ "$IGNORE_EXIT" -eq 1 ]; then exit 0; fi
    exit 1
fi

exit 0
