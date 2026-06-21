#!/usr/bin/env bash
#
# validate-log-merge.sh — section-count guard for union-merged logs (closes G-117 companion).
#
# Detection layer for the `merge=union` mechanism (.gitattributes): union NEVER
# loses lines AS LONG AS a true 3-way merge fires. If the merge strategy is ever
# changed to squash/rebase, union does not fire and append-entries can be lost on
# integration. This guard catches that regression by asserting the count of
# top-level log sections (`## ` headers) in the working tree is NOT LESS than at
# the given baseline ref (append-only logs only ever grow).
#
# Severity: WARN by default (exit 0 + message). Set SECTION_GUARD_SEVERITY=error
# to make a shrink block (exit 1). A shrink is not always a bug (intentional
# history prune) — hence warn — but it must never be silent.
#
# Usage:
#   bash scripts/validate-log-merge.sh [BASELINE_REF]
#   BASELINE_REF default: HEAD  (compare working tree vs last commit)
#
# Bash 3.2 compatible (Git Bash on Windows). No bash 4 features.

set -u

BASELINE_REF="${1:-HEAD}"
SEVERITY="${SECTION_GUARD_SEVERITY:-warn}"

# Files to guard: "path:header_regex". Only checked if the path exists.
# CHANGELOG sections = "## v..."; dated logs/registries vary, so use "^## ".
GUARDED="
CHANGELOG.md:^##
DEVLOG.md:^##
AGENT-GAPS.md:^Gap-ID:
PRODUCT-GAPS.md:^Gap-ID:
"

shrink_found=0
checked=0

# Count matches of a regex in text supplied on stdin.
_count() { grep -cE "$1" 2>/dev/null || true; }

echo "=== validate-log-merge.sh (baseline: $BASELINE_REF, severity: $SEVERITY) ==="

while IFS= read -r line; do
  [ -z "$line" ] && continue
  file="${line%%:*}"
  rx="${line#*:}"
  [ -f "$file" ] || continue
  # baseline content (file may not exist at baseline → count 0)
  base_n=$(git show "${BASELINE_REF}:${file}" 2>/dev/null | _count "$rx")
  base_n="${base_n:-0}"
  wt_n=$(_count "$rx" < "$file")
  wt_n="${wt_n:-0}"
  checked=$((checked + 1))
  if [ "$wt_n" -lt "$base_n" ]; then
    echo "  ⚠️  $file: sections $base_n → $wt_n (DECREASED by $((base_n - wt_n)))"
    shrink_found=1
  else
    echo "  ✅ $file: sections $base_n → $wt_n"
  fi
done <<EOF
$GUARDED
EOF

if [ "$checked" -eq 0 ]; then
  echo "⚪ SKIP — no guarded log files present."
  exit 2
fi

if [ "$shrink_found" -eq 1 ]; then
  echo ""
  echo "⚠️  Log section count decreased vs $BASELINE_REF."
  echo "    Возможные причины: union merge не сработал (squash/rebase merge-стратегия?),"
  echo "    либо записи удалены вручную. Проверь что .gitattributes merge=union в силе"
  echo "    и что merge идёт через 'gh pr merge --merge' (true 3-way), не squash."
  [ "$SEVERITY" = "error" ] && exit 1
fi

exit 0
