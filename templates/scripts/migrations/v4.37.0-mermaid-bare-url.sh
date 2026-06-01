#!/usr/bin/env bash
# v4.37.0-mermaid-bare-url.sh — migrate mermaid links to bare-URL format.
#
# FORMAT CHANGE (v4.37.0): old markdown-link form
#   > 🔗 [Открыть в Mermaid Live](https://mermaid.live/...)
# → new bare URL on its own line (triple-click selects URL only, no title):
#   https://mermaid.live/...
#
# This is the exact case that bit erp consumer: artifact filled with old format,
# sync never transformed it. Idempotent: delegates to update-mermaid-links.sh
# (which already converts old→bare, cleans placeholders, handles TODO blocks).
#
# Sourced by _runner.sh. NO top-level execution. Bash 3.2 / Git-Bash safe.

MIGRATION_TARGET_VERSION="v4.37.0"
MIGRATION_ID="mermaid-bare-url"
MIGRATION_MODE="auto"

migration_describe() {
  echo "Mermaid: markdown-link '> 🔗 [Открыть](url)' → bare URL (триплклик выделяет только ссылку)."
}

# NEEDED if any .md still has the old markdown-link mermaid form.
# Pure read. Returns 0 = needed, 1 = clean.
migration_detect() {
  local root="$1"
  # old form: optional '>' blockquote, optional 🔗, [..Mermaid Live..](https://mermaid.live
  grep -rEl '^[[:space:]]*>?[[:space:]]*(🔗[[:space:]]*)?\[[^]]*Mermaid Live[^]]*\]\(https://mermaid\.live' \
    "$root/docs" "$root"/*.md 2>/dev/null | grep -q .
}

# Idempotent transform: run update-mermaid-links.sh (local + doc-repo if two-repo).
migration_apply() {
  local root="$1"
  [ -f "$root/scripts/update-mermaid-links.sh" ] || return 1
  bash "$root/scripts/update-mermaid-links.sh" --root "$root" >/dev/null 2>&1 || return 1
  # two-repo: also doc repo if doc_repo_path configured and present
  local doc
  doc="$(grep '^[[:space:]]*doc_repo_path:' "$root/CLAUDE.local.md" 2>/dev/null \
         | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r"'"'"' ' )"
  if [ -n "$doc" ] && [ "$doc" != "null" ] && [ -d "$root/$doc" ]; then
    bash "$root/scripts/update-mermaid-links.sh" --root "$root/$doc" >/dev/null 2>&1 || return 1
  fi
  return 0
}
