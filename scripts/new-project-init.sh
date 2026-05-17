#!/usr/bin/env bash
#
# new-project-init.sh — bootstrap a project with the methodology platform.
#
# Usage:
#   /path/to/methodology-platform/scripts/new-project-init.sh <project-name> [target-dir]
#
# Arguments:
#   <project-name>    Name of the project (used for {{Project Name}} substitution)
#   [target-dir]      Target directory (default: ./<project-name>)
#
# The SKILL template (templates/SKILL.template.md) is for per-domain use during
# /onboard, not auto-copied. Copy it manually into the relevant service folder.
#
# Always created (v3.4.0+):
#   .claude/{commands,agents,rules,state,hooks}/, .claude/.version
#   .claude/rules/README.md (template for tech stack rules)
#   README.md (workspace setup + links to SYSTEM-MAP/USER-MAP)
#   CLAUDE.md, CLAUDE_LONG.md, PRODUCT.md, VISION.md
#   docs/architecture/SYSTEM-MAP.md, docs/product/{USER-MAP,ARTIFACT-MAP}.md
#   docs/vision/{AGENT_VISION,LONG_VISION_v1}.md
#   docs/adr/{_TEMPLATE,README}.md, docs/data-map.md
#   docs/sync-vision-reports/ (placeholder for /sync-vision output)
#   inbox/{README,_processed/,_processed/rejected/}, services-registry.yaml
#   DEVLOG.md, IDEAS.md, ROADMAP.md, OPEN-QUESTIONS.md, HYPOTHESES.md, RISKS.md
#   .gitignore (standard ignores)
#   triggers.json (local state)
#
# One methodology, one bootstrap. For solo-dev: ignore docs that don't apply (docs/adr/, services-registry.yaml, etc.).
# For multi-service: fill in the multi-tier vision and services registry.
#
# Idempotent: existing files preserved (only .claude/commands/ overwritten by sync).

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing (no flags — simple positional arguments).
# ---------------------------------------------------------------------------
PROJECT_NAME="${1:?Usage: $0 <project-name> [target-dir]}"
TARGET_DIR="${2:-./$PROJECT_NAME}"

METHODOLOGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(cat "$METHODOLOGY_DIR/VERSION" | tr -d '[:space:]')"
SYNCED_AT="$(date -u +%Y-%m-%d)"

echo "Methodology: $VERSION"
echo "Project:     $PROJECT_NAME"
echo "Target:      $TARGET_DIR"
echo "Structure:   Full (one methodology, all artifacts created)"
echo ""

mkdir -p "$TARGET_DIR"/{.claude/{commands,agents,rules,state,hooks},docs/{architecture,product,vision,sync-vision-reports}}

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
# Hooks — universal protection. Strips .template from filename so wiring in
# settings.json resolves (e.g. docs_reminder.template.py → docs_reminder.py).
# ---------------------------------------------------------------------------
if [[ -d "$METHODOLOGY_DIR/hooks" ]] && compgen -G "$METHODOLOGY_DIR/hooks/*" >/dev/null; then
  echo "→ hooks/"
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
# triggers.json (idempotent: only created if missing — preserves counters).
# ---------------------------------------------------------------------------
echo "→ state/"
if [[ -f "$TARGET_DIR/.claude/state/triggers.json" ]]; then
  echo "  - triggers.json (exists — preserved)"
else
  cp "$METHODOLOGY_DIR/templates/triggers.json.template" "$TARGET_DIR/.claude/state/triggers.json"
  echo "  ✓ triggers.json (initialized)"
fi

cat > "$TARGET_DIR/.claude/.version" <<EOF
methodology: $VERSION
synced_at: $SYNCED_AT
source: https://github.com/cait-solutions/it-dev-methodology
EOF
echo "  ✓ .version"

# Model tiers registry — canonical methodology reference, copied with banner.
if [[ -f "$METHODOLOGY_DIR/templates/model-tiers.md" ]]; then
  inject_md_banner "$METHODOLOGY_DIR/templates/model-tiers.md" "$TARGET_DIR/.claude/model-tiers.md"
  echo "  ✓ model-tiers.md"
fi

# Settings — project-owned after bootstrap. Only created if absent.
if [[ -f "$TARGET_DIR/.claude/settings.json" ]]; then
  echo "  - settings.json (exists — preserved)"
else
  if [[ -f "$METHODOLOGY_DIR/templates/settings.template.json" ]]; then
    cp "$METHODOLOGY_DIR/templates/settings.template.json" "$TARGET_DIR/.claude/settings.json"
    echo "  ✓ settings.json (initialized with hooks wiring)"
  fi
fi

# ---------------------------------------------------------------------------
# Template copy with {{Project Name}} substitution. Preserves existing files.
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

