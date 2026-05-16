#!/usr/bin/env bash
#
# new-project-init.sh — bootstrap a project with the methodology platform.
#
# Usage:
#   /path/to/methodology-platform/scripts/new-project-init.sh <project-name> [target-dir]
#
# Creates in <target-dir>:
#   .claude/commands/       — slash commands, synced from methodology (with AUTO-GENERATED banner)
#   .claude/agents/         — agent skeletons (only if methodology has agents/*.template.md)
#   .claude/rules/          — empty, ready for tech-stack-specific rules
#   .claude/hooks/          — universal protection hooks (only if methodology has hooks/)
#   .claude/state/          — triggers.json initialized
#   .claude/.version        — records which methodology version is synced
#   CLAUDE.md, PRODUCT.md, VISION.md, docs/architecture/SYSTEM-MAP.md  — from templates
#   DEVLOG.md, IDEAS.md, ROADMAP.md, OPEN-QUESTIONS.md, HYPOTHESES.md, RISKS.md  — from templates
#
# Idempotent: existing files in target are preserved (only .claude/commands/ is overwritten by sync).

set -euo pipefail

PROJECT_NAME="${1:?Usage: $0 <project-name> [target-dir]}"
TARGET_DIR="${2:-./$PROJECT_NAME}"

METHODOLOGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(cat "$METHODOLOGY_DIR/VERSION" | tr -d '[:space:]')"
SYNCED_AT="$(date -u +%Y-%m-%d)"

echo "Methodology: $VERSION"
echo "Project:     $PROJECT_NAME"
echo "Target:      $TARGET_DIR"
echo ""

mkdir -p "$TARGET_DIR"/{.claude/{commands,agents,rules,state,hooks},docs/{adr,architecture,vision}}

# ---------------------------------------------------------------------------
# Banner injection for markdown commands.
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

# ---------------------------------------------------------------------------
# Slash commands.
# ---------------------------------------------------------------------------
echo "→ commands/"
for cmd in "$METHODOLOGY_DIR"/commands/*.md; do
  [[ -f "$cmd" ]] || continue
  name="$(basename "$cmd")"
  inject_md_banner "$cmd" "$TARGET_DIR/.claude/commands/$name"
  echo "  ✓ $name"
done

# ---------------------------------------------------------------------------
# Agent skeletons (appear once Phase E lands).
# ---------------------------------------------------------------------------
if compgen -G "$METHODOLOGY_DIR/agents/*.template.md" >/dev/null; then
  echo "→ agents/"
  for agent in "$METHODOLOGY_DIR"/agents/*.template.md; do
    name="$(basename "$agent" .template.md).md"
    dest="$TARGET_DIR/.claude/agents/$name"
    if [[ -f "$dest" ]]; then
      echo "  - $name (preserved — agent body is per-project)"
    else
      cp "$agent" "$dest"
      echo "  ✓ $name (copied)"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Hooks (appear once Phase E lands).
# ---------------------------------------------------------------------------
if [[ -d "$METHODOLOGY_DIR/hooks" ]] && compgen -G "$METHODOLOGY_DIR/hooks/*" >/dev/null; then
  echo "→ hooks/"
  for hook in "$METHODOLOGY_DIR"/hooks/*; do
    [[ -f "$hook" ]] || continue
    name="$(basename "$hook")"
    cp "$hook" "$TARGET_DIR/.claude/hooks/$name"
    echo "  ✓ $name"
  done
fi

# ---------------------------------------------------------------------------
# triggers.json (idempotent: only created if missing — preserves counters).
# ---------------------------------------------------------------------------
echo "→ state/"
if [[ -f "$TARGET_DIR/.claude/state/triggers.json" ]]; then
  echo "  - triggers.json (exists — preserved)"
else
  cp "$METHODOLOGY_DIR/templates/triggers.json.template" "$TARGET_DIR/.claude/state/triggers.json"
  echo "  ✓ triggers.json (initialized)"
fi

# ---------------------------------------------------------------------------
# .version pointer.
# ---------------------------------------------------------------------------
cat > "$TARGET_DIR/.claude/.version" <<EOF
methodology: $VERSION
synced_at: $SYNCED_AT
source: https://github.com/cait-solutions/it-dev-methodology
EOF
echo "  ✓ .version"

# ---------------------------------------------------------------------------
# Root artifacts with {{Project Name}} substitution. Preserves existing files.
# ---------------------------------------------------------------------------
copy_with_subst() {
  local template="$1"
  local dest="$2"
  if [[ -f "$dest" ]]; then
    echo "  - $(basename "$dest") (exists — preserved)"
    return
  fi
  if [[ ! -f "$template" ]]; then
    echo "  ! $(basename "$template") (template missing — skipped)"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  sed "s/{{Project Name}}/$PROJECT_NAME/g" "$template" > "$dest"
  echo "  ✓ $(basename "$dest")"
}

echo "→ artifacts/"
copy_with_subst "$METHODOLOGY_DIR/templates/CLAUDE.template.md"          "$TARGET_DIR/CLAUDE.md"
copy_with_subst "$METHODOLOGY_DIR/templates/PRODUCT.template.md"         "$TARGET_DIR/PRODUCT.md"
copy_with_subst "$METHODOLOGY_DIR/templates/VISION.template.md"          "$TARGET_DIR/VISION.md"
copy_with_subst "$METHODOLOGY_DIR/templates/SYSTEM-MAP.template.md"      "$TARGET_DIR/docs/architecture/SYSTEM-MAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/DEVLOG.template.md"          "$TARGET_DIR/DEVLOG.md"
copy_with_subst "$METHODOLOGY_DIR/templates/IDEAS.template.md"           "$TARGET_DIR/IDEAS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/ROADMAP.template.md"         "$TARGET_DIR/ROADMAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/OPEN-QUESTIONS.template.md"  "$TARGET_DIR/OPEN-QUESTIONS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/HYPOTHESES.template.md"      "$TARGET_DIR/HYPOTHESES.md"
copy_with_subst "$METHODOLOGY_DIR/templates/RISKS.template.md"           "$TARGET_DIR/RISKS.md"

# ---------------------------------------------------------------------------
# Git init (only if no .git in target).
# ---------------------------------------------------------------------------
if [[ ! -d "$TARGET_DIR/.git" ]]; then
  ( cd "$TARGET_DIR" && git init -q )
  echo "  ✓ git initialized"
fi

echo ""
echo "✅ Project '$PROJECT_NAME' bootstrapped at $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. Fill in CLAUDE.md   — operational rules for AI agents"
echo "  2. Fill in PRODUCT.md  — product vision (commands, storages, behavior)"
echo "  3. Fill in VISION.md   — strategic axes"
echo "  4. Open in Claude Code, then run /plan to start the first feature"
echo ""
echo "Sync methodology updates later via:"
echo "  $METHODOLOGY_DIR/scripts/sync-methodology.sh $TARGET_DIR"
