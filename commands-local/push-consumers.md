# /push-consumers — Доставка обновлений методологии консьюмерам (drift visibility + batch sync + optional auto-commit-push)

> **LOCAL-ONLY command — NEVER syncs to consumer projects.**
> Lives in `commands-local/` (excluded from `sync-methodology.sh` glob).
> Цель: владелец видит drift всех консьюмеров и одной командой доставляет обновления.
>
> **Default (без флага):** только sync файлов (write-only). Коммит делает владелец самостоятельно.
>
> **С флагом `--commit-push`:** после успешного sync — автоматический `git commit` (только manifest-пути из `--print-changed`) + `git push` в каждом whitelisted консьюмере. Только репо из `auto_commit_consumers` в `CLAUDE.local.md`. Commit scope = точный список файлов записанных sync'ом — гарантия отсутствия pathspec-overcapture (класс a17ecc1).

---

## Рекомендуемая модель

**Default tier** — читаем версии, вызываем sync-methodology.sh, собираем отчёт.
**Fast tier** если ≤2 консьюмера и без `--commit-push`.
Pre-flight model check: спросить только если Capable (Opus) активен — не нужен.

---

## Флаги

| Флаг | Поведение |
|---|---|
| *(без флага)* | Только sync файлов. Коммит и push — ручные. |
| `--commit-push` | Sync + авто-commit (manifest-scope) + авто-push (reuse deploy-push харнесс). Только whitelisted репо. |

---

## Шаг 1 — Инициализация (флаги + whitelist)

**Флаг `--commit-push`:** зафиксировать в памяти сессии — `COMMIT_PUSH=true`.

**Whitelist (только при `--commit-push`):** прочитать `CLAUDE.local.md ## auto_commit_consumers` → список `path`+`branch`. Это **policy gate** — commit+push разрешён ТОЛЬКО для путей в этом списке. Вне списка → только sync. Если секция отсутствует → 🔴 СТОП: «`auto_commit_consumers` не настроен в CLAUDE.local.md — добавь whitelist перед запуском с `--commit-push`».

---

## Шаг 2 — Discovery консьюмеров

Читать `CLAUDE.local.md ## Consumers` → `workspace_file`. Использовать тот же двухрежимный discovery что `/pull-consumers`:

**Режим A (приоритет) — workspace file:**
Читать `workspace_file` из CLAUDE.local.md. Извлечь все `folders[].path`, резолвить относительно папки workspace-файла.

**Режим B (fallback) — sibling scan:**
Если `workspace_file` не найден → сканировать `consumers_root/*/`, проверять `marker_file` (`.claude/.version`).

---

## Шаг 2 — Drift-таблица

Для каждого обнаруженного репо:

1. Читать `.claude/.version` (если существует):
   - `methodology:` → consumer version
   - `synced_at:` → дата синка
2. Читать текущую `VERSION` methodology repo
3. Вычислить Δ минорных версий
4. Присвоить статус:
   - `[ok]` — Δ ≤ 1 minor
   - `[drift]` — `.claude/.version` есть, Δ > 1 minor
   - `[no-marker]` — репо есть в workspace, `.claude/.version` отсутствует
   - `[not-initialized]` — нет `.claude/` вообще
   - `[skip: dirty]` — см. Шаг 3

**Пример drift-таблицы:**

| Репо | Consumer ver | Synced | Δ | Статус |
|---|---|---|---|---|
| erp-documentantion | v4.47.5 | 2026-06-01 | +94 minor | [drift] |
| it-dev-methodology-documentation | v4.45.0 | 2026-06-01 | +96 minor | [drift] |
| ai-assistant-documentation | v4.10.6 | 2026-05-27 | +131 minor | [drift] |
| ebay-template-documentation | v4.60.0 | 2026-06-04 | +81 minor | [drift] |
| lead-gen-documentation | — | — | — | [not-initialized] |

---

## Шаг 3 — Pre-check (parallel-session safety)

Для каждого консьюмера со статусом `[drift]`:

```bash
git -C <consumer-path> status --short -- .claude/ 2>/dev/null
```