# ---------------------------------------------------------------------------
# Core artifacts (always).
# ---------------------------------------------------------------------------
echo "→ core artifacts/"
copy_with_subst "$METHODOLOGY_DIR/templates/README.template.md"          "$TARGET_DIR/README.md"
copy_with_subst "$METHODOLOGY_DIR/templates/CLAUDE.template.md"          "$TARGET_DIR/CLAUDE.md"
copy_with_subst "$METHODOLOGY_DIR/templates/CLAUDE_LONG.template.md"     "$TARGET_DIR/CLAUDE_LONG.md"
copy_with_subst "$METHODOLOGY_DIR/templates/PRODUCT.template.md"         "$TARGET_DIR/PRODUCT.md"
copy_with_subst "$METHODOLOGY_DIR/templates/SYSTEM-MAP.template.md"      "$TARGET_DIR/docs/architecture/SYSTEM-MAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/USER-MAP.template.md"        "$TARGET_DIR/docs/product/USER-MAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/ARTIFACT-MAP.template.md"    "$TARGET_DIR/docs/product/ARTIFACT-MAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/DEVLOG.template.md"          "$TARGET_DIR/DEVLOG.md"
copy_with_subst "$METHODOLOGY_DIR/templates/IDEAS.template.md"           "$TARGET_DIR/IDEAS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/ROADMAP.template.md"         "$TARGET_DIR/ROADMAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/OPEN-QUESTIONS.template.md"  "$TARGET_DIR/OPEN-QUESTIONS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/HYPOTHESES.template.md"      "$TARGET_DIR/HYPOTHESES.md"
copy_with_subst "$METHODOLOGY_DIR/templates/RISKS.template.md"           "$TARGET_DIR/RISKS.md"

# ---------------------------------------------------------------------------
# Vision — both single-tier and multi-tier structures created.
# Solo-dev projects use VISION.md; multi-service projects use docs/vision/
# ---------------------------------------------------------------------------
echo "→ vision/"

# Single-tier VISION.md (for solo-dev projects)
copy_with_subst "$METHODOLOGY_DIR/templates/VISION.template.md"  "$TARGET_DIR/VISION.md"

# Multi-tier vision (for multi-service projects)
copy_with_subst "$METHODOLOGY_DIR/templates/vision/AGENT_VISION.template.md"  "$TARGET_DIR/docs/vision/AGENT_VISION.md"
copy_with_subst "$METHODOLOGY_DIR/templates/vision/LONG_VISION.template.md"   "$TARGET_DIR/docs/vision/LONG_VISION_v1.md"

# Services registry (for multi-service projects)
echo "→ services-registry/"
copy_with_subst "$METHODOLOGY_DIR/templates/services-registry.template.yaml"  "$TARGET_DIR/services-registry.yaml"

# ---------------------------------------------------------------------------
# Standard artifacts — all created (v3.1.0+).
# For solo-dev projects: simply don't fill these in (or delete if not needed).
# For multi-service: fill these in as needed.
# ---------------------------------------------------------------------------
echo "→ adr/"
copy_with_subst "$METHODOLOGY_DIR/templates/adr/_TEMPLATE.md"          "$TARGET_DIR/docs/adr/_TEMPLATE.md"
copy_with_subst "$METHODOLOGY_DIR/templates/adr/README.template.md"    "$TARGET_DIR/docs/adr/README.md"

echo "→ inbox/"
mkdir -p "$TARGET_DIR/inbox/_processed/rejected"
touch "$TARGET_DIR/inbox/_processed/.gitkeep"
touch "$TARGET_DIR/inbox/_processed/rejected/.gitkeep"
copy_with_subst "$METHODOLOGY_DIR/templates/inbox/README.template.md"  "$TARGET_DIR/inbox/README.md"

echo "→ sync-vision-reports/"
touch "$TARGET_DIR/docs/sync-vision-reports/.gitkeep"
echo "  ✓ docs/sync-vision-reports/ (placeholder)"

echo "→ data-map/"
copy_with_subst "$METHODOLOGY_DIR/templates/data-map.template.md"  "$TARGET_DIR/docs/data-map.md"

echo "→ glossary/"
copy_with_subst "$METHODOLOGY_DIR/templates/glossary.template.md"  "$TARGET_DIR/docs/glossary.md"

echo "→ behavior/"
copy_with_subst "$METHODOLOGY_DIR/templates/BEHAVIOR.template.md"  "$TARGET_DIR/docs/BEHAVIOR.md"

echo "→ threat-model/"
copy_with_subst "$METHODOLOGY_DIR/templates/threat-model.template.md"  "$TARGET_DIR/docs/threat-model.template.md"

echo "→ rules/"
copy_with_subst "$METHODOLOGY_DIR/templates/.claude/rules/README.template.md"  "$TARGET_DIR/.claude/rules/README.md"

echo "→ gitignore/"
copy_with_subst "$METHODOLOGY_DIR/templates/.gitignore.template"  "$TARGET_DIR/.gitignore"

# ---------------------------------------------------------------------------
# Git init.
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
echo "  2. Fill in PRODUCT.md  — product behavior from user POV"
echo ""
echo "  For single-developer projects:"
echo "    - Fill in VISION.md (single-tier strategic axes)"
echo "    - Delete dirs you don't need (docs/adr/, services-registry.yaml, etc.)"
echo ""
echo "  For multi-service platforms:"
echo "    - Fill in docs/vision/AGENT_VISION.md and LONG_VISION_v1.md"
echo "    - Add services to services-registry.yaml"
echo "    - Set up per-service CLAUDE.md files"
echo ""
echo "  Then: Open $TARGET_DIR/ in Claude Code, run /plan for the first feature"
echo ""
echo "  IMPORTANT: .claude/commands/ is gitignored (synced, not project-owned)."
echo "  After each git clone of this project, teammates must run:"
echo "    bash $METHODOLOGY_DIR/scripts/sync-methodology.sh <project-dir>"
echo "  Add this to your project README."
echo ""
echo "Sync methodology updates later via:"
echo "  $METHODOLOGY_DIR/scripts/sync-methodology.sh $TARGET_DIR"
