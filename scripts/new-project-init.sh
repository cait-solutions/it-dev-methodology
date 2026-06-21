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
#   .claude/rules/project-context.md (shared project context: Design Spec links, domain knowledge)
#   README.md (workspace setup + links to SYSTEM-MAP/USER-MAP)
#   AGENTS.md (concurrent-session task-ownership coordination)
#   CLAUDE.md, CLAUDE_LONG.md, PRODUCT.md, VISION.md
#   docs/architecture/SYSTEM-MAP.md, docs/product/{USER-MAP,ARTIFACT-MAP}.md
#   docs/vision/{AGENT_VISION,LONG_VISION_v1}.md
#   docs/adr/{_TEMPLATE,README}.md, docs/data-map.md
#   docs/sync-vision-reports/ (placeholder for /sync-vision output)
#   inbox/{README,_processed/,_processed/rejected/}, services-registry.yaml
#   DEVLOG.md, IDEAS.md, ROADMAP.md, NORTH-STAR.md, OPEN-QUESTIONS.md, HYPOTHESES.md, RISKS.md
#   .gitignore (standard ignores)
#   triggers.json (local state)
#
# One methodology, one bootstrap. For solo-dev: ignore docs that don't apply (docs/adr/, services-registry.yaml, etc.).
# For multi-service: fill in the multi-tier vision and services registry.
#
# Idempotent: existing files preserved (only .claude/commands/ overwritten by sync).

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing.
# Usage: new-project-init.sh <project-name> [target-dir] [--with-marketing]
#   --with-marketing  Also copy marketing skills (.claude/skills/) and MARKETING.md template.
# ---------------------------------------------------------------------------
WITH_MARKETING=false
PROJECT_NAME=""
TARGET_DIR=""
for arg in "$@"; do
  case "$arg" in
    --with-marketing) WITH_MARKETING=true ;;
    *) if [[ -z "$PROJECT_NAME" ]]; then PROJECT_NAME="$arg"; elif [[ -z "$TARGET_DIR" ]]; then TARGET_DIR="$arg"; fi ;;
  esac
done
if [[ -z "$PROJECT_NAME" ]]; then
  echo "Usage: $0 <project-name> [target-dir] [--with-marketing]" >&2
  exit 1
fi
TARGET_DIR="${TARGET_DIR:-./$PROJECT_NAME}"

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

# inject_skill_banner: copy SKILL.md with {{SYNCED_AT}} substituted in metadata block.
# YAML frontmatter must stay on line 1 — banner goes inside metadata: field.
inject_skill_banner() {
  local src="$1"
  local dest="$2"
  sed "s/{{SYNCED_AT}}/$SYNCED_AT/g" "$src" > "$dest"
}

