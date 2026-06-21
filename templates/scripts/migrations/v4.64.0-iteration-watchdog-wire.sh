#!/usr/bin/env bash
#
# v4.64.0-iteration-watchdog-wire — добавить iteration-watchdog.py в PostToolUse
# хуки settings.json существующих консьюмеров. (closes G-082 — consumer side)
#
# WHY: settings.json синкается add-if-missing → новый hook-entry в PostToolUse
# НЕ добавляется автоматически у консьюмеров где файл уже существует. Migration —
# единственный путь дотянуть L4 iteration-watchdog до existing проектов.
#
# MODE=auto: добавляет ровно одну строку рядом с post-edit-watchdog, idempotent.

MIGRATION_TARGET_VERSION="v4.64.0"
MIGRATION_ID="iteration-watchdog-wire"
MIGRATION_MODE="auto"

migration_describe() {
  echo "settings.json: добавить iteration-watchdog.py в PostToolUse (L4 reasoning-escalation, G-082)."
}

# NEEDED если post-edit-watchdog есть в settings, а iteration-watchdog ещё нет.
migration_detect() {
  local root="$1"
  local settings="$root/.claude/settings.json"
  [ -f "$settings" ] || return 1
  grep -q 'post-edit-watchdog\.py' "$settings" 2>/dev/null || return 1
  # needed только если iteration-watchdog ещё НЕ упомянут
  ! grep -q 'iteration-watchdog\.py' "$settings" 2>/dev/null
}

# Idempotent: вставить строку iteration-watchdog после строки post-edit-watchdog.
migration_apply() {
  local root="$1"
  local settings="$root/.claude/settings.json"
  [ -f "$settings" ] || return 1

  # hook-файл обязан присутствовать (кладёт sync-methodology.sh)
  if [ ! -f "$root/.claude/hooks/iteration-watchdog.py" ]; then
    echo "    ! iteration-watchdog.py отсутствует — запусти sync-methodology.sh сначала" >&2
    return 1
  fi

  # Уже есть → no-op (idempotent guard, на случай повторного вызова)
  if grep -q 'iteration-watchdog\.py' "$settings" 2>/dev/null; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)" || return 1
  # Найти строку с post-edit-watchdog, добавить запятую в конец её JSON-объекта
  # и вставить следующей строкой iteration-watchdog (сохраняя отступ).
  # awk: при матче строки post-edit-watchdog — печатаем её с добавленной запятой
  # (если её ещё нет) + новую строку с тем же отступом.
  awk '
    /post-edit-watchdog\.py/ {
      line = $0
      # отступ = leading whitespace
      match(line, /^[ \t]*/)
      indent = substr(line, 1, RLENGTH)
      # убрать возможную trailing запятую, потом добавить ровно одну
      sub(/,[ \t]*$/, "", line)
      print line ","
      print indent "{ \"type\": \"command\", \"command\": \"sh .claude/hooks/run-hook.sh iteration-watchdog.py\" }"
      next
    }
    { print }
  ' "$settings" > "$tmp" || { rm -f "$tmp"; return 1; }

  # Verify валидный JSON
  local _py=""
  for _cmd in python3 py python; do
    command -v "$_cmd" >/dev/null 2>&1 && _py="$_cmd" && break
  done
  if [ -n "$_py" ]; then
    if ! "$_py" -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8-sig'))" "$tmp" 2>/dev/null; then
      echo "    ! результат — невалидный JSON, откат" >&2
      rm -f "$tmp"
      return 1
    fi
  fi

  mv "$tmp" "$settings" || { rm -f "$tmp"; return 1; }
  return 0
}

# Declare touched path for the runner's commit manifest (v7.8.0 a17ecc1-safe bridge):
# sync run_migrations() парсит MIGRATED:<path> → _track_changed → _auto_commit_sync коммитит
# explicit pathspec. settings.json — methodology-delivered infra (MERGE), безопасно авто-коммитить.
migration_changed_paths() {
  echo ".claude/settings.json"
}
