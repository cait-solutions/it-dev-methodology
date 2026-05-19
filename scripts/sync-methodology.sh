#!/usr/bin/env bash
#
# sync-methodology.sh — update an existing project's .claude/commands/ (and hooks/agents)
# from this methodology-platform checkout. Run from anywhere; the script locates the
# methodology root via its own path.
#
# Usage:
#   /path/to/methodology-platform/scripts/sync-methodology.sh <target-project-dir>
#
# Self-apply (methodology-platform itself):
#   bash scripts/sync-methodology.sh .
#   Restores .claude/ + checks all artifacts after a fresh clone.
#
# What it does:
#   1. Detects local modifications (commands without AUTO-GENERATED banner) and prompts.
#   2. Overwrites .claude/commands/*.md with banner-prefixed copies from methodology.
#   3. Copies new agent skeletons (existing per-project content is preserved).
#   4. Copies hooks (overwrites — they are universal infrastructure).
#   5. Updates .claude/.version.
#   6. OVERWRITE canonical: CLAUDE.md (with migration to CLAUDE.local.md), docs/adr/_TEMPLATE.md.
#   7. MERGE: triggers.json (new template fields added; existing values preserved).
#   8. PRESERVE (add-only): all project-owned artifacts (PRODUCT.md, VISION.md, etc.).
#
# Artifact taxonomy:
#   OVERWRITE (methodology-owned): commands/, hooks/, model-tiers.md, CLAUDE.md, adr/_TEMPLATE.md
#   MERGE (special):               triggers.json (add new keys), settings.json (add if missing)
#   PRESERVE (project-owned):      everything else — CLAUDE.local.md, PRODUCT.md, VISION.md, etc.

set -euo pipefail

TARGET_DIR="${1:?Usage: $0 <target-project-dir>}"
METHODOLOGY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(cat "$METHODOLOGY_DIR/VERSION" | tr -d '[:space:]')"
SYNCED_AT="$(date -u +%Y-%m-%d)"

# Detect self-apply (methodology-platform syncing itself after fresh clone).
IS_SELF_APPLY=false
_target_abs="$(cd "$TARGET_DIR" && pwd)"
_method_abs="$(cd "$METHODOLOGY_DIR" && pwd)"
if [[ "$_target_abs" == "$_method_abs" ]]; then
  IS_SELF_APPLY=true
fi

if [[ ! -d "$TARGET_DIR/.claude" ]]; then
  if [[ "$IS_SELF_APPLY" == "true" ]]; then
    mkdir -p "$TARGET_DIR/.claude/"{commands,agents,rules,state,hooks}
    echo "  (created .claude/ — self-apply on fresh clone)"
  else
    echo "ERROR: $TARGET_DIR/.claude not found."
    echo "       Run new-project-init.sh first to bootstrap the project."
    exit 1
  fi
fi
# commands/ may be absent after fresh clone (gitignored) — create it
if [[ ! -d "$TARGET_DIR/.claude/commands" ]]; then
  mkdir -p "$TARGET_DIR/.claude/commands"
  echo "  (created .claude/commands/ — absent after clone, restoring via sync)"
else
  mkdir -p "$TARGET_DIR/.claude/commands"
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

# sync_claude_canonical: overwrite CLAUDE.md with canonical methodology rules.
# On first run: if CLAUDE.md exists without banner, migrate project content to CLAUDE.local.md.
sync_claude_canonical() {
  local dest="$TARGET_DIR/CLAUDE.md"
  local local_dest="$TARGET_DIR/CLAUDE.local.md"
  local src="$METHODOLOGY_DIR/templates/CLAUDE.template.md"
  local src_local="$METHODOLOGY_DIR/templates/CLAUDE_LOCAL.template.md"
  local pname="$(basename "$TARGET_DIR")"

  if [[ ! -f "$src" ]]; then
    echo "  ! CLAUDE.md (template missing — skipped)"
    return
  fi

  if [[ -f "$dest" ]]; then
    if head -1 "$dest" 2>/dev/null | grep -q "AUTO-GENERATED from methodology-platform"; then
      # Already canonical format — update in place
      inject_md_banner "$src" "$dest"
      echo "  ↻ CLAUDE.md (canonical rules updated)"
    else
      # Old-style project: migrate project content to CLAUDE.local.md first
      if [[ ! -f "$local_dest" ]]; then
        cp "$dest" "$local_dest"
        echo "  ✓ CLAUDE.local.md (migrated project content from CLAUDE.md)"
        echo "    ⚠️  Review CLAUDE.local.md: keep only project-specific sections"
        echo "        (Stack, Architecture invariants, Security threats, Key files, External links)"
      else
        echo "  - CLAUDE.local.md (exists — preserved)"
      fi
      inject_md_banner "$src" "$dest"
      echo "  ↻ CLAUDE.md (canonical rules updated — project content in CLAUDE.local.md)"
    fi
  else
    inject_md_banner "$src" "$dest"
    echo "  ✓ CLAUDE.md (created canonical)"
    if [[ -f "$src_local" ]]; then
      sed "s/{{Project Name}}/$pname/g" "$src_local" > "$local_dest"
      echo "  ✓ CLAUDE.local.md (created from template)"
    fi
  fi
}

