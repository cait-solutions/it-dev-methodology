#!/usr/bin/env bash
#
# v7.8.2-uningore-derived-layer — снять .claude/commands/ + hooks/ + model-tiers.md
# из consumer .gitignore, чтобы свежий `git clone` consumer-репо имел рабочие команды/хуки
# БЕЗ ручного sync-шага (self-contained clone).
#
# WHY: исторически (v3.3.0, коммит 68e9e00 "gitignore synced artifacts") весь
# derived-слой был заигнорен под доктриной single-source. Но это склеило два разных
# класса: (а) runtime-local (.claude/state/, .version — машинно-специфичны, корректно
# ignored) и (б) derived-но-функциональное (commands/hooks/model-tiers — без них клон
# мёртв: нет slash-команд, settings.json ссылается на отсутствующие хуки). Класс (б)
# должен коммититься (как уже коммитятся agents/ и settings.json — тоже synced). v7.8.2
# убрал класс (б) из templates/.gitignore.template → новые консьюмеры получают команды
# на remote. Но sync НЕ перезаписывает consumer .gitignore (project-owned) → уже
# инициализированные консьюмеры заморожены на старом ignore. Эта миграция их расклеивает.
#
# MODE=auto: idempotent. detect → нужен если в consumer .gitignore есть строка
# ".claude/commands/". apply → grep -vxF убирает три точные строки. Повторный прогон →
# строк нет → SKIP. Команды/хуки коммитятся на следующем штатном sync (manifest их
# впустит, фильтр line 1109 больше не отбрасывает) — eventual-consistency, self-healing.
#
# ⛔ GUARD methodology-platform: на самой методологии .claude/commands/ остаётся ignored
# КАНОНИЧЕСКИ (self-apply churns SYNCED_AT date + VERSION в banner на каждом deploy
# без commit → dirty-tree). detect возвращает «не нужно» если templates/scripts/ ИЛИ
# commands/ присутствуют (признак канон-репо).
#
# Класс: gitignore-blanket-over-derived (свежий клон без команд → ручной sync).

MIGRATION_TARGET_VERSION="v7.8.2"
MIGRATION_ID="uningore-derived-layer"
MIGRATION_MODE="auto"

migration_describe() {
  echo ".gitignore: снять .claude/commands/ + hooks/ + model-tiers.md из ignore — свежий клон получает рабочие команды без ручного sync (self-contained clone v7.8.2). Изменение .gitignore застейджено; команды коммитятся на следующем sync."
}

# NEEDED если consumer И .gitignore всё ещё игнорит derived-слой.
# Pure read. Returns 0 = needed, 1 = clean / methodology-platform / нет .gitignore.
migration_detect() {
  local root="$1"
  # GUARD: methodology-platform = канон-дом, .claude/commands/ ignored намеренно.
  [ -d "$root/templates/scripts" ] && return 1
  [ -d "$root/commands" ] && return 1
  [ -f "$root/.gitignore" ] || return 1
  grep -qxF '.claude/commands/' "$root/.gitignore" 2>/dev/null && return 0
  return 1
}

# idempotent: убрать три точные строки из .gitignore. grep -vxF (-x = whole-line,
# -F = fixed-string) — не заденет .env / secret-строки, только точные совпадения.
# || true: grep возвращает 1 когда ВСЕ строки совпали с паттерном (пустой вывод) —
# под set -u это не должно ронять функцию.
migration_apply() {
  local root="$1"
  local gi="$root/.gitignore"
  [ -f "$gi" ] || return 0
  local tmp="$gi.migtmp.$$"
  local pat
  cp "$gi" "$tmp" || return 0
  for pat in '.claude/commands/' '.claude/hooks/' '.claude/model-tiers.md'; do
    grep -vxF "$pat" "$tmp" > "$tmp.next" 2>/dev/null || true
    mv -f "$tmp.next" "$tmp" 2>/dev/null || true
  done
  mv -f "$tmp" "$gi" 2>/dev/null || true
  return 0
}

# Declare touched path for the runner's commit manifest (a17ecc1-safe explicit pathspec).
# sync-methodology.sh run_migrations() парсит MIGRATED:<path> → _track_changed →
# _auto_commit_sync коммитит .gitignore. Команды/хуки попадут в manifest на следующем
# sync (они уже не gitignored → проходят фильтр).
migration_changed_paths() {
  echo ".gitignore"
}
