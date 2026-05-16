#!/usr/bin/env bash
#
# sync-methodology.sh — update an existing project's .claude/commands/ (and hooks/agents)
# from this methodology-platform checkout. Run from anywhere; the script locates the
# methodology root via its own path.
#
# Usage:
#   /path/to/methodology-platform/scripts/sync-methodology.sh <target-project-dir>
#
# What it does:
#   1. Detects local modifications (commands without AUTO-GENERATED banner) and prompts.
#   2. Overwrites .claude/commands/*.md with banner-prefixed copies from methodology.
#   3. Copies new agent skeletons (existing per-project content is preserved).
#   4. Copies hooks (overwrites — they are universal infrastructure).
#   5. Updates .claude/.version.

set -euo pipefail

TARGET_DIR="${1:?Usage: $0 <target-project-dir>}"
METHODOLOGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(cat "$METHODOLOGY_DIR/VERSION" | tr -d '[:space:]')"
SYNCED_AT="$(date -u +%Y-%m-%d)"

if [[ ! -d "$TARGET_DIR/.claude/commands" ]]; then
  echo "ERROR: $TARGET_DIR/.claude/commands not found."
  echo "       Run new-project-init.sh first, or check the path."
  exit 1
fi

echo "Methodology: $VERSION"
echo "Target:      $TARGET_DIR"
echo ""

# ---------------------------------------------------------------------------
# Detect local modifications (commands missing the banner).
# These would be silently overwritten — warn user.
# ---------------------------------------------------------------------------
LOCAL_MODS=()
for f in "$TARGET_DIR"/.claude/commands/*.md; do
  [[ -f "$f" ]] || continue
  if ! head -1 "$f" 2>/dev/null | grep -q "AUTO-GENERATED from methodology-platform"; then
    LOCAL_MODS+=("$(basename "$f")")
  fi
done

if [[ ${#LOCAL_MODS[@]} -gt 0 ]]; then
  echo "⚠️  These commands lack the AUTO-GENERATED banner (manually edited or new):"
  for m in "${LOCAL_MODS[@]}"; do
    echo "    - $m"
  done
  echo ""
  echo "    Sync will OVERWRITE them. If you edited locally, open a PR upstream first:"
  echo "    https://github.com/cait-solutions/it-dev-methodology"
  echo ""
  printf "Continue and overwrite? [y/N] "
  read -r ans
  ans_lower="$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')"
  if [[ "$ans_lower" != "y" ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Banner injection — picks comment syntax by file extension.
# ---------------------------------------------------------------------------
inject_md_banner() {
  local src="$1"
  local dest="$2"
  {
    cat <<EOF
<!-- AUTO-GENERATED from methodology-platform $VERSION -->
<!-- Synced: $SYNCED_AT -->
<!-- DO NOT EDIT — changes will be overwritten on next sync -->
<!-- Modify via PR to https://github.com/cait-solutions/it-dev-methodology -->
<!-- Emergency override: edit locally + open PR within 48h -->

EOF
    cat "$src"
  } > "$dest"
}

inject_py_banner() {
  local src="$1"
  local dest="$2"
  {
    cat <<EOF
# AUTO-GENERATED from methodology-platform $VERSION
# Synced: $SYNCED_AT
# DO NOT EDIT — changes will be overwritten on next sync
# Modify via PR to https://github.com/cait-solutions/it-dev-methodology
# Emergency override: edit locally + open PR within 48h

EOF
    cat "$src"
  } > "$dest"
}

# ---------------------------------------------------------------------------
# Commands — always overwrite (canonical source is methodology).
# ---------------------------------------------------------------------------
echo "→ commands/"
for cmd in "$METHODOLOGY_DIR"/commands/*.md; do
  [[ -f "$cmd" ]] || continue
  name="$(basename "$cmd")"
  inject_md_banner "$cmd" "$TARGET_DIR/.claude/commands/$name"
  echo "  ✓ $name"
done

# Delete commands that no longer exist in methodology (renamed/removed upstream).
for existing in "$TARGET_DIR"/.claude/commands/*.md; do
  [[ -f "$existing" ]] || continue
  name="$(basename "$existing")"
  if [[ ! -f "$METHODOLOGY_DIR/commands/$name" ]]; then
    echo "  ✗ $name (removed upstream — deleting)"
    rm "$existing"
  fi
done

# ---------------------------------------------------------------------------
# Agent skeletons — only copy if missing in target. Per-project bodies are preserved.
# ---------------------------------------------------------------------------
if compgen -G "$METHODOLOGY_DIR/agents/*.template.md" >/dev/null; then
  echo "→ agents/"
  mkdir -p "$TARGET_DIR/.claude/agents"
  for agent in "$METHODOLOGY_DIR"/agents/*.template.md; do
    name="$(basename "$agent" .template.md).md"
    dest="$TARGET_DIR/.claude/agents/$name"
    if [[ -f "$dest" ]]; then
      echo "  - $name (preserved — agent body is per-project)"
    else
      cp "$agent" "$dest"
      echo "  ✓ $name (new)"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Hooks — universal infrastructure, always overwrite. Strips .template from
# filename so wiring in settings.json resolves.
#
# NOTE: This will overwrite local fills of docs_reminder.py LIBS dict. If your
# project has filled LIBS, mirror that change in methodology/hooks/docs_reminder.template.py
# before syncing, or keep a project-local docs_reminder_libs.py and import from it.
# ---------------------------------------------------------------------------
if [[ -d "$METHODOLOGY_DIR/hooks" ]] && compgen -G "$METHODOLOGY_DIR/hooks/*" >/dev/null; then
  echo "→ hooks/"
  mkdir -p "$TARGET_DIR/.claude/hooks"
  for hook in "$METHODOLOGY_DIR"/hooks/*; do
    [[ -f "$hook" ]] || continue
    name="$(basename "$hook")"
    dest_name="${name/.template/}"
    dest="$TARGET_DIR/.claude/hooks/$dest_name"
    case "$name" in
      *.py) inject_py_banner "$hook" "$dest" ;;
      *.md) inject_md_banner "$hook" "$dest" ;;
      *)    cp "$hook" "$dest" ;;
    esac
    echo "  ✓ $dest_name"
  done
fi

# ---------------------------------------------------------------------------
# Model tiers registry — canonical reference, always overwrite.
# ---------------------------------------------------------------------------
if [[ -f "$METHODOLOGY_DIR/templates/model-tiers.md" ]]; then
  echo "→ model-tiers/"
  inject_md_banner "$METHODOLOGY_DIR/templates/model-tiers.md" "$TARGET_DIR/.claude/model-tiers.md"
  echo "  ✓ model-tiers.md"
fi

# ---------------------------------------------------------------------------
# .version pointer.
# ---------------------------------------------------------------------------
cat > "$TARGET_DIR/.claude/.version" <<EOF
methodology: $VERSION
synced_at: $SYNCED_AT
source: https://github.com/cait-solutions/it-dev-methodology
EOF

echo ""
echo "✅ Sync complete. Methodology version: $VERSION"