# merge_triggers_json: add new fields from template to existing triggers.json.
# Existing values are preserved; only new keys from template are added.
# Requires python3 (available on all platforms that have hooks enabled).
merge_triggers_json() {
  local existing="$TARGET_DIR/.claude/state/triggers.json"
  local template="$METHODOLOGY_DIR/templates/triggers.json.template"

  mkdir -p "$TARGET_DIR/.claude/state"

  if [[ ! -f "$existing" ]]; then
    cp "$template" "$existing"
    echo "  ✓ triggers.json (initialized)"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    TJ_EXISTING="$existing" TJ_TEMPLATE="$template" python3 - <<'PYEOF' || true
import json, os, sys
try:
    with open(os.environ['TJ_EXISTING']) as f:
        existing = json.load(f)
    with open(os.environ['TJ_TEMPLATE']) as f:
        template = json.load(f)
    def deep_merge(t, e):
        if isinstance(t, dict) and isinstance(e, dict):
            result = dict(t)
            for k, v in e.items():
                result[k] = deep_merge(t.get(k, v), v)
            return result
        return e
    merged = deep_merge(template, existing)
    with open(os.environ['TJ_EXISTING'], 'w') as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print("  ↻ triggers.json (merged new fields from template)")
except Exception as ex:
    print("  ! triggers.json (merge failed: {} — preserved)".format(ex))
PYEOF
  else
    echo "  - triggers.json (python3 not available — preserved; merge new fields manually)"
  fi
}

