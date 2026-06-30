#!/usr/bin/env bash
#
# check-gh-account.sh — pre-push helper: switches the gh account before push to a repo.
#
# WHY (council [opinion:git-account-ssot], 2026-06-30 — reverses P-012):
#   The account to push under is resolved by lib/gh-account.sh (single source of truth):
#     learned cache for this remote-URL → else URL-owner.
#   URL is primary (incident 2026-06-30: URL was correct, the hand-typed whitelist
#   gh_account was stale → push under stale account → 404). The whitelist gh_account
#   is now only an OPTIONAL pre-seed — validate-gh-accounts.sh warns if it's stale.
#
# This script SWITCHES; it does not persist. Persist (remote-URL → account) happens in
# the caller AFTER a confirmed successful push (push-consumer-single.sh / deploy-push.sh)
# — only a real push proves the account is correct, so only then is it cached.
#
# Usage: bash scripts/check-gh-account.sh <consumer-abs-path> [claude-local-path]
#   consumer-abs-path — absolute path to the consumer repo
#   claude-local-path — path to CLAUDE.local.md (kept for backward-compat / hooks; the
#                       resolver is URL+cache based and does not require it)
#
# Exit 0 = ready to push (account verified / switched, or non-github → no gh action).
# Exit 1 = push impossible (required account not logged in, switch failed).
#
# Bash 3.2+ compatible.

set -uo pipefail

CONSUMER_PATH="${1:-}"
if [ -z "$CONSUMER_PATH" ]; then
  echo "Usage: $0 <consumer-abs-path> [claude-local-path]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${2:-$SCRIPT_DIR/../CLAUDE.local.md}"

# --- Source the gh-account lib (single source of truth for derivation) ------
# Defensive: inline fallback if the lib is absent (older clone mid-migration) —
# fallback = URL-owner only (no cache), the historically-reliable signal.
if [ -f "$SCRIPT_DIR/lib/gh-account.sh" ]; then
  # shellcheck source=scripts/lib/gh-account.sh
  . "$SCRIPT_DIR/lib/gh-account.sh"
else
  gh_owner_from_url() {
    case "${1:-}" in
      https://github.com/*) local o="${1#https://github.com/}"; o="${o%%/*}"; printf '%s\n' "${o%.git}" ;;
      *) printf '%s\n' "" ;;
    esac
  }
  gh_resolve_account() { gh_owner_from_url "$(git -C "${1:-.}" remote get-url origin 2>/dev/null || true)"; }
  gh_switch_to() {
    local want="${1:-}"; [ -n "$want" ] || return 0
    command -v gh >/dev/null 2>&1 || { echo "  🟡 gh CLI not found — switch skipped." >&2; return 0; }
    local active; active="$(gh api user -q .login 2>/dev/null || echo "")"
    [ "$active" = "$want" ] && { echo "  ✅ gh account: $want (уже активен)"; return 0; }
    if gh auth status 2>/dev/null | grep -q "account ${want} "; then
      gh auth switch --user "$want" >/dev/null 2>&1 && { echo "  🔄 gh account: ${active:-none} → $want"; return 0; }
      echo "  ❌ gh auth switch --user $want не удался." >&2; return 1
    fi
    echo "  ❌ gh: аккаунт '$want' не залогинен (активен: ${active:-none}). Залогинься: gh auth login --user $want" >&2
    return 1
  }
  _gh_account_for_entry() { printf '%s\n' ""; }   # whitelist hook unavailable without lib
fi

# Internal test hook (hermetic — no gh side-effects): resolve the whitelist gh_account
# for an EXACT auto_commit_consumers '- path:' value. Used by test-check-gh-account.sh.
#   check-gh-account.sh --lookup-whitelist <exact-entry-path> <config-file>
if [ "$CONSUMER_PATH" = "--lookup-whitelist" ]; then
  _gh_account_for_entry "${2:-}" "${3:-}"
  exit 0
fi

# --- Resolve the account (cache → URL-owner) --------------------------------
GH_ACCOUNT="$(gh_resolve_account "$CONSUMER_PATH")"

if [ -z "$GH_ACCOUNT" ]; then
  # Non-github remote (gitlab / self-hosted / ssh) → gh CLI not applicable.
  exit 0
fi

# --- Switch (block on failure — caller treats exit 1 as "do not push") ------
if gh_switch_to "$GH_ACCOUNT"; then
  exit 0
else
  exit 1
fi
