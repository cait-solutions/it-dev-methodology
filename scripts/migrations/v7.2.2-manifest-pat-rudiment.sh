#!/usr/bin/env bash
#
# v7.2.2-manifest-pat-rudiment — обнаружить рудиментарную запись GITHUB_PAT
# с required:true в consumer .claude/secrets-manifest.yaml.
#
# NB: имя файла НЕ содержит "secret" намеренно — protect.py (PreToolUse) блокирует
# Edit/Write по пути матчащему /secret/. Контекст (manifest + GITHUB_PAT) однозначен.
# MIGRATION_ID и содержимое описывают secrets-manifest полностью.
#
# WHY: secrets-manifest.yaml создаётся ОДИН РАЗ при init из шаблона, затем
# consumer-owned (PRESERVE — sync-methodology.sh его НЕ перезаписывает). Старый
# шаблон поставлял активную запись GITHUB_PAT с required:true; в v6.x шаблон
# вычищен (P-005: GITHUB_PAT закомментирован, required:false). Но фикс шаблона
# НЕ доезжает до уже инициализированных консьюмеров — рудимент заморожен в их
# копиях. Следствие: `/secrets --audit` / validate-secrets.sh вечно репортят
# "1 required secret missing", хотя push не требует PAT (G-083: gh credential
# helper для GitHub, токен для GitLab). Косметический false-positive, но
# эрозирует доверие к secrets-аудиту.
#
# MODE=report: НЕ auto. secrets-manifest — самый чувствительный PRESERVE-артефакт
# (декларация секретов пользователя), авто-правка запрещена. Плюс ответ не
# единственный: проект, реально использующий PAT-в-credential-helper, мог бы
# легитимно держать запись. Поэтому detect-and-report — решение за владельцем.
#
# Класс: init-once artifact drift (Ось 1 config-drift). Сиблинг: Gap 11
# (CLAUDE.local.md config-recommendations) — тот же класс на другом артефакте.

MIGRATION_TARGET_VERSION="v7.2.2"
MIGRATION_ID="secrets-manifest-pat-rudiment"
MIGRATION_MODE="report"

migration_describe() {
  echo "secrets-manifest.yaml: рудиментарный GITHUB_PAT required:true — push идёт через gh credential helper / GitLab токен (G-083), PAT не нужен. Убери запись или поставь required:false (шаблон уже чист, P-005). Файл consumer-owned — правь сам, затем закоммить."
}

# NEEDED если в манифесте есть АКТИВНАЯ (раскомментированная) запись
# `- key: GITHUB_PAT`, чей блок содержит `required: true`.
# Pure read. Returns 0 = needed (рудимент найден), 1 = clean / нет файла.
migration_detect() {
  local root="$1"
  local manifest="$root/.claude/secrets-manifest.yaml"
  [ -f "$manifest" ] || return 1

  awk '
    # Пропустить строки-комментарии (любой отступ + #).
    /^[[:space:]]*#/ { next }
    # Начало записи списка секретов: "  - key: <NAME>".
    /^[[:space:]]*-[[:space:]]+key:/ {
      inblock = ($0 ~ /key:[[:space:]]*GITHUB_PAT[[:space:]]*$/) ? 1 : 0
      next
    }
    # Внутри блока GITHUB_PAT встретили required: true → рудимент.
    inblock && /^[[:space:]]*required:[[:space:]]*true[[:space:]]*$/ { found = 1 }
    END { exit (found ? 0 : 1) }
  ' "$manifest" 2>/dev/null
}

# report-mode: runner НЕ вызывает apply (только describe + detect). Определён
# для соответствия контракту _runner.sh; no-op idempotent.
migration_apply() {
  return 0
}
