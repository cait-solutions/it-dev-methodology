#!/usr/bin/env bash
#
# migrate-claude-md.sh — helper for existing consumers (PAI, ERP, ...)
# to migrate from single-file CLAUDE.md to split CLAUDE.md + CLAUDE_LONG.md
# convention introduced in methodology v3.0.0 (Phase G2).
#
# What it does:
#   1. Reads existing <target>/CLAUDE.md
#   2. Copies it to <target>/CLAUDE_LONG.md (full content preserved)
#   3. Does NOT modify CLAUDE.md — that requires human judgment
#   4. Prints instructions for manual extraction of short rules
#
# What it does NOT do:
#   - Auto-split content (different projects have different structure)
#   - Decide what stays in CLAUDE.md (operational) vs moves to CLAUDE_LONG.md (rationale)
#   - Modify any other artifact
#
# Usage:
#   /path/to/methodology-platform/scripts/migrate-claude-md.sh <target-project-dir>
#
# Idempotent: refuses to overwrite existing CLAUDE_LONG.md.

set -euo pipefail

TARGET_DIR="${1:?Usage: $0 <target-project-dir>}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "ERROR: $TARGET_DIR is not a directory" >&2
  exit 1
fi

CLAUDE_SHORT="$TARGET_DIR/CLAUDE.md"
CLAUDE_LONG="$TARGET_DIR/CLAUDE_LONG.md"

if [[ ! -f "$CLAUDE_SHORT" ]]; then
  echo "ERROR: $CLAUDE_SHORT not found — nothing to migrate" >&2
  exit 1
fi

if [[ -f "$CLAUDE_LONG" ]]; then
  echo "ERROR: $CLAUDE_LONG already exists — migration likely already done" >&2
  echo "       To redo: delete $CLAUDE_LONG and rerun this script" >&2
  exit 1
fi

LINES_BEFORE="$(wc -l < "$CLAUDE_SHORT" | tr -d ' ')"

# Copy full content to CLAUDE_LONG.md
cp "$CLAUDE_SHORT" "$CLAUDE_LONG"

# Prepend convention banner to the copy
{
  cat <<'EOF'
# CLAUDE_LONG.md

Полный контекст методологических правил с обоснованием. Парный файл к [CLAUDE.md](CLAUDE.md):
- CLAUDE.md = WHAT (rules, MUST/MUST NOT, scan-friendly, auto-loaded)
- CLAUDE_LONG.md = WHY (rationale, edge cases, examples)

> Этот файл был создан скриптом migrate-claude-md.sh из единого CLAUDE.md.
> После миграции — отредактируй CLAUDE.md чтобы оставить только короткие правила.
> Этот CLAUDE_LONG.md остаётся как полная база знаний.

---

EOF
  cat "$CLAUDE_SHORT"
} > "$CLAUDE_LONG.tmp"
mv "$CLAUDE_LONG.tmp" "$CLAUDE_LONG"

echo "✅ Migrated: $CLAUDE_LONG created ($LINES_BEFORE lines + convention banner)"
echo ""
echo "Next manual steps:"
echo ""
echo "  1. Edit $CLAUDE_SHORT — reduce to short form:"
echo "     - Keep WHAT (rules, MUST/MUST NOT, conventions)"
echo "     - Remove WHY (rationale, historical motivation, edge cases)"
echo "     - Target: ~80-150 lines (currently $LINES_BEFORE)"
echo "     - Add cross-references: [CLAUDE_LONG.md § ...](anchor) where deep context needed"
echo ""
echo "  2. Add convention banner to the top of $CLAUDE_SHORT:"
echo ""
echo "     > **Convention:**"
echo "     > - This file (CLAUDE.md) = **WHAT** — rules, scan-friendly. Auto-loaded."
echo "     > - [CLAUDE_LONG.md](CLAUDE_LONG.md) = **WHY** — rationale, edge cases."
echo ""
echo "  3. Reference $CLAUDE_SHORT structure in $TARGET_DIR/templates/CLAUDE.template.md"
echo "     (the canonical short-form template in methodology-platform repo)"
echo ""
echo "  4. Record migration in DEVLOG.md with tag [methodology][migration]:"
echo "     - what changed (single CLAUDE.md → split)"
echo "     - why (methodology v3.0.0 Phase G2)"
echo "     - data map: unchanged (rules content preserved in CLAUDE_LONG.md)"
echo ""
echo "  5. Commit both files in the same commit."
