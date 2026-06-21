#!/usr/bin/env bash
#
# v7.6.0-remove-consumer-delivery-rudiments — снять рудименты clone-consumer.sh +
# sync-doctor.sh из consumer scripts/ (consumer-delivery-hygiene).
#
# WHY: оба скрипта исторически лежали в templates/scripts/ → sync-methodology.sh
# копировал их в каждый consumer scripts/. Но это maintainer-only операции:
#   - clone-consumer.sh клонит consumer-репы из workspace методолога (у консьюмера
#     нет consumers/<name>.yaml);
#   - sync-doctor.sh зовётся только commands-local/ (push-consumers, sync-audit) —
#     ни одна consumer-facing команда его не вызывает.
# v7.6.0 снял их из templates/scripts/ (delivery) → новые консьюмеры их не получат.
# Но sync НЕ удаляет removed-upstream скрипты (в отличие от commands) → stale-копии
# заморожены в уже-инициализированных консьюмерах. Эта миграция их вычищает.
#
# MODE=auto: idempotent. detect → нужен если хоть один рудимент в scripts/. apply →
# git rm --ignore-unmatch (fallback rm -f). Повторный прогон → файлов нет → SKIP.
#
# ⛔ GUARD methodology-platform: на самой методологии scripts/clone-consumer.sh +
# scripts/sync-doctor.sh — это КАНОН (maintainer-internal), НЕ рудимент. detect
# возвращает «не нужно» если есть templates/scripts/ ИЛИ commands/ (признак канон-репо).
#
# Класс: removed-upstream-script drift (sync не удаляет скрипты, только commands).

MIGRATION_TARGET_VERSION="v7.6.0"
MIGRATION_ID="remove-consumer-delivery-rudiments"
MIGRATION_MODE="auto"

migration_describe() {
  echo "scripts/: снять clone-consumer.sh + sync-doctor.sh — maintainer-only, сняты из delivery (consumer-delivery-hygiene v7.6.0). Удаление застейджено; закоммить штатным flow."
}

# NEEDED если consumer И хоть один рудимент лежит в scripts/.
# Pure read. Returns 0 = needed, 1 = clean / methodology-platform / нет файлов.
migration_detect() {
  local root="$1"
  # GUARD: methodology-platform = канон-дом этих скриптов, НЕ трогать.
  [ -d "$root/templates/scripts" ] && return 1
  [ -d "$root/commands" ] && return 1
  [ -f "$root/scripts/clone-consumer.sh" ] && return 0
  [ -f "$root/scripts/sync-doctor.sh" ] && return 0
  return 1
}

# idempotent: удалить оба рудимента если присутствуют. git rm стейджит удаление
# (consumer/owner коммитит штатным flow / push-consumers sweep); fallback rm -f
# если не git-репо. --ignore-unmatch → no-op для отсутствующего файла.
migration_apply() {
  local root="$1"
  local f p
  for f in clone-consumer.sh sync-doctor.sh; do
    p="$root/scripts/$f"
    [ -f "$p" ] || continue
    if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
      git -C "$root" rm -q --ignore-unmatch "scripts/$f" >/dev/null 2>&1 || rm -f "$p"
    else
      rm -f "$p"
    fi
  done
  return 0
}
