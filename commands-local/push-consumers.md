# /push-consumers — Доставка обновлений методологии консьюмерам (drift visibility + batch sync)

> **LOCAL-ONLY command — NEVER syncs to consumer projects.**
> Lives in `commands-local/` (excluded from `sync-methodology.sh` glob).
> Цель: владелец видит drift всех консьюмеров и одной командой доставляет обновления.
>
> ⛔ **НИКОГДА** не делает `git add`, `git commit`, `git push` в консьюмерах — только записывает файлы через `sync-methodology.sh`. Коммит в консьюмерах делает владелец самостоятельно.

---

## Рекомендуемая модель

**Default tier** — читаем версии, вызываем sync-methodology.sh, собираем отчёт.
**Fast tier** если ≤2 консьюмера.
Pre-flight model check: спросить только если Capable (Opus) активен — не нужен.

---

## Шаг 1 — Discovery консьюмеров

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

Показать итоговую таблицу (из Шага 2 + dirty-статусы из Шага 3):

```
Drift-таблица (methodology v5.41.0):

| Репо | ver | Δ | Статус |
|---|---|---|---|
| erp-documentantion | v4.47.5 | +94 | [drift] → обновить |
| it-dev-documentation | v4.45.0 | +96 | [drift] → обновить |
| ai-assistant | v4.10.6 | +131 | [drift] → обновить |
| ebay-template | v4.60.0 | +81 | [drift] → обновить |
| lead-gen | — | — | [not-initialized] → skip |

Будет обновлено: 4 | Пропущено: 1 (not-initialized)

Продолжить синк для 4 консьюмеров? (y/n/список через запятую для выборочного)
```

- **y** → все со статусом [drift] (кроме dirty и not-initialized)
- **n** → выход, ничего не делать
- **«1,3»** → только указанные номера строк

---

## Шаг 5 — Батч синк

Для каждого согласованного консьюмера:

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

- Fail одного консьюмера → продолжить остальных (не abort батча)
- Собирать результаты для финального отчёта

---

## Шаг 6 — Финальный отчёт

```
=== /push-consumers результаты ===

✅ erp-documentantion:     v4.47.5 → v5.41.0  (sync успешен)
✅ it-dev-documentation:   v4.45.0 → v5.41.0  (sync успешен)
✅ ai-assistant:            v4.10.6 → v5.41.0  (sync успешен)
✅ ebay-template:           v4.60.0 → v5.41.0  (sync успешен)
⏭ lead-gen:                не инициализирован — пропущен

Готово: 4/4 синков успешны.

⚠️ Коммит в консьюмерах — твоё действие:
   git -C <consumer-path> status   (что изменилось)
   git -C <consumer-path> diff     (детали)
   git -C <consumer-path> commit .claude/ -m "sync methodology v5.41.0"
   ... для каждого консьюмера
```

---

## Когда запускать

- **После каждого релиза** методологии (рекомендация в `/deploy` финале)
- **Перед `/retro`** — убедиться что консьюмеры на свежей версии
- ❌ НЕ запускать автоматически — manual trigger only (решение владельца)
