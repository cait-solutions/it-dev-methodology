#!/usr/bin/env bash
#
# new-project-init.sh — bootstrap a project with the methodology platform.
#
# Usage:
#   /path/to/methodology-platform/scripts/new-project-init.sh <project-name> [target-dir] [flags]
#
# Flags (all optional):
#   --multi-service       Use two-tier vision (docs/vision/AGENT_VISION + LONG_VISION)
#                         + services-registry.yaml. Replaces single VISION.md.
#   --with-adr            Initialize docs/adr/ with _TEMPLATE.md and README.md
#   --with-inbox          Initialize inbox/ with README + _processed/ + _processed/rejected/
#   --with-data-map       Create docs/data-map.md
#   --with-glossary       Create docs/glossary.md
#   --with-behavior       Create docs/BEHAVIOR.md
#   --with-threat-model   Create docs/threat-model.template.md (kept as template)
#   --all-optional        Enable everything above
#   -h, --help            Show this help
#
# The SKILL template (templates/SKILL.template.md) is for per-domain use during
# /onboard, not auto-copied. Copy it manually into the relevant service folder.
#
# Always created:
#   .claude/{commands,agents,rules,state,hooks}/, .claude/.version
#   triggers.json, CLAUDE.md, PRODUCT.md, docs/architecture/SYSTEM-MAP.md
#   DEVLOG.md, IDEAS.md, ROADMAP.md, OPEN-QUESTIONS.md, HYPOTHESES.md, RISKS.md
#   VISION.md (single-tier — unless --multi-service)
#
# Idempotent: existing files preserved (only .claude/commands/ overwritten by sync).

set -euo pipefail

# ---------------------------------------------------------------------------
# Flag parsing.
# ---------------------------------------------------------------------------
WITH_MULTI_SERVICE=false
WITH_ADR=false
WITH_INBOX=false
WITH_DATA_MAP=false
WITH_GLOSSARY=false
WITH_BEHAVIOR=false
WITH_THREAT_MODEL=false

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --multi-service)      WITH_MULTI_SERVICE=true; shift ;;
    --with-adr)           WITH_ADR=true; shift ;;
    --with-inbox)         WITH_INBOX=true; shift ;;
    --with-data-map)      WITH_DATA_MAP=true; shift ;;
    --with-glossary)      WITH_GLOSSARY=true; shift ;;
    --with-behavior)      WITH_BEHAVIOR=true; shift ;;
    --with-threat-model)  WITH_THREAT_MODEL=true; shift ;;
    --all-optional)
      WITH_MULTI_SERVICE=true
      WITH_ADR=true
      WITH_INBOX=true
      WITH_DATA_MAP=true
      WITH_GLOSSARY=true
      WITH_BEHAVIOR=true
      WITH_THREAT_MODEL=true
      shift ;;
    -h|--help)
      sed -n '/^#$/,/^$/p' "$0" | head -40 | sed 's/^#//'
      exit 0 ;;
    -*)
      echo "Unknown flag: $1" >&2
      exit 1 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
  esac
done

PROJECT_NAME="${POSITIONAL[0]:?Usage: $0 <project-name> [target-dir] [flags]   (try --help)}"
TARGET_DIR="${POSITIONAL[1]:-./$PROJECT_NAME}"

METHODOLOGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(cat "$METHODOLOGY_DIR/VERSION" | tr -d '[:space:]')"
SYNCED_AT="$(date -u +%Y-%m-%d)"

echo "Methodology: $VERSION"
echo "Project:     $PROJECT_NAME"
echo "Target:      $TARGET_DIR"
[[ "$WITH_MULTI_SERVICE" == "true" ]] && echo "Mode:        multi-service (two-tier vision + services-registry)"
echo ""

mkdir -p "$TARGET_DIR"/{.claude/{commands,agents,rules,state,hooks},docs/architecture}

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

cat > "$TARGET_DIR/.claude/.version" <<EOF
methodology: $VERSION
synced_at: $SYNCED_AT
source: https://github.com/cait-solutions/it-dev-methodology
EOF
echo "  ✓ .version"

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
copy_with_subst "$METHODOLOGY_DIR/templates/CLAUDE.template.md"          "$TARGET_DIR/CLAUDE.md"
copy_with_subst "$METHODOLOGY_DIR/templates/PRODUCT.template.md"         "$TARGET_DIR/PRODUCT.md"
copy_with_subst "$METHODOLOGY_DIR/templates/SYSTEM-MAP.template.md"      "$TARGET_DIR/docs/architecture/SYSTEM-MAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/DEVLOG.template.md"          "$TARGET_DIR/DEVLOG.md"
copy_with_subst "$METHODOLOGY_DIR/templates/IDEAS.template.md"           "$TARGET_DIR/IDEAS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/ROADMAP.template.md"         "$TARGET_DIR/ROADMAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/OPEN-QUESTIONS.template.md"  "$TARGET_DIR/OPEN-QUESTIONS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/HYPOTHESES.template.md"      "$TARGET_DIR/HYPOTHESES.md"
copy_with_subst "$METHODOLOGY_DIR/templates/RISKS.template.md"           "$TARGET_DIR/RISKS.md"

