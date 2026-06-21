#!/usr/bin/env bash
#
# secrets-cleanup-backups.sh — remove .env.backup-* older than retention.
#
# delivery-allow: легит ручной tool очистки .env-бэкапов — reactive cleanup без
#   повседневного command-entry (decision consumer-delivery-hygiene 2026-06-20).
#   validate-consumer-delivery.sh пропускает его по этому маркеру.
#
# Retention configurable in CLAUDE.local.md ## Secrets.backup_retention_hours
# (default 24h). Also called automatically at end of set-secret.sh.
#
# Usage:
#   bash scripts/secrets-cleanup-backups.sh           # use configured retention
#   bash scripts/secrets-cleanup-backups.sh --all     # remove ALL backups (no age check)
#   bash scripts/secrets-cleanup-backups.sh --hours N # custom retention

set -uo pipefail

TARGET=".env"
RETENTION_HOURS="24"

if [[ -f "CLAUDE.local.md" ]]; then
  v=$(awk '/^##[[:space:]]+Secrets/{f=1; next} /^## /{f=0} f' CLAUDE.local.md 2>/dev/null \
      | grep -E "^[[:space:]]*backup_retention_hours:" | head -1 \
      | sed 's/.*backup_retention_hours:[[:space:]]*//' | tr -d '"'"'"'' | tr -d '[:space:]')
  [[ -n "$v" ]] && RETENTION_HOURS="$v"
fi

case "${1:-}" in
  --all)    RETENTION_HOURS="0" ;;
  --hours)  RETENTION_HOURS="${2:-24}" ;;
  --help|-h) sed -n '2,12p' "$0"; exit 0 ;;
esac

py -c "
import os, time, glob
retention_secs = int('${RETENTION_HOURS}') * 3600
now = time.time()
removed = 0
patterns = ['${TARGET}.backup-*', '${TARGET}.pre-rollback-*']
for pat in patterns:
    for f in glob.glob(pat):
        try:
            age = now - os.path.getmtime(f)
            if age > retention_secs:
                os.unlink(f)
                removed += 1
                print(f'  removed: {f} (age: {int(age/3600)}h)')
        except Exception as e:
            print(f'  failed: {f}: {e}')
print(f'Cleanup complete: {removed} backup(s) removed (retention: ${RETENTION_HOURS}h)')
"
