#!/usr/bin/env bash
#
# test-check-gh-account.sh — regression guard for gh-account resolution (lib/gh-account.sh)
# and the whitelist parser.
#
# Covers (council [opinion:git-account-ssot]):
#   (a) cache-path and URL-path resolve to the SAME owner when consistent;
#   (b) INCIDENT REGRESSION (2026-06-30): URL-owner (IDK-IDK) wins; a stale hand-typed
#       whitelist gh_account (cait-solutions) does NOT override it — gh_resolve_account
#       never consults the whitelist;
#   (c) ask-once → persist → never ask again: once a successful push persists (URL→account),
#       gh_resolve_account returns the learned account (cache wins over URL-owner);
#   + whitelist parser middle-entry regression (closes the awk dead-code that only ever
#     resolved the LAST entry).
#
# Hermetic: temp git repos with fake remotes + a temp GH_ACCOUNT_CACHE. No gh CLI, no auth.
# Scripts-only (methodology push tooling, not delivered to consumers) — no dual-copy.
#
# Bash 3.2+ compatible.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CGA="$SCRIPT_DIR/check-gh-account.sh"
LIB="$SCRIPT_DIR/lib/gh-account.sh"
fails=0

# shellcheck source=scripts/lib/gh-account.sh
. "$LIB"

_assert() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ok: $desc (= '$actual')"
  else
    echo "  FAIL: $desc — expected '$expected', got '$actual'"
    fails=$((fails + 1))
  fi
}

# Hermetic temp git repo with a github.com remote.
_mkrepo() {
  local dir url
  dir="$(mktemp -d 2>/dev/null || echo "${TMPDIR:-/tmp}/_cga_repo_$$_$RANDOM")"
  mkdir -p "$dir"
  url="$1"
  ( cd "$dir" && git init -q && git remote add origin "$url" ) >/dev/null 2>&1
  printf '%s\n' "$dir"
}

echo "test-check-gh-account: gh-account resolution + whitelist parser"

# ---- isolate the cache to a temp file (never touch the real one) ----
export GH_ACCOUNT_CACHE="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/_cga_cache_$$")"
: > "$GH_ACCOUNT_CACHE"

URL="https://github.com/IDK-IDK/foo.git"
REPO="$(_mkrepo "$URL")"

# (b) INCIDENT REGRESSION — URL-owner wins, no cache yet.
_assert "URL-owner derivation"            "IDK-IDK" "$(gh_owner_from_url "$URL")"
_assert "(b) resolve = URL-owner (no cache)" "IDK-IDK" "$(gh_resolve_account "$REPO")"
# Stale whitelist value must NOT change resolution (resolver ignores whitelist):
STALE_WL="cait-solutions"
_assert "(b) stale whitelist != resolved" "true" "$([ "$STALE_WL" != "$(gh_resolve_account "$REPO")" ] && echo true || echo false)"

# (a) cache-path and URL-path agree when consistent.
gh_cache_put "$URL" "IDK-IDK"
_assert "(a) resolve = cache-hit (consistent w/ URL)" "IDK-IDK" "$(gh_resolve_account "$REPO")"

# (c) ask-once → persist → never ask again: human answered a DIFFERENT account
#     (e.g. a bot with write access) → cache wins over URL-owner on next resolve.
gh_cache_put "$URL" "deploy-bot"
_assert "(c) resolve = learned account (cache > URL)" "deploy-bot" "$(gh_resolve_account "$REPO")"
# invalidate → falls back to URL-owner (self-heal on owner change / failure):
gh_cache_del "$URL"
_assert "(c) after invalidate → URL-owner again" "IDK-IDK" "$(gh_resolve_account "$REPO")"

# non-github remote → empty (gh not applicable).
GLREPO="$(_mkrepo "https://gitlab.com/group/proj.git")"
_assert "non-github → empty (no gh action)" "" "$(gh_resolve_account "$GLREPO")"

# ---- whitelist parser middle-entry regression (via --lookup-whitelist hook) ----
FIX="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/_test_cga_$$.md")"
cat > "$FIX" <<'EOF'
# fixture CLAUDE.local.md
```yaml
auto_commit_consumers:
  - path: ../first-documentation
    gh_account: first-acct
  - path: ../middle-documentation
    gh_account: middle-acct
  - path: ../no-account-documentation
    branch: ai-dev
  - path: ../last-documentation
    gh_account: last-acct
```
EOF
_assert "whitelist first"  "first-acct"  "$(bash "$CGA" --lookup-whitelist '../first-documentation'  "$FIX")"
_assert "whitelist MIDDLE (dead-code guard)" "middle-acct" "$(bash "$CGA" --lookup-whitelist '../middle-documentation' "$FIX")"
_assert "whitelist last"   "last-acct"   "$(bash "$CGA" --lookup-whitelist '../last-documentation'   "$FIX")"
_assert "whitelist no-account → empty" "" "$(bash "$CGA" --lookup-whitelist '../no-account-documentation' "$FIX")"
_assert "whitelist absent → empty"     "" "$(bash "$CGA" --lookup-whitelist '../does-not-exist' "$FIX")"

# ---- cleanup ----
rm -rf "$REPO" "$GLREPO" 2>/dev/null || true
rm -f "$FIX" "$GH_ACCOUNT_CACHE" 2>/dev/null || true

echo ""
if [ "$fails" -eq 0 ]; then
  echo "PASS: test-check-gh-account (all assertions)"
  exit 0
else
  echo "FAIL: test-check-gh-account ($fails failed)"
  exit 1
fi