# ---------------------------------------------------------------------------
# Vision — single-tier (default) vs two-tier (--multi-service).
# ---------------------------------------------------------------------------
if [[ "$WITH_MULTI_SERVICE" == "true" ]]; then
  echo "→ vision/ (two-tier)"
  copy_with_subst "$METHODOLOGY_DIR/templates/vision/AGENT_VISION.template.md"  "$TARGET_DIR/docs/vision/AGENT_VISION.md"
  copy_with_subst "$METHODOLOGY_DIR/templates/vision/LONG_VISION.template.md"   "$TARGET_DIR/docs/vision/LONG_VISION_v1.md"

  # Tiny VISION.md at root pointing to docs/vision/
  if [[ ! -f "$TARGET_DIR/VISION.md" ]]; then
    cat > "$TARGET_DIR/VISION.md" <<EOF
# VISION — $PROJECT_NAME

Стратегические vision-документы:
- [docs/vision/AGENT_VISION.md](docs/vision/AGENT_VISION.md) — operational vision (English, MUST/MUST NOT)
- [docs/vision/LONG_VISION_v1.md](docs/vision/LONG_VISION_v1.md) — strategic manifest (full content)

Обновляется через \`/product-vision\` раз в 1-2 квартала.
EOF
    echo "  ✓ VISION.md (index pointing to docs/vision/)"
  else
    echo "  - VISION.md (exists — preserved)"
  fi

  echo "→ services-registry/"
  copy_with_subst "$METHODOLOGY_DIR/templates/services-registry.template.yaml"  "$TARGET_DIR/services-registry.yaml"
else
  echo "→ vision/ (single-tier)"
  copy_with_subst "$METHODOLOGY_DIR/templates/VISION.template.md"  "$TARGET_DIR/VISION.md"
fi

# ---------------------------------------------------------------------------
# Optional artifacts (flag-gated).
# ---------------------------------------------------------------------------
if [[ "$WITH_ADR" == "true" ]]; then
  echo "→ adr/"
  copy_with_subst "$METHODOLOGY_DIR/templates/adr/_TEMPLATE.md"          "$TARGET_DIR/docs/adr/_TEMPLATE.md"
  copy_with_subst "$METHODOLOGY_DIR/templates/adr/README.template.md"    "$TARGET_DIR/docs/adr/README.md"
fi

if [[ "$WITH_INBOX" == "true" ]]; then
  echo "→ inbox/"
  mkdir -p "$TARGET_DIR/inbox/_processed/rejected"
  touch "$TARGET_DIR/inbox/_processed/.gitkeep"
  touch "$TARGET_DIR/inbox/_processed/rejected/.gitkeep"
  copy_with_subst "$METHODOLOGY_DIR/templates/inbox/README.template.md"  "$TARGET_DIR/inbox/README.md"
fi

if [[ "$WITH_DATA_MAP" == "true" ]]; then
  echo "→ data-map/"
  copy_with_subst "$METHODOLOGY_DIR/templates/data-map.template.md"  "$TARGET_DIR/docs/data-map.md"
fi

if [[ "$WITH_GLOSSARY" == "true" ]]; then
  echo "→ glossary/"
  copy_with_subst "$METHODOLOGY_DIR/templates/glossary.template.md"  "$TARGET_DIR/docs/glossary.md"
fi

if [[ "$WITH_BEHAVIOR" == "true" ]]; then
  echo "→ behavior/"
  copy_with_subst "$METHODOLOGY_DIR/templates/BEHAVIOR.template.md"  "$TARGET_DIR/docs/BEHAVIOR.md"
fi

if [[ "$WITH_THREAT_MODEL" == "true" ]]; then
  echo "→ threat-model/"
  copy_with_subst "$METHODOLOGY_DIR/templates/threat-model.template.md"  "$TARGET_DIR/docs/threat-model.template.md"
fi

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
if [[ "$WITH_MULTI_SERVICE" == "true" ]]; then
  echo "  3. Fill in docs/vision/AGENT_VISION.md and LONG_VISION_v1.md"
  echo "  4. Add services to services-registry.yaml"
else
  echo "  3. Fill in VISION.md   — strategic axes"
fi
echo "  N. Open in Claude Code, then run /plan to start the first feature"
echo ""
echo "Sync methodology updates later via:"
echo "  $METHODOLOGY_DIR/scripts/sync-methodology.sh $TARGET_DIR"
