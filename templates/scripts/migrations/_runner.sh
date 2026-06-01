#!/usr/bin/env bash
#
# _runner.sh — migration registry runner (Flyway/Alembic-style for methodology artifacts).
#
# WHY: sync-methodology.sh overwrites methodology-owned files (commands/hooks/scripts)
# but NEVER transforms consumer's already-filled artifacts (maps, CLAUDE.local.md).
# When methodology changes the FORMAT of a filled artifact (e.g. mermaid link format),
# consumers stay on the old format forever — sync can't fix it (it's add-only/overwrite-
# canonical, never edits project-owned content). Migrations close exactly this class.
#
# CONTRACT — each migration file scripts/migrations/v<X.Y.Z>-<id>.sh defines:
#   MIGRATION_TARGET_VERSION="vX.Y.Z"   # informational + ordering
#   MIGRATION_ID="stable-id"            # logged in applied-list; source of truth
#   MIGRATION_MODE="auto" | "report"    # auto = self-heal idempotent; report = needs human
#   migration_describe()  -> human one-liner
#   migration_detect ROOT -> exit 0 if migration NEEDED (pure read, no writes)
#   migration_apply  ROOT -> idempotent transform; exit 0 on success/no-op
# NO top-level side effects (runner sources each file).
#
# STATE: .claude/state/migrations-applied.txt — one MIGRATION_ID per line, append-only,
#        per-consumer runtime (gitignored). Source of truth: applied = skip.
#        This fixes the erp bug (synced to latest but old-format transform never ran):
#        we key on "has this transform run here", NOT on version numbers.
#
# OUTPUT: machine-readable block parsed by /sync-audit:
#   HEALED: <id> — <describe>      (auto migration applied)
#   REPORT: <id> — <describe>      (report migration: needs human, NOT applied)
#   SKIPPED: <id>                  (already applied OR not needed)
#
# Usage: bash scripts/migrations/_runner.sh [ROOT]   (ROOT default: .)
# Bash 3.2 / Git-Bash (Windows) safe.

set -u

ROOT="${1:-.}"
MIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLIED_LIST="$ROOT/.claude/state/migrations-applied.txt"

mkdir -p "$ROOT/.claude/state" 2>/dev/null || true
[ -f "$APPLIED_LIST" ] || : > "$APPLIED_LIST"

_already_applied() {
  grep -qxF "$1" "$APPLIED_LIST" 2>/dev/null
}

_mark_applied() {
  echo "$1" >> "$APPLIED_LIST"
}

HEALED=""
REPORTED=""
SKIPPED=""

# Discover migrations in lexical order (zero-pad/semver in filenames keeps order).
shopt -s nullglob 2>/dev/null || true
for mig in "$MIG_DIR"/v*.sh; do
  [ -f "$mig" ] || continue
  # Source in a subshell-safe way: reset contract vars, then source.
  MIGRATION_TARGET_VERSION=""; MIGRATION_ID=""; MIGRATION_MODE="auto"
  unset -f migration_describe migration_detect migration_apply 2>/dev/null || true
  # shellcheck disable=SC1090
  . "$mig"
  [ -n "$MIGRATION_ID" ] || continue

  if _already_applied "$MIGRATION_ID"; then
    SKIPPED="$SKIPPED $MIGRATION_ID"
    continue
  fi

  # detect: needed?
  if ! migration_detect "$ROOT" 2>/dev/null; then
    SKIPPED="$SKIPPED $MIGRATION_ID"
    continue
  fi

  desc="$(migration_describe 2>/dev/null || echo "$MIGRATION_ID")"

  case "$MIGRATION_MODE" in
    auto)
      if migration_apply "$ROOT" 2>/dev/null; then
        _mark_applied "$MIGRATION_ID"
        HEALED="$HEALED|$MIGRATION_ID — $desc"
        echo "HEALED: $MIGRATION_ID — $desc"
      else
        echo "REPORT: $MIGRATION_ID — $desc (auto-apply FAILED, needs manual check)"
        REPORTED="$REPORTED|$MIGRATION_ID"
      fi
      ;;
    report)
      echo "REPORT: $MIGRATION_ID — $desc"
      REPORTED="$REPORTED|$MIGRATION_ID"
      ;;
    *)
      echo "REPORT: $MIGRATION_ID — unknown MODE '$MIGRATION_MODE', not applied"
      ;;
  esac
done

# Trailing summary line for /sync-audit parsing.
echo "MIGRATIONS_DONE healed=$(printf '%s' "$HEALED" | tr -cd '|' | wc -c | tr -d ' ') reported=$(printf '%s' "$REPORTED" | tr -cd '|' | wc -c | tr -d ' ')"
exit 0
