#!/usr/bin/env bash
#
# secrets-rollback.sh — restore .env from most recent backup.
#
# Usage:
#   bash scripts/secrets-rollback.sh             # restore from latest backup
#   bash scripts/secrets-rollback.sh --list      # list available backups
#   bash scripts/secrets-rollback.sh FILE        # restore from specific backup
#
# Backups are created by set-secret.sh before each write (.env.backup-{ts}).
# Retention configurable in CLAUDE.local.md ## Secrets.backup_retention_hours.
#
# Exit codes:
#   0  success
#   1  no backup found / restoration failed
#   2  usage error
#   5  user aborted

set -uo pipefail

TARGET=".env"

if [[ "${1:-}" == "--list" ]]; then
  echo "Available backups:"
  ls -lt "${TARGET}".backup-* 2>/dev/null | head -10 || echo "  (none)"
  exit 0
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,15p' "$0"
  exit 0
fi

if [[ -n "${1:-}" ]]; then
  BACKUP="$1"
  if [[ ! -f "$BACKUP" ]]; then
    echo "ERROR: backup file not found: $BACKUP" >&2
    exit 1
  fi
else
  # Find most recent backup
  BACKUP=$(ls -t "${TARGET}".backup-* 2>/dev/null | head -1 || true)
  if [[ -z "$BACKUP" ]]; then
    echo "ERROR: no backups found (pattern: ${TARGET}.backup-*)" >&2
    echo "       Backups are created automatically by set-secret.sh" >&2
    exit 1
  fi
fi

echo "Restoring .env from backup:"
echo "  Source: $BACKUP"
echo "  Target: $TARGET"
echo ""
echo "Current .env will be preserved as ${TARGET}.pre-rollback-$$"
echo ""

if [[ -t 0 ]]; then
  printf 'Proceed? (yes/no): '
  read -r confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Aborted." >&2
    exit 5
  fi
fi

# Save current as pre-rollback (in case user wants to redo).
if [[ -f "$TARGET" ]]; then
  cp "$TARGET" "${TARGET}.pre-rollback-$$"
fi

cp "$BACKUP" "$TARGET"
chmod 600 "$TARGET" 2>/dev/null || true

echo "✅ Restored from $BACKUP"
echo "   Current state pre-rollback saved as: ${TARGET}.pre-rollback-$$"
echo "   Verify: bash scripts/validate-secrets.sh"
