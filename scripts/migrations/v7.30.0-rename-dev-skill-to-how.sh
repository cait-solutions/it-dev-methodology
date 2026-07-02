#!/usr/bin/env bash
#
# v7.30.0-rename-dev-skill-to-how — снять orphan skill `dev` после переименования
# skills/dev/ → skills/how/ в методологии (router-skill rename).
#
# WHY: sync_skills() в sync-methodology.sh КОПИРУЕТ skills/* но НЕ удаляет orphans.
# Переименование skills/dev/ → skills/how/ на стороне методологии доставит консьюмеру
# новый .claude/skills/how/ — но старый .claude/skills/dev/ останется навсегда. Оба —
# роутеры «не знаю какую команду звать» → двойная auto-активация, конфликт. Эта
# миграция вычищает orphan .claude/skills/dev/ у уже-инициализированных консьюмеров.
#
# MODE=auto: idempotent. detect → нужен если .claude/skills/dev/ существует. apply →
# git rm -r (fallback rm -rf). Повторный прогон → директории нет → SKIP.
#
# NB: удаляем ТОЛЬКО derived .claude/skills/dev/ (gitignored у консьюмера / self-apply
# у методологии). Канонический источник skills/dev/ уже переименован в git методологии —
# у консьюмера его нет (консьюмер получает только .claude/skills/), так что guard на
# methodology-platform не нужен: и там, и там .claude/skills/dev/ = orphan после rename.
#
# Класс: orphan-skill-after-rename (sync add-only, не prune).

MIGRATION_TARGET_VERSION="v7.30.0"
MIGRATION_ID="rename-dev-skill-to-how"
MIGRATION_MODE="auto"

migration_describe() {
  echo ".claude/skills/: снять orphan dev/ (router-skill переименован dev → how, v7.30.0). Sync доставит how/; старый dev/ = orphan (двойной роутер) → удаляется."
}

# NEEDED если orphan .claude/skills/dev/ присутствует. Pure read.
# Returns 0 = needed, 1 = clean.
migration_detect() {
  local root="$1"
  [ -d "$root/.claude/skills/dev" ] && return 0
  return 1
}

# idempotent: удалить orphan .claude/skills/dev/. git rm -r стейджит удаление
# (у консьюмера .claude/skills/ обычно gitignored → git rm no-op → fallback rm -rf).
migration_apply() {
  local root="$1"
  local d="$root/.claude/skills/dev"
  [ -d "$d" ] || return 0
  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$root" rm -rq --ignore-unmatch "$d" >/dev/null 2>&1 || rm -rf "$d"
    # git rm no-op на gitignored dir → страховкой добить с диска
    [ -d "$d" ] && rm -rf "$d"
  else
    rm -rf "$d"
  fi
  return 0
}
