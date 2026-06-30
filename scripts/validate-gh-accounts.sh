#!/usr/bin/env bash
#
# validate-gh-accounts.sh — correctness warn for the OPTIONAL gh_account pre-seed.
#
# WHY (council [opinion:git-account-ssot], 2026-06-30 — reverses the old presence-gate):
#   Old behaviour: exit 1 (block deploy) if any github.com repo in auto_commit_consumers
#   lacked an explicit gh_account. That presence-gate PASSED the 2026-06-30 incident: the
#   field was PRESENT but STALE (cait-solutions) while the URL owner (IDK-IDK) was correct
#   → push under the stale account → 404. Presence ≠ correctness.
#
#   New model: gh_account is now an OPTIONAL pre-seed. The authoritative resolver
#   (lib/gh-account.sh: learned cache → URL-owner) makes a missing field harmless and a
#   stale field harmless (URL/cache win). So this script no longer BLOCKS — it WARNS when a
#   pre-seed gh_account is set AND disagrees with BOTH the URL-owner AND the learned cache
#   (i.e. a stale manual override that, while harmless, signals config rot worth cleaning).
#
# Called from deploy-push.sh inside the methodology guard. Consumers guard=false → skipped.
#
# Exit 0 = always (warn-only — never blocks deploy).
#
# Bash 3.2+ compatible (Git Bash on Windows): no associative arrays, no ${var,,}.

set -uo pipefail

CONFIG="${1:-CLAUDE.local.md}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METHODOLOGY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -f "$CONFIG" ]; then
  echo "  ⚡ validate-gh-accounts: $CONFIG not found — skip." >&2
  exit 0
fi

# Source the gh-account lib (URL-owner + cache lookup). Defensive inline fallback.
if [ -f "$SCRIPT_DIR/lib/gh-account.sh" ]; then
  # shellcheck source=scripts/lib/gh-account.sh
  . "$SCRIPT_DIR/lib/gh-account.sh"
else
  gh_owner_from_url() { case "${1:-}" in https://github.com/*) local o="${1#https://github.com/}"; o="${o%%/*}"; printf '%s\n' "${o%.git}";; *) printf '%s\n' "";; esac; }
  gh_cache_get() { printf '%s\n' ""; }
fi

# _parse_whitelist: outputs TSV "RELATIVE_PATH\tGH_ACCOUNT" per entry (GH_ACCOUNT empty if absent).
_parse_whitelist() {
  awk '
    /^```yaml/ && !in_block { in_block=1; next }
    /^```/ && in_block       { in_block=0; in_consumers=0; next }
    !in_block                { next }
    /auto_commit_consumers:/ { in_consumers=1; next }
    !in_consumers            { next }
    /^  - path:/ {
      if (entry_path != "") { print entry_path "\t" entry_gh }
      entry_path = $0
      sub(/^[^:]*:[[:space:]]*/, "", entry_path)
      sub(/[[:space:]]*#.*$/,     "", entry_path)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", entry_path)
      entry_gh = ""
    }
    /^[[:space:]]+gh_account:/ {
      gh = $0
      sub(/^[^:]*:[[:space:]]*/, "", gh)
      sub(/[[:space:]]*#.*$/,     "", gh)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", gh)
      entry_gh = gh
    }
    END { if (entry_path != "") print entry_path "\t" entry_gh }
  ' "$CONFIG"
}

STALE=0
CHECKED=0

while IFS="	" read -r ENTRY_PATH ENTRY_GH; do
  [ -z "$ENTRY_PATH" ] && continue

  ABS_PATH=""
  if cd "$METHODOLOGY_DIR/$ENTRY_PATH" 2>/dev/null; then
    ABS_PATH="$(pwd)"
    cd - >/dev/null 2>&1
  else
    continue   # repo not present on this machine — skip silently
  fi

  REMOTE_URL="$(git -C "$ABS_PATH" remote get-url origin 2>/dev/null || true)"
  OWNER="$(gh_owner_from_url "$REMOTE_URL")"
  [ -n "$OWNER" ] || continue   # not github.com → gh not applicable

  CHECKED=$((CHECKED + 1))
  REPO_NAME="$(basename "$ABS_PATH")"

  # No pre-seed → fine. The resolver uses URL-owner; field is optional now.
  if [ -z "$ENTRY_GH" ]; then
    echo "  ℹ️  $REPO_NAME: no gh_account pre-seed → URL-owner ($OWNER) will be used (OK)."
    continue
  fi

  CACHED="$(gh_cache_get "$REMOTE_URL")"

  # Pre-seed agrees with URL-owner or with the learned cache → trustworthy.
  if [ "$ENTRY_GH" = "$OWNER" ] || { [ -n "$CACHED" ] && [ "$ENTRY_GH" = "$CACHED" ]; }; then
    echo "  ✅ gh_account: $ENTRY_GH → $REPO_NAME"
    continue
  fi

  # Stale override: set, but disagrees with BOTH URL-owner AND cache. Harmless
  # (URL/cache win at push time) but signals config rot.
  printf "  🟡 STALE gh_account pre-seed: %s\n     path: %s\n     whitelist gh_account: %s\n     URL-owner: %s%s\n     Harmless (URL/cache win), но почисти поле или выровняй под URL-owner.\n" \
    "$REPO_NAME" "$ENTRY_PATH" "$ENTRY_GH" "$OWNER" \
    "$([ -n "$CACHED" ] && printf ' · learned-cache: %s' "$CACHED")" >&2
  STALE=$((STALE + 1))

done < <(_parse_whitelist)

echo ""
if [ "$CHECKED" -eq 0 ]; then
  echo "  ℹ️  validate-gh-accounts: нет github.com repos в whitelist — OK."
elif [ "$STALE" -gt 0 ]; then
  echo "🟡 validate-gh-accounts: $STALE stale gh_account pre-seed(s) of $CHECKED github.com repo(s) — warn-only, деплой не блокируется." >&2
else
  echo "✅ validate-gh-accounts: все $CHECKED github.com repo(s) — gh_account отсутствует или согласован (OK)."
fi
exit 0
