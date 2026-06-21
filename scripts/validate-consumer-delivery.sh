#!/usr/bin/env bash
# validate-consumer-delivery.sh — orphan-in-delivery detector (consumer-delivery-hygiene).
#
# WHY: templates/scripts/* синкается консьюмерам ЦЕЛИКОМ. Скрипт без consumer-facing
# ссылки (commands/*.md, templates/.claude/hooks/*, другой templates/scripts/*) =
# maintainer-only рудимент, протёкший в delivery (класс: clone-consumer.sh, sync-doctor.sh).
# Канон проверки: REFERENCE-based (robust). НЕ content-signature — signature-grep даёт
# false-positives на легит commands (plan.md/pull.md/secrets.md) → dead rule (Ось 1).
#
# SCOPE: ТОЛЬКО templates/scripts/. Closedness команд/skills держится author-time в
# /plan Шаг -1.3 (классификация при создании), НЕ шумным deploy-grep здесь (opinion-trim).
#
# Allow-marker: скрипт с `# delivery-allow: <reason>` в первых 15 строках — легитимный
# ручной tool без command-entry → НЕ флагуется (e.g. secrets-cleanup-backups.sh).
#
# Severity: CONSUMER_DELIVERY_SEVERITY=warn (default, exit 0) | error (exit 1 на orphan).
# Guard: methodology-platform only (<root>/commands + <root>/templates/scripts). Иначе exit 2 SKIP.
#
# Usage: bash scripts/validate-consumer-delivery.sh [--root DIR]
# Exit 0 = clean / warn-only; Exit 1 = orphan + severity=error; Exit 2 = SKIP (не methodology-platform).
# Bash 3.2+ / Git-Bash (Windows) safe — no associative arrays, no ${var,,}.

set -u

ROOT="."
case "${1:-}" in
  --root)   ROOT="${2:-.}" ;;
  --root=*) ROOT="${1#--root=}" ;;
esac

SEVERITY="${CONSUMER_DELIVERY_SEVERITY:-warn}"

TPL_SCRIPTS="$ROOT/templates/scripts"
if [ ! -d "$ROOT/commands" ] || [ ! -d "$TPL_SCRIPTS" ]; then
  echo "INFO: not methodology-platform (no commands/ + templates/scripts/) — consumer-delivery check N/A."
  exit 2
fi

ORPHANS=0
CHECKED=0

for f in "$TPL_SCRIPTS"/*.sh "$TPL_SCRIPTS"/*.py; do
  [ -f "$f" ] || continue
  name="$(basename "$f")"

  # allow-marker → легит ручной tool без command-entry, пропустить.
  if head -15 "$f" 2>/dev/null | grep -q "delivery-allow:"; then
    continue
  fi

  CHECKED=$((CHECKED+1))
  refs=0

  # consumer-facing surface #1 — commands/*.md
  grep -rlF "$name" "$ROOT/commands" >/dev/null 2>&1 && refs=1

  # consumer-facing surface #2 — synced hooks
  if [ "$refs" -eq 0 ] && [ -d "$ROOT/templates/.claude/hooks" ]; then
    grep -rlF "$name" "$ROOT/templates/.claude/hooks" >/dev/null 2>&1 && refs=1
  fi

  # consumer-facing surface #3 — другой синкаемый скрипт (исключая себя)
  if [ "$refs" -eq 0 ]; then
    if grep -rlF "$name" "$TPL_SCRIPTS" 2>/dev/null | grep -v "/$name$" | grep -q .; then
      refs=1
    fi
  fi

  if [ "$refs" -eq 0 ]; then
    ORPHANS=$((ORPHANS+1))
    echo "[WARN] consumer-delivery: $name — orphan в templates/scripts/ (нет ссылки в commands/ / hooks/ / др. скрипте)."
    echo "       maintainer-only? → перенеси в scripts/-only (как clone-consumer/sync-doctor)."
    echo "       легит ручной tool? → добавь '# delivery-allow: <причина>' в шапку."
  fi
done

if [ "$ORPHANS" -eq 0 ]; then
  echo "INFO: consumer-delivery — $CHECKED скриптов проверено, 0 orphan."
  exit 0
fi

echo "consumer-delivery: $ORPHANS orphan(s) из $CHECKED проверенных (severity=$SEVERITY)."
if [ "$SEVERITY" = "error" ]; then
  echo "  CONSUMER_DELIVERY_SEVERITY=error → блок. Перенеси orphan в scripts/-only или пометь delivery-allow."
  exit 1
fi
echo "  (warn-режим — не блок. CONSUMER_DELIVERY_SEVERITY=error для жёсткого гейта.)"
exit 0