- Вывод непустой → пометить `[skip: dirty]` + причина. **НЕ синкать** — dirty `.claude/` = in-progress работа параллельной сессии.
- Вывод пустой → добавить в список «будет обновлено».

`[not-initialized]` — sync НЕ применять. Init = решение владельца через `new-project-init.sh`. Показать в таблице, но в батч не включать.

---

## Шаг 4 — Одно подтверждение на весь батч

Показать итоговую таблицу. При `--commit-push` — добавить колонку `Commit+Push`:

```
Drift-таблица (methodology vX.Y.Z):

| Репо | ver | Δ | Статус | Commit+Push |
|---|---|---|---|---|
| erp-documentantion | v4.47.5 | +94 | [drift] → обновить | ✅ whitelisted |
| it-dev-documentation | v4.45.0 | +96 | [drift] → обновить | ✅ whitelisted |
| some-other | v5.0.0 | +3 | [drift] → обновить | ⚠️ не в whitelist — только sync |
| lead-gen | — | — | [not-initialized] → skip | — |

Будет обновлено: 3 | Пропущено: 1 (not-initialized)
Будет сделан commit+push: 2 (whitelisted) | Только sync: 1 (not in whitelist)

Продолжить? (y/n/список через запятую для выборочного)
```

- **y** → все со статусом [drift] (кроме dirty и not-initialized)
- **n** → выход, ничего не делать
- **«1,3»** → только указанные номера строк

---

## Шаг 5 — Батч синк (+ manifest-commit-push если флаг)

Для каждого согласованного консьюмера — **два режима**:

### Режим A (default — без `--commit-push`)

```bash
echo "→ Синкаю <имя> (was <ver>)..."
bash scripts/sync-methodology.sh <consumer-path>
EXIT=$?
if [ $EXIT -eq 0 ]; then
  NEW_VER=$(grep "methodology:" <consumer-path>/.claude/.version | sed 's/methodology: //')
  echo "  ✅ <имя>: <ver> → $NEW_VER"
else
  echo "  ❌ <имя>: sync failed (exit $EXIT) — проверь вручную"
fi
```

### Режим B (`--commit-push`, только whitelisted репо)

```bash
echo "→ Синкаю <имя> (was <ver>)..."

# 1. Sync с манифестом
MANIFEST=$(bash scripts/sync-methodology.sh <consumer-path> --print-changed 2>&1)
SYNC_EXIT=$?
CHANGED_PATHS=$(echo "$MANIFEST" | grep "^CHANGED:" | sed 's/^CHANGED://' | tr '\n' ' ')

if [ $SYNC_EXIT -ne 0 ]; then
  echo "  ❌ <имя>: sync failed (exit $SYNC_EXIT) — пропуск commit+push"
  continue  # к следующему консьюмеру
fi

NEW_VER=$(grep "methodology:" <consumer-path>/.claude/.version | sed 's/methodology: //')
echo "  ✅ sync: <ver> → $NEW_VER"

# 2. Проверить что CHANGED_PATHS не пустой
if [ -z "$CHANGED_PATHS" ]; then
  echo "  ℹ️  <имя>: манифест пустой — нечего коммитить"
  continue
fi

# 3. Symmetric dirty-check: проверить грязность ТОЛЬКО по manifest-путям
DIRTY=$(git -C <consumer-path> status --short $CHANGED_PATHS 2>/dev/null | grep -v "^$" | head -1)
if [ -n "$DIRTY" ]; then
  echo "  ⚠️  <имя>: dirty manifest-путь (параллельная сессия?) — пропуск commit+push"
  echo "      Грязный путь: $DIRTY"
  continue
fi

# 4. Git commit — ТОЛЬКО manifest-пути (explicit pathspec, не git add .)
MSG="sync methodology $NEW_VER"
if git -C <consumer-path> commit $CHANGED_PATHS -m "$MSG" 2>/dev/null; then
  echo "  ✅ commit: '$MSG'"
else
  echo "  ℹ️  <имя>: нечего коммитить (уже актуально)"
  continue
fi

# 5. Push с gh-account проверкой
REMOTE_URL=$(git -C <consumer-path> remote get-url origin 2>/dev/null || true)
OWNER=""
case "$REMOTE_URL" in
  https://github.com/*)
    OWNER="${REMOTE_URL#https://github.com/}"; OWNER="${OWNER%%/*}"
    ACTIVE=$(gh api user -q .login 2>/dev/null || echo "")
    if [ "$ACTIVE" != "$OWNER" ]; then
      if gh auth status 2>/dev/null | grep -q "account $OWNER "; then
        gh auth switch --user "$OWNER" >/dev/null 2>&1 && \
          echo "  🔄 gh account: $ACTIVE → $OWNER"
      else
        echo "  ⚠️  gh: аккаунт '$OWNER' не залогинен (активен: $ACTIVE)"
        echo "      Push пропущен. Залогинься: gh auth login --user $OWNER"
        continue
      fi
    fi
    ;;
esac

BRANCH=<branch-from-whitelist>  # из auto_commit_consumers для этого репо
PUSH_ERR=$(git -C <consumer-path> push origin HEAD:"$BRANCH" 2>&1)
PUSH_EXIT=$?
if [ $PUSH_EXIT -eq 0 ]; then
  echo "  ✅ push → $BRANCH"
else
  echo "  ❌ push failed (exit $PUSH_EXIT):"
  echo "$PUSH_ERR" | head -5 | sed 's/^/      /'
  # Classify common errors
  if echo "$PUSH_ERR" | grep -qiE '403|permission|denied|forbidden'; then
    echo "  → Проверь gh-аккаунт: gh api user -q .login"
    echo "  → Нужен: gh auth switch --user $OWNER"
  elif echo "$PUSH_ERR" | grep -qiE 'GH006|protected branch'; then
    echo "  → Branch protection: нужен PR. Push-only не разрешён для этого репо."
  elif echo "$PUSH_ERR" | grep -qiE 'network|resolve|timed out'; then
    echo "  → Сеть недоступна. Повтори позже."
  fi
fi
```