# check_artifact: add file from template if missing; never overwrite.
check_artifact() {
  local dest_rel="$1"
  local src_rel="$2"
  local dest="$TARGET_DIR/$dest_rel"
  local src="$METHODOLOGY_DIR/$src_rel"
  if [[ -f "$dest" ]]; then
    echo "  - $dest_rel (exists — preserved)"
  elif [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  ✓ $dest_rel (added from template)"
  else
    echo "  ! $dest_rel (template missing — skipped)"
  fi
}

# check_artifact_subst: same as check_artifact but substitutes {{Project Name}}.
check_artifact_subst() {
  local dest_rel="$1"
  local src_rel="$2"
  local project_name="$3"
  local dest="$TARGET_DIR/$dest_rel"
  local src="$METHODOLOGY_DIR/$src_rel"
  if [[ -f "$dest" ]]; then
    echo "  - $dest_rel (exists — preserved)"
  elif [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    sed "s/{{Project Name}}/$project_name/g" "$src" > "$dest"
    echo "  ✓ $dest_rel (added from template)"
  else
    echo "  ! $dest_rel (template missing — skipped)"
  fi
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
if compgen -G "$METHODOLOGY_DIR/templates/.claude/agents/*.template.md" >/dev/null; then
  echo "→ agents/"
  mkdir -p "$TARGET_DIR/.claude/agents"
  for agent in "$METHODOLOGY_DIR"/templates/.claude/agents/*.template.md; do
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
if [[ -d "$METHODOLOGY_DIR/templates/.claude/hooks" ]] && compgen -G "$METHODOLOGY_DIR/templates/.claude/hooks/*" >/dev/null; then
  echo "→ hooks/"
  mkdir -p "$TARGET_DIR/.claude/hooks"
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

# ---------------------------------------------------------------------------
# Artifact coverage — add-only, never overwrite project content.
# Self-apply: restore methodology artifacts (gitignored, absent after clone).
# Consumer: fill any artifact gaps introduced in newer methodology versions.
# ---------------------------------------------------------------------------
echo "→ artifact coverage/"
if [[ "$IS_SELF_APPLY" == "true" ]]; then
  # Restore methodology-platform-specific artifacts after fresh clone.
  if [[ -f "$TARGET_DIR/CLAUDE.md" ]]; then
    echo "  - CLAUDE.md (exists — preserved)"
  elif [[ -f "$METHODOLOGY_DIR/templates/CLAUDE-methodology.template.md" ]]; then
    sed -e "s/{{Project Name}}/methodology-platform/g" \
        -e "s|{{github-url}}|https://github.com/cait-solutions/it-dev-methodology|g" \
        "$METHODOLOGY_DIR/templates/CLAUDE-methodology.template.md" > "$TARGET_DIR/CLAUDE.md"
    echo "  ✓ CLAUDE.md (restored from methodology template)"
  fi
  if [[ -f "$TARGET_DIR/CLAUDE_LONG.md" ]]; then
    echo "  - CLAUDE_LONG.md (exists — preserved)"
  elif [[ -f "$METHODOLOGY_DIR/templates/CLAUDE_LONG-methodology.template.md" ]]; then
    sed -e "s/{{Project Name}}/methodology-platform/g" \
        -e "s|{{github-url}}|https://github.com/cait-solutions/it-dev-methodology|g" \
        "$METHODOLOGY_DIR/templates/CLAUDE_LONG-methodology.template.md" > "$TARGET_DIR/CLAUDE_LONG.md"
    echo "  ✓ CLAUDE_LONG.md (restored from methodology template)"
  fi
else
  # Consumer project: overwrite canonical artifacts, add missing project-owned artifacts.
  _pname="$(basename "$TARGET_DIR")"

  # --- OVERWRITE: methodology-canonical (always synced with banner) ---
  echo "  [canonical — overwrite]"
  sync_claude_canonical
  # ADR template format evolves with methodology
  if [[ -f "$METHODOLOGY_DIR/templates/adr/_TEMPLATE.md" ]]; then
    mkdir -p "$TARGET_DIR/docs/adr"
    inject_md_banner "$METHODOLOGY_DIR/templates/adr/_TEMPLATE.md" "$TARGET_DIR/docs/adr/_TEMPLATE.md"
    echo "  ↻ docs/adr/_TEMPLATE.md (updated)"
  fi

  # --- MERGE: special handling ---
  echo "  [special — merge]"
  merge_triggers_json
  check_artifact       ".claude/settings.json"            "templates/settings.template.json"

  # --- PRESERVE: project-owned (add-only, never overwrite) ---
  echo "  [project-owned — add if missing]"
  check_artifact_subst "CLAUDE.local.md"                  "templates/CLAUDE_LOCAL.template.md"        "$_pname"
  check_artifact_subst "CLAUDE_LONG.md"                   "templates/CLAUDE_LONG.template.md"         "$_pname"
  check_artifact_subst "VISION.md"                        "templates/VISION.template.md"              "$_pname"
  check_artifact_subst "PRODUCT.md"                       "templates/PRODUCT.template.md"             "$_pname"
  check_artifact_subst "DEVLOG.md"                        "templates/DEVLOG.template.md"              "$_pname"
  check_artifact_subst "IDEAS.md"                         "templates/IDEAS.template.md"               "$_pname"
  check_artifact_subst "ROADMAP.md"                       "templates/ROADMAP.template.md"             "$_pname"
  check_artifact_subst "RISKS.md"                         "templates/RISKS.template.md"               "$_pname"
  check_artifact_subst "HYPOTHESES.md"                    "templates/HYPOTHESES.template.md"          "$_pname"
  check_artifact_subst "OPEN-QUESTIONS.md"                "templates/OPEN-QUESTIONS.template.md"      "$_pname"
  check_artifact_subst "README.md"                        "templates/README.template.md"              "$_pname"
  check_artifact_subst "AGENT-GAPS.md"                    "templates/AGENT-GAPS.md.template"          "$_pname"
  check_artifact_subst "docs/architecture/SYSTEM-MAP.md"  "templates/SYSTEM-MAP.template.md"          "$_pname"
  check_artifact_subst "docs/product/USER-MAP.md"         "templates/USER-MAP.template.md"            "$_pname"
  check_artifact_subst "docs/product/ARTIFACT-MAP.md"     "templates/ARTIFACT-MAP.template.md"        "$_pname"
  check_artifact_subst "docs/vision/AGENT_VISION.md"      "templates/vision/AGENT_VISION.template.md" "$_pname"
  check_artifact_subst "docs/vision/LONG_VISION_v1.md"    "templates/vision/LONG_VISION.template.md"  "$_pname"
  check_artifact_subst "services-registry.yaml"           "templates/services-registry.template.yaml" "$_pname"
  check_artifact_subst "docs/data-map.md"                 "templates/data-map.template.md"            "$_pname"
  check_artifact_subst "docs/glossary.md"                 "templates/glossary.template.md"            "$_pname"
  check_artifact_subst "docs/BEHAVIOR.md"                 "templates/BEHAVIOR.template.md"            "$_pname"
  check_artifact_subst "docs/adr/README.md"               "templates/adr/README.template.md"              "$_pname"
  check_artifact       "inbox/README.md"                  "templates/inbox/README.template.md"
  check_artifact_subst ".claude/rules/README.md"          "templates/.claude/rules/README.template.md" "$_pname"
fi

echo ""
echo "✅ Sync complete. Methodology version: $VERSION"