# ---------------------------------------------------------------------------
# Slash commands.
#
# NOTE: Glob 'commands/*.md' намеренно НЕ матчит 'commands-local/*.md' —
# methodology-only команды не bootstrap'ятся консьюмерам. См. commands-local/.keep.
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
if compgen -G "$METHODOLOGY_DIR/templates/.claude/agents/*.template.md" >/dev/null; then
  echo "→ agents/"
  for agent in "$METHODOLOGY_DIR"/templates/.claude/agents/*.template.md; do
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
if [[ -d "$METHODOLOGY_DIR/templates/.claude/hooks" ]] && compgen -G "$METHODOLOGY_DIR/templates/.claude/hooks/*" >/dev/null; then
  echo "→ hooks/"
  for hook in "$METHODOLOGY_DIR"/templates/.claude/hooks/*; do
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
# Skills — copied only when --with-marketing flag is set.
# Marketing skills require MARKETING.md; not all projects need them.
# ---------------------------------------------------------------------------
if [[ "$WITH_MARKETING" == "true" ]] && [[ -d "$METHODOLOGY_DIR/skills" ]]; then
  if compgen -G "$METHODOLOGY_DIR/skills/*" > /dev/null 2>&1; then
    echo "→ skills/ (--with-marketing)"
    mkdir -p "$TARGET_DIR/.claude/skills"
    for skill_dir in "$METHODOLOGY_DIR/skills"/*/; do
      [[ -d "$skill_dir" ]] || continue
      skill_name="$(basename "$skill_dir")"
      dest_dir="$TARGET_DIR/.claude/skills/$skill_name"
      mkdir -p "$dest_dir"
      if [[ -f "$skill_dir/SKILL.md" ]]; then
        inject_skill_banner "$skill_dir/SKILL.md" "$dest_dir/SKILL.md"
        echo "  ✓ $skill_name/SKILL.md"
      fi
    done
    # Also add MARKETING.md template if missing
    if [[ -f "$METHODOLOGY_DIR/templates/MARKETING.template.md" ]]; then
      if [[ ! -f "$TARGET_DIR/MARKETING.md" ]]; then
        sed "s/{{Project Name}}/$PROJECT_NAME/g" "$METHODOLOGY_DIR/templates/MARKETING.template.md" > "$TARGET_DIR/MARKETING.md"
        echo "  ✓ MARKETING.md (added from template)"
      else
        echo "  - MARKETING.md (exists — preserved)"
      fi
    fi
  fi
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
copy_with_subst "$METHODOLOGY_DIR/templates/AGENTS.md.template"          "$TARGET_DIR/AGENTS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/CLAUDE.template.md"          "$TARGET_DIR/CLAUDE.md"
copy_with_subst "$METHODOLOGY_DIR/templates/CLAUDE_LOCAL.template.md"    "$TARGET_DIR/CLAUDE.local.md"
copy_with_subst "$METHODOLOGY_DIR/templates/CLAUDE_LONG.template.md"     "$TARGET_DIR/CLAUDE_LONG.md"
copy_with_subst "$METHODOLOGY_DIR/templates/PRODUCT.template.md"         "$TARGET_DIR/PRODUCT.md"
copy_with_subst "$METHODOLOGY_DIR/templates/SYSTEM-MAP.template.md"      "$TARGET_DIR/docs/architecture/SYSTEM-MAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/USER-MAP.template.md"        "$TARGET_DIR/docs/product/USER-MAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/ARTIFACT-MAP.template.md"    "$TARGET_DIR/docs/product/ARTIFACT-MAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/DEVLOG.template.md"          "$TARGET_DIR/DEVLOG.md"
copy_with_subst "$METHODOLOGY_DIR/templates/IDEAS.template.md"           "$TARGET_DIR/IDEAS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/ROADMAP.template.md"         "$TARGET_DIR/ROADMAP.md"
copy_with_subst "$METHODOLOGY_DIR/templates/NORTH-STAR.template.md"      "$TARGET_DIR/NORTH-STAR.md"
copy_with_subst "$METHODOLOGY_DIR/templates/OPEN-QUESTIONS.template.md"  "$TARGET_DIR/OPEN-QUESTIONS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/HYPOTHESES.template.md"      "$TARGET_DIR/HYPOTHESES.md"
copy_with_subst "$METHODOLOGY_DIR/templates/RISKS.template.md"           "$TARGET_DIR/RISKS.md"

# ---------------------------------------------------------------------------
# Secrets foundation (v4.34.0+).
# .env.example and secrets-manifest.yaml are CANONICAL — overwritten on init.
# .env itself is NEVER created by init — user copies from .env.example and
# fills values via `bash scripts/set-secret.sh KEY <value>`.
# ---------------------------------------------------------------------------
echo "→ secrets foundation/"
if [[ -f "$METHODOLOGY_DIR/templates/.env.example.template" ]]; then
  copy_with_subst "$METHODOLOGY_DIR/templates/.env.example.template" "$TARGET_DIR/.env.example"
