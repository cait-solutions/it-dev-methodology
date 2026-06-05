#!/usr/bin/env bash
#
# v4.63.0-settings-interpreter — перевести hooks в settings.json с хардкода
# интерпретатора (python3/py/python .claude/hooks/X.py) на interpreter-agnostic
# wrapper (sh .claude/hooks/run-hook.sh X.py). (closes G-081)
#
# WHY: settings.json синкается режимом add-if-missing — sync-methodology.sh
# НЕ перезаписывает уже существующий файл консьюмера. Поэтому консьюмеры со
# старым "python3 .claude/hooks/..." застряли навсегда: на Windows (только `py`)
# ВСЕ хуки падают молча — auto-update, sync-audit, security (protect/bash_protect).
# Format-migration — единственный путь починить existing консьюмеров.
#
# MODE=auto: детерминированная idempotent замена строки. Ответ единственный.

MIGRATION_TARGET_VERSION="v4.63.0"
MIGRATION_ID="settings-interpreter-wrapper"
MIGRATION_MODE="auto"

migration_describe() {
  echo "settings.json: хуки 'python3|py|python .claude/hooks/X.py' → 'sh .claude/hooks/run-hook.sh X.py' (cross-platform резолвер)."
}

# NEEDED если settings.json вызывает любой hook напрямую через интерпретатор.
# Pure read. Returns 0 = needed, 1 = clean.
migration_detect() {
  local root="$1"
  local settings="$root/.claude/settings.json"
  [ -f "$settings" ] || return 1
  grep -qE '"command": "(python3|py|python) \.claude/hooks/[A-Za-z0-9_-]+\.py' "$settings" 2>/dev/null
}

# Idempotent transform: заменить прямой вызов на run-hook.sh wrapper.
# Также гарантирует что run-hook.sh присутствует (sync должен был его положить).
migration_apply() {
  local root="$1"
  local settings="$root/.claude/settings.json"
  [ -f "$settings" ] || return 1

  # run-hook.sh обязан существовать (его кладёт sync-methodology.sh).
  # Если нет — миграция не может гарантировать рабочий результат → fail (не молча).
  if [ ! -f "$root/.claude/hooks/run-hook.sh" ]; then
    echo "    ! run-hook.sh отсутствует в .claude/hooks/ — запусти sync-methodology.sh сначала" >&2
    return 1
  fi

  # Замена через временный файл (Bash 3.2 / Git-Bash safe, без sed -i переносимости).
  local tmp
  tmp="$(mktemp)" || return 1
  # sed: "<interp> .claude/hooks/<name>.py" → "sh .claude/hooks/run-hook.sh <name>.py"
  # Захватываем имя файла группой \1, интерпретатор отбрасываем.
  sed -E 's#"command": "(python3|py|python) \.claude/hooks/([A-Za-z0-9_-]+\.py)#"command": "sh .claude/hooks/run-hook.sh \2#g' \
    "$settings" > "$tmp" || { rm -f "$tmp"; return 1; }

  # Verify: результат всё ещё валидный JSON (резолвер интерпретатора как в sync).
  local _py=""
  for _cmd in python3 py python; do
    command -v "$_cmd" >/dev/null 2>&1 && _py="$_cmd" && break
  done
  if [ -n "$_py" ]; then
    if ! "$_py" -c "import json,sys; json.load(open(sys.argv[1], encoding='utf-8-sig'))" "$tmp" 2>/dev/null; then
      echo "    ! результат миграции — невалидный JSON, откат" >&2
      rm -f "$tmp"
      return 1
    fi
  fi

  mv "$tmp" "$settings" || { rm -f "$tmp"; return 1; }
  return 0
}