**Invariants Режима B:**
- ❌ НИКОГДА не делать `git add` перед commit — только explicit pathspec из манифеста.
- ❌ НИКОГДА не делать push если commit вернул ненулевой exit (нет ничего пушить).
- ❌ НИКОГДА не делать push в репо вне `auto_commit_consumers` whitelist.
- ❌ Fail одного консьюмера → продолжить остальных (не abort батча).

---

## Шаг 6 — Финальный отчёт

```
=== /push-consumers результаты (methodology vX.Y.Z) ===

✅ erp-documentantion:          v4.47.5 → vX.Y.Z  (sync + commit + push ✅)
✅ it-dev-documentation:        v4.45.0 → vX.Y.Z  (sync + commit + push ✅)
✅ ai-assistant:                v4.10.6 → vX.Y.Z  (sync + commit + push ✅)
⚠️ some-other:                  v5.0.0  → vX.Y.Z  (sync ✅, commit+push пропущен — не в whitelist)
⏭ lead-gen:                    не инициализирован — пропущен

Sync: 4/4 ✅  |  Commit+Push: 3/3 whitelisted ✅  |  Пропущено: 1
```

**Если `--commit-push` НЕ передан — старый формат с ручным шагом:**

```
=== /push-consumers результаты ===

✅ erp-documentantion:     v4.47.5 → vX.Y.Z  (sync успешен)
...

⚠️ Коммит — твоё действие (одной командой):
   git -C ../erp-documentantion commit .claude/ docs/adr/_TEMPLATE.md scripts/ -m "sync methodology vX.Y.Z" && \
   git -C ../it-dev-methodology-documentation commit .claude/ docs/adr/_TEMPLATE.md scripts/ -m "sync methodology vX.Y.Z" && \
   ...
   (скопируй всё одним paste — или используй /push-consumers --commit-push для авто)
```

---

## Когда запускать

- **После каждого релиза** методологии (рекомендация в `/deploy` финале)
- **Перед `/retro`** — убедиться что консьюмеры на свежей версии
- **`--commit-push`** — когда хочешь полный zero-step deploy: sync + commit + push для всех whitelisted в одном прогоне
- ❌ НЕ запускать автоматически — manual trigger only (решение владельца)
