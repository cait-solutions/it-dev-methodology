#!/usr/bin/env bash
#
# lib/gh-account.sh — single source of truth for resolving WHICH gh account pushes
# to a given repo. Source-able (no execution on its own).
#
#   usage:  . scripts/lib/gh-account.sh
#
# Resolution model (council [opinion:git-account-ssot], self-learning, 2026-06-30):
#   1. learned cache for this remote-URL → hit → return it (don't ask, don't re-derive)
#   2. else URL-owner (segment after github.com/) — URL is the reliable signal
#   3. caller attempts push under the result
#   4. success → gh_cache_put (remote-URL → account): machine-written, never drifts
#   5. push-failure (404/403 wrong account) → caller asks human once → push under the
#      answer → on success gh_cache_put + (cache self-heals) → afterwards automatic
#
# WHY URL-primary (P-012 reversed by evidence): incident 2026-06-30 — URL=IDK-IDK
# (correct), hand-typed whitelist gh_account=cait-solutions (stale) → push under the
# stale account → 404. The URL was reliable; the manually-maintained field drifted.
# Therefore URL > manual field. The machine cache is written ONLY on a real successful
# push, so it cannot drift like a hand-typed value. The whitelist gh_account survives
# only as an OPTIONAL pre-seed/hint — validated (warn on stale), never authoritative.
#
# Cache file (gitignored, per-clone): <repo-root>/.claude/state/gh-account-cache
#   line format:  <remote-URL>\t<account>   (one per line)
# Override via env GH_ACCOUNT_CACHE (tests / non-default clone layout).
#
# bash 3.2 compatible (Git Bash on Windows): no associative arrays, no ${var,,}.
# Returns via stdout only. All functions namespaced gh_* / _gh_*.

# --- URL → owner -----------------------------------------------------------
# gh_owner_from_url <remote-url> → owner segment after github.com/, or empty
# string for non-github (gh CLI does not manage gitlab / self-hosted).
gh_owner_from_url() {
  local url="${1:-}"
  case "$url" in
    https://github.com/*)
      local o="${url#https://github.com/}"
      o="${o%%/*}"
      o="${o%.git}"
      printf '%s\n' "$o"
      ;;
    *) printf '%s\n' "" ;;
  esac
}

# gh_remote_url <repo-path> → origin remote URL (empty if none / not a repo)
gh_remote_url() {
  git -C "${1:-.}" remote get-url origin 2>/dev/null || true
}

# gh_active_account → currently active gh login (empty if no gh / not logged in)
gh_active_account() {
  command -v gh >/dev/null 2>&1 || { printf '%s\n' ""; return 0; }
  gh api user -q .login 2>/dev/null || printf '%s\n' ""
}

# --- learned cache ---------------------------------------------------------
# gh_cache_file → resolve the cache path (env override → repo-root default).
gh_cache_file() {
  if [ -n "${GH_ACCOUNT_CACHE:-}" ]; then printf '%s\n' "$GH_ACCOUNT_CACHE"; return 0; fi
  local self_dir repo_root
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "$self_dir/../.." && pwd)"
  printf '%s\n' "$repo_root/.claude/state/gh-account-cache"
}

# gh_cache_get <remote-url> [cache-file] → cached account for URL, or empty.
gh_cache_get() {
  local url="${1:-}" cache="${2:-}"
  [ -n "$url" ] || { printf '%s\n' ""; return 0; }
  [ -n "$cache" ] || cache="$(gh_cache_file)"
  [ -f "$cache" ] || { printf '%s\n' ""; return 0; }
  awk -F '\t' -v u="$url" '$1==u {print $2; exit}' "$cache"
}

# gh_cache_put <remote-url> <account> [cache-file]
#   Machine-written — caller invokes ONLY after a confirmed successful push.
#   Idempotent: replaces any prior entry for the same URL (self-heals stale value).
gh_cache_put() {
  local url="${1:-}" acct="${2:-}" cache="${3:-}"
  [ -n "$url" ] && [ -n "$acct" ] || return 0
  [ -n "$cache" ] || cache="$(gh_cache_file)"
  local dir tmp
  dir="$(dirname "$cache")"
  mkdir -p "$dir" 2>/dev/null || true
  tmp="$(mktemp 2>/dev/null || echo "${cache}.tmp.$$")"
  if [ -f "$cache" ]; then
    awk -F '\t' -v u="$url" '$1!=u' "$cache" > "$tmp" 2>/dev/null || true
  fi
  printf '%s\t%s\n' "$url" "$acct" >> "$tmp"
  mv -f "$tmp" "$cache" 2>/dev/null || { cat "$tmp" > "$cache" 2>/dev/null || true; rm -f "$tmp" 2>/dev/null || true; }
}

# gh_cache_del <remote-url> [cache-file]
#   Invalidate one entry (self-heal on push-failure / repo owner change → re-learn).
gh_cache_del() {
  local url="${1:-}" cache="${2:-}"
  [ -n "$url" ] || return 0
  [ -n "$cache" ] || cache="$(gh_cache_file)"
  [ -f "$cache" ] || return 0
  local tmp; tmp="$(mktemp 2>/dev/null || echo "${cache}.tmp.$$")"
  awk -F '\t' -v u="$url" '$1!=u' "$cache" > "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$cache" 2>/dev/null || { cat "$tmp" > "$cache" 2>/dev/null || true; rm -f "$tmp" 2>/dev/null || true; }
}