fi
if [[ -f "$METHODOLOGY_DIR/templates/secrets-manifest.yaml.template" ]]; then
  mkdir -p "$TARGET_DIR/.claude"
  if [[ -f "$TARGET_DIR/.claude/secrets-manifest.yaml" ]]; then
    echo "  - .claude/secrets-manifest.yaml (exists — preserved; manual review for new manifest_version)"
  else
    copy_with_subst "$METHODOLOGY_DIR/templates/secrets-manifest.yaml.template" "$TARGET_DIR/.claude/secrets-manifest.yaml"
    # Platform-detect (P-005): не навязывать GITHUB_PAT GitLab-проектам.
    # Определить платформу из remote origin и подсказать какой git-секрит
    # объявить. Шаблон поставляет git-секреты закомментированными → агент/юзер
    # раскомментирует подходящий. init только сообщает рекомендацию (не правит
    # YAML автоматически — раскомментирование per-host оставляем явным шагом,
    # чтобы не ломать manifest парсером).
    _init_remote=$(cd "$TARGET_DIR" 2>/dev/null && git remote get-url origin 2>/dev/null || true)
    case "$_init_remote" in
      "")                  echo "  - secrets-manifest: remote origin не настроен → git-секрет не объявлен (настрой remote, затем раскомментируй нужный в manifest)" ;;
      *github.com*)        echo "  - secrets-manifest: remote = GitHub → push обычно через gh credential helper (gh auth login). GITHUB_PAT в .env НЕ обязателен (раскомментируй в manifest только если используешь PAT)." ;;
      *gitlab*|*code.*)    echo "  - secrets-manifest: remote = GitLab-подобный ($_init_remote) → объяви GITLAB_* секрет (см. закомментированный пример GITLAB_NEXCHANCE в manifest). НЕ объявляй GITHUB_PAT." ;;
      *)                   echo "  - secrets-manifest: remote = $_init_remote (платформа не распознана) → объяви секрет соответствующий хосту вручную в manifest." ;;
    esac
  fi
fi

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

echo "→ agent-gaps/"
copy_with_subst "$METHODOLOGY_DIR/templates/AGENT-GAPS.md.template"  "$TARGET_DIR/AGENT-GAPS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/PRODUCT-GAPS.md.template" "$TARGET_DIR/PRODUCT-GAPS.md"
copy_with_subst "$METHODOLOGY_DIR/templates/CODE-GAPS.md.template"    "$TARGET_DIR/CODE-GAPS.md"

echo "→ behavior/"
copy_with_subst "$METHODOLOGY_DIR/templates/BEHAVIOR.template.md"  "$TARGET_DIR/docs/BEHAVIOR.md"

echo "→ threat-model/"
copy_with_subst "$METHODOLOGY_DIR/templates/threat-model.template.md"  "$TARGET_DIR/docs/threat-model.template.md"

echo "→ rules/"
copy_with_subst "$METHODOLOGY_DIR/templates/.claude/rules/README.template.md"          "$TARGET_DIR/.claude/rules/README.md"
copy_with_subst "$METHODOLOGY_DIR/templates/.claude/rules/project-context.template.md" "$TARGET_DIR/.claude/rules/project-context.md"

echo "→ gitignore/"
copy_with_subst "$METHODOLOGY_DIR/templates/.gitignore.template"  "$TARGET_DIR/.gitignore"

# ---------------------------------------------------------------------------
# Living Artifact Registry (v5.51.0+).
# Guard: existing LAR is owned by the project — never overwrite.
# ---------------------------------------------------------------------------
echo "→ lar/"
_lar_dest="$TARGET_DIR/docs/architecture/LIVING-ARTIFACTS.md"
_lar_tmpl="$METHODOLOGY_DIR/templates/LIVING-ARTIFACTS.template.md"
if [[ -f "$_lar_dest" ]]; then
  echo "  - LIVING-ARTIFACTS.md (exists — preserved; review Detection column for auto: markers)"
elif [[ -f "$_lar_tmpl" ]]; then
  copy_with_subst "$_lar_tmpl" "$_lar_dest"
