#!/usr/bin/env bash
#
# secrets-scrub.sh — find token-shaped strings in transcripts and logs.
#
# Use case: after a leak (or as periodic hygiene check), scan local Claude Code
# transcripts (`~/.claude/projects/`) and other configured paths for known
# token prefixes. Default mode is READ-ONLY (report only).
#
# Usage:
#   bash scripts/secrets-scrub.sh                 # report only
#   bash scripts/secrets-scrub.sh --clean         # destructive: overwrite matches with [REDACTED]
#                                                  (prompts for confirmation)
#   bash scripts/secrets-scrub.sh --paths a,b,c   # custom paths
#
# Exit codes:
#   0  no exposures found
#   1  exposures found (count printed to stderr)
#   2  usage / config error
#
# Bash 3.2 compatible.

set -euo pipefail

MANIFEST=".claude/secrets-manifest.yaml"

# Default token patterns — extensible via manifest config.extra_patterns.
PATTERNS=(
  'ghp_[A-Za-z0-9]{36,}'
  'github_pat_[A-Za-z0-9_]{40,}'
  'gho_[A-Za-z0-9]{36,}'
  'ghs_[A-Za-z0-9]{36,}'
  'ghu_[A-Za-z0-9]{36,}'
  'sk-ant-[A-Za-z0-9_-]{32,}'
  'sk-[A-Za-z0-9]{32,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'AKIA[0-9A-Z]{16}'
  'ya29\.[A-Za-z0-9_-]{20,}'
)

# Default scrub paths (overridable via --paths or manifest config.scrub_paths).
DEFAULT_PATHS=(
  "$HOME/.claude/projects"
  "$HOME/.claude/history"
)

# Parse args
CLEAN=false
CUSTOM_PATHS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      CLEAN=true
      shift
      ;;
    --paths)
      CUSTOM_PATHS="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      echo "See: bash $0 --help" >&2
      exit 2
      ;;
  esac
done

# Load extra patterns from manifest.
if [[ -f "$MANIFEST" ]]; then
  while IFS= read -r extra; do
    [[ -z "$extra" ]] && continue
    PATTERNS+=("$extra")
  done < <(awk '
    /^[[:space:]]*extra_patterns:[[:space:]]*\[\][[:space:]]*$/ { next }
    /^[[:space:]]*extra_patterns:[[:space:]]*$/ { capture=1; next }
    capture && /^[[:space:]]*-[[:space:]]*["'"'"']/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      next
    }
    capture && !/^[[:space:]]*-/ && /^[[:space:]]*[a-z_]+:/ { exit }
  ' "$MANIFEST")
fi

# Load scrub paths from manifest if no --paths given.
if [[ -z "$CUSTOM_PATHS" && -f "$MANIFEST" ]]; then
  manifest_paths=$(awk '
    /^[[:space:]]*scrub_paths:[[:space:]]*$/ { capture=1; next }
    capture && /^[[:space:]]*-[[:space:]]*["'"'"']?/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      next
    }
    capture && !/^[[:space:]]*-/ && /^[[:space:]]*[a-z_]+:/ { exit }
  ' "$MANIFEST")
  if [[ -n "$manifest_paths" ]]; then
    PATHS=()
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      # Expand ~ → $HOME
      p="${p/#\~/$HOME}"
      PATHS+=("$p")
    done <<< "$manifest_paths"
  else
    PATHS=("${DEFAULT_PATHS[@]}")
  fi
elif [[ -n "$CUSTOM_PATHS" ]]; then
  IFS=',' read -ra PATHS <<< "$CUSTOM_PATHS"
else
  PATHS=("${DEFAULT_PATHS[@]}")
fi

# Build combined pattern for grep (one big alternation).
ALT_PATTERN=$(printf '|%s' "${PATTERNS[@]}")
ALT_PATTERN="${ALT_PATTERN:1}"

echo "Scrub paths:" >&2
for p in "${PATHS[@]}"; do
  echo "  $p $([[ -e "$p" ]] && echo "(exists)" || echo "(missing — skipped)")" >&2
done
echo "Patterns: ${#PATTERNS[@]} token shapes" >&2
echo "" >&2

# Collect matches
matches_count=0
matched_files=()

for path in "${PATHS[@]}"; do
  [[ -e "$path" ]] || continue
  if [[ -d "$path" ]]; then
    while IFS= read -r -d '' file; do
      # Skip binary files quickly
      if file "$file" 2>/dev/null | grep -q "binary"; then
        continue
      fi
      count=$(grep -cE "$ALT_PATTERN" "$file" 2>/dev/null || echo 0)
      if [[ "$count" -gt 0 ]]; then
        matched_files+=("$file:$count")
        matches_count=$((matches_count + count))
      fi
    done < <(find "$path" -type f \( -name "*.jsonl" -o -name "*.json" -o -name "*.md" -o -name "*.txt" -o -name "*.log" \) -print0 2>/dev/null)
  elif [[ -f "$path" ]]; then
    count=$(grep -cE "$ALT_PATTERN" "$path" 2>/dev/null || echo 0)
    if [[ "$count" -gt 0 ]]; then
      matched_files+=("$path:$count")
      matches_count=$((matches_count + count))
    fi
  fi
done

if [[ ${#matched_files[@]} -eq 0 ]]; then
  echo "✅ No token-shaped strings found in scanned paths."
  exit 0
fi

echo "⚠️  Found $matches_count potential token exposure(s) across ${#matched_files[@]} file(s):"
echo ""
for entry in "${matched_files[@]}"; do
  echo "  $entry"
done
echo ""
echo "Action required:"
echo "  1. ROTATE every token that may have been exposed at the provider IMMEDIATELY."
echo "     Treat these as compromised regardless of file age."
echo "  2. Run: bash scripts/set-secret.sh KEY <new-value>"
echo "  3. To overwrite matches with [REDACTED] (destructive):"
echo "       bash scripts/secrets-scrub.sh --clean"
echo "  4. Check git history: git log -p --all -S '<token-prefix>'"
echo "     If found in history: git filter-repo + force-push + notify contributors."
echo ""

if [[ "$CLEAN" == "true" ]]; then
  echo "DESTRUCTIVE CLEAN mode requested."
  echo "This will overwrite token-shaped strings with [REDACTED-SECRETS-SCRUB] in:"
  for entry in "${matched_files[@]}"; do
    echo "  ${entry%:*}"
  done
  read -p "Proceed? (type 'yes' to confirm): " confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted." >&2
    exit 1
  fi
  for entry in "${matched_files[@]}"; do
    f="${entry%:*}"
    # Backup first
    cp "$f" "$f.scrub-backup-$(date +%s)"
    # Replace matches in-place
    py - "$f" "$ALT_PATTERN" <<'PYEOF'
import re, sys
fp = sys.argv[1]
pat = sys.argv[2]
with open(fp, "r", encoding="utf-8", errors="replace") as fh:
    data = fh.read()
data = re.sub(pat, "[REDACTED-SECRETS-SCRUB]", data)
with open(fp, "w", encoding="utf-8") as fh:
    fh.write(data)
PYEOF
    echo "  ✓ scrubbed $f (backup: $f.scrub-backup-*)"
  done
  echo ""
  echo "✅ Scrub complete. Verify with: bash scripts/secrets-scrub.sh"
fi

exit 1