# --- whitelist (OPTIONAL pre-seed/hint only — never authoritative) ----------
# Parse the ```yaml auto_commit_consumers: block of a CLAUDE.local.md-style file.

# _gh_list_whitelist_paths <config> → each '- path:' value, raw, one per line.
_gh_list_whitelist_paths() {
  local config="${1:-}"
  [ -f "$config" ] || return 0
  awk '
    /^```yaml/ && !in_block { in_block=1; next }
    /^```/ && in_block       { in_block=0; in_consumers=0; next }
    !in_block                { next }
    /auto_commit_consumers:/ { in_consumers=1; next }
    !in_consumers            { next }
    /^  - path:/ {
      ep=$0; sub(/^[^:]*:[[:space:]]*/,"",ep); sub(/[[:space:]]*#.*$/,"",ep)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",ep)
      print ep
    }
  ' "$config"
}

# _gh_account_for_entry <exact-path-value> <config> → gh_account for that entry (or empty).
# Emits IMMEDIATELY on the gh_account line while in the target entry (closes the
# dead-code deferred-print bug that only ever resolved the LAST whitelist entry).
_gh_account_for_entry() {
  local target_path="${1:-}" config="${2:-}"
  [ -f "$config" ] || { printf '%s\n' ""; return 0; }
  awk -v target="$target_path" '
    /^```yaml/ && !in_block { in_block=1; next }
    /^```/ && in_block       { in_block=0; in_consumers=0; next }
    !in_block                { next }
    /auto_commit_consumers:/ { in_consumers=1; next }
    !in_consumers            { next }
    /^  - path:/ {
      entry_path = $0
      sub(/^[^:]*:[[:space:]]*/, "", entry_path)
      sub(/[[:space:]]*#.*$/,     "", entry_path)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", entry_path)
      in_target = (entry_path == target)
      next
    }
    /^[[:space:]]+gh_account:/ && in_target {
      gh = $0
      sub(/^[^:]*:[[:space:]]*/, "", gh)
      sub(/[[:space:]]*#.*$/,     "", gh)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", gh)
      print gh
      exit
    }
  ' "$config"
}

# gh_whitelist_account <consumer-abs-path> <config> → pre-seed gh_account (or empty).
# OPTIONAL hint only. Matches consumer to an auto_commit_consumers entry by resolving
# BOTH sides to absolute paths (so nested consumers match, not just siblings).
gh_whitelist_account() {
  local consumer_path="${1:-}" config="${2:-}"
  [ -n "$consumer_path" ] && [ -f "$config" ] && [ -d "$consumer_path" ] || { printf '%s\n' ""; return 0; }
  local abs_consumer config_dir
  abs_consumer="$(cd "$consumer_path" && pwd)" || { printf '%s\n' ""; return 0; }
  config_dir="$(cd "$(dirname "$config")" && pwd)" || { printf '%s\n' ""; return 0; }
  local matched="" _entry _abs_entry
  # Process-substitution (NOT a pipe) so $matched survives the loop in bash 3.2.
  while IFS= read -r _entry; do
    [ -n "$_entry" ] || continue
    _abs_entry="$( cd "$config_dir" 2>/dev/null && cd "$_entry" 2>/dev/null && pwd )"
    if [ -n "$_abs_entry" ] && [ "$_abs_entry" = "$abs_consumer" ]; then
      matched="$_entry"; break
    fi
  done < <(_gh_list_whitelist_paths "$config")
  [ -n "$matched" ] || { printf '%s\n' ""; return 0; }
  _gh_account_for_entry "$matched" "$config"
}

# --- resolution (authoritative: cache → URL-owner) -------------------------
# gh_resolve_account <repo-path> → account to push under. Empty = non-github
# (caller skips gh entirely). Order: learned cache for this URL → URL-owner.
# Whitelist is intentionally NOT consulted here — it only pre-seeds/validates.
gh_resolve_account() {
  local cpath="${1:-.}" url owner cached
  url="$(gh_remote_url "$cpath")"
  owner="$(gh_owner_from_url "$url")"
  [ -n "$owner" ] || { printf '%s\n' ""; return 0; }
  cached="$(gh_cache_get "$url")"
  if [ -n "$cached" ]; then printf '%s\n' "$cached"; return 0; fi
  printf '%s\n' "$owner"
}

# --- switch orchestration --------------------------------------------------
# gh_switch_to <account> → ensure <account> is active. Echoes a status line.
# Exit 0 = active (or switched); 1 = not logged in / switch failed (caller decides
# whether that blocks the push or is only a warning).
gh_switch_to() {
  local want="${1:-}"
  [ -n "$want" ] || return 0
  if ! command -v gh >/dev/null 2>&1; then
    echo "  🟡 gh CLI not found — switch skipped." >&2
    return 0
  fi
  local active; active="$(gh_active_account)"
  if [ "$active" = "$want" ]; then
    echo "  ✅ gh account: $want (уже активен)"
    return 0
  fi
  if gh auth status 2>/dev/null | grep -q "account ${want} "; then
    if gh auth switch --user "$want" >/dev/null 2>&1; then
      echo "  🔄 gh account: ${active:-none} → $want"
      return 0
    fi
    echo "  ❌ gh auth switch --user $want не удался." >&2
    return 1
  fi
  echo "  ❌ gh: аккаунт '$want' не залогинен (активен: ${active:-none})." >&2
  echo "     Залогинься: gh auth login --user $want" >&2
  return 1
}