else
  echo "  - LIVING-ARTIFACTS.md (template not found — skip; install methodology v5.51.0+)"
fi

# ---------------------------------------------------------------------------
# Git init.
# ---------------------------------------------------------------------------
if [[ ! -d "$TARGET_DIR/.git" ]]; then
  ( cd "$TARGET_DIR" && git init -q )
  echo "  ✓ git initialized"
fi

# ---------------------------------------------------------------------------
# Fill push-critical config from the live git remote (closes the new-consumer
# remote-clobber class). The template ships origin_url / push_token_owner as
# <owner>/<repo> placeholders; if a real 'origin' remote exists, substitute the real
# values so sync-methodology.sh never auto-corrects a real remote to a placeholder.
# PRESERVE: only rewrite lines that are STILL the unfilled placeholder (re-run safe).
# tmp+mv (no sed -i — Git Bash/Windows CRLF quirk). Bash 3.2 safe.
# ---------------------------------------------------------------------------
_cl="$TARGET_DIR/CLAUDE.local.md"
if [[ -f "$_cl" ]]; then
  _real_remote="$( ( cd "$TARGET_DIR" && git remote get-url origin 2>/dev/null ) || true )"
  if [[ -n "$_real_remote" ]]; then
    # owner = first path segment after host; handles https:// and git@host: forms
    _slug="$(printf '%s' "$_real_remote" | sed -e 's#^git@[^:]*:##' -e 's#^https\{0,1\}://[^/]*/##' -e 's#\.git$##')"
    _owner="$(printf '%s' "$_slug" | cut -d/ -f1)"
    if grep -q '^origin_url:.*<owner>.*<repo>' "$_cl" 2>/dev/null; then
      sed "s#^origin_url:.*#origin_url: $_real_remote#" "$_cl" > "$_cl.tmp" && mv "$_cl.tmp" "$_cl"
      echo "  ✓ CLAUDE.local.md: origin_url ← $_real_remote (from live remote)"
    fi
    if grep -q '^push_token_owner: <github-username-with-write-access>' "$_cl" 2>/dev/null; then
      sed "s#^push_token_owner:.*#push_token_owner: $_owner#" "$_cl" > "$_cl.tmp" && mv "$_cl.tmp" "$_cl"
      echo "  ✓ CLAUDE.local.md: push_token_owner ← $_owner"
    fi
  else
    echo "  - CLAUDE.local.md: no 'origin' remote yet → origin_url left as placeholder (set remote + re-run init, or fill manually before /push)"
  fi
fi

echo ""
echo "✅ Project '$PROJECT_NAME' bootstrapped at $TARGET_DIR"
echo ""
echo "Next steps:"
echo "  1. Fill in CLAUDE.local.md — project stack, architecture invariants, security threats"
echo "  2. Fill in PRODUCT.md      — product behavior from user POV"
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
echo "  Workspace setup (recommended):"
echo "    Inside $TARGET_DIR/, clone your code repos alongside it-dev-methodology/:"
echo "      cd $TARGET_DIR"
echo "      git clone <it-dev-methodology-url> it-dev-methodology"
echo "      git clone <backend-repo-url>       [project-name]-backend"
echo "    These are already gitignored (.gitignore includes it-dev-methodology/ and code repos)."
echo "    Open $TARGET_DIR/ in Claude Code — Claude sees all repos in one workspace."
echo ""
echo "  NOTE: .claude/commands/ + hooks/ + model-tiers.md are COMMITTED (v7.8.2+)."
echo "  A fresh 'git clone' of this project has working commands/hooks immediately —"
echo "  no manual sync needed just to use them. (They stay derived: DO NOT edit"
echo "  directly — canon lives in it-dev-methodology; sync overwrites them.)"
echo ""
echo "Pull methodology UPDATES later (from inside $TARGET_DIR/):"
echo "  bash it-dev-methodology/scripts/sync-methodology.sh ."
