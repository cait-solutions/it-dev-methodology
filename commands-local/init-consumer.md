# /init-consumer — Initialize [no-marker] consumer repos

> **LOCAL-ONLY command — NEVER syncs to consumer projects.**
> Lives in `commands-local/` (excluded from `sync-methodology.sh` glob `commands/*.md`).
> Цель: инициализировать репо из workspace которые не имеют `.claude/.version` ([no-marker])
> через `scripts/new-project-init.sh` — одной командой, с per-repo решением владельца.
>
> Заменяет: ручной `bash scripts/new-project-init.sh <path>` из Troubleshooting `/pull-consumers`.
> Закрывает: command-first violation (consmer init без команды-обёртки = gap для AI engineer).

---

## Рекомендуемая модель

**Fast tier (Haiku)** — discovery + per-repo вопросы + вызов init-скрипта. Никакого reasoning.
**Upgrade не нужен.** Pre-flight model check: если на Capable (Opus) — рекомендовать downgrade.
**LOCAL-ONLY:** не синхронизируется консьюмерам.

---

## Когда запускать

- После `/pull-consumers` который показал `[no-marker]` repos в Summary
- При добавлении нового репо в `.code-workspace` без методологии
- Явно владельцем — когда нужно добавить gap-tracking к существующему репо

---

## Шаг 0 — Discovery [no-marker] repos

Переиспользовать discovery из `/pull-consumers` Подшаг 0.1–0.3 без дублирования:

1. Читать `CLAUDE.local.md` секцию `## Consumers` → `consumers_root`, `marker_file`, `workspace_file`, `exclude_paths`
2. Запустить discovery (Режим A: workspace file, Режим B: sibling scan — аналогично `/pull-consumers` Подшаг 0.2-0.3)
3. Отфильтровать только `[no-marker]` repos (нет `<path>/<marker_file>`)
4. Применить `exclude_paths`: если resolved_path присутствует в `exclude_paths` → пропустить (без вывода)
5. Если `[no-marker]` список пуст → вывести «✅ Все репо в workspace уже инициализированы» и завершить

Вывод:
```
Найдено [no-marker] repos (методология не инициализирована):
  ⚪ legal-ai-assistant-documentation   /abs/path/to/repo  [no-marker]
  ⚪ social-promo-documentation         /abs/path/to/repo  [no-marker]
  ⚪ ebay-template-documentation        /abs/path/to/repo  [no-marker]
  ⚪ lead-gen-documentation             /abs/path/to/repo  [no-marker]
```

---

## Шаг 1 — Per-repo решение владельца

Для каждого `[no-marker]` репо — **по очереди** (не батч), спросить владельца:

```
Репо: <repo-name> (<abs-path>)
<если в <path>/.claude/ уже есть файлы — показать: «⚠️ .claude/ содержит файлы: <list>. init перезапишет .claude/commands/, .claude/hooks/, .claude/skills/»>
Действие? [init / skip / never]
  init  — инициализировать сейчас
  skip  — пропустить этот раз (спросит снова в следующем запуске)
  never — добавить в exclude_paths (больше не предлагать)
```

> **⚠️ init не делает git commit.** После init репо станет dirty (файлы созданы, не закоммичены).
> `/pull-consumers` будет SKIP этот репо пока владелец сам не закоммитит.
> Это ожидаемо — commit решает владелец.

- `init` → Шаг 2 для этого репо
- `skip` → продолжить к следующему
- `never` → записать в `exclude_paths` (Шаг 3), продолжить

---

## Шаг 2 — Вызов new-project-init.sh

> **⚠️ Изменяем файлы в consumer repo — READ-ONLY правило: запись разрешена через /init-consumer после per-repo owner approval (Шаг 1); git commit — пользователь.** Это исключение зафиксировано в `CLAUDE.local.md ## Consumer repos — READ ONLY`.

```bash
# Определить project-name из имени директории (последний компонент пути)
project_name=$(basename "<abs_path>")

# Вызвать скрипт (idempotent — existing files preserved, только .claude/commands/ перезапишется sync'ом)
bash scripts/new-project-init.sh "$project_name" "<abs_path>"
```

После завершения:
```
✅ <repo-name>: инициализирован (new-project-init.sh).
   Создано: .claude/.version, commands/, hooks/, templates/...
   ⚠️  Репо dirty — закоммить в <repo-name>: git add .claude && git commit -m "feat: init methodology v<version>"
   ℹ️  /pull-consumers будет SKIP этот репо до коммита (pre-flight dirty check).
```

---

## Шаг 3 — Запись exclude_paths

Если владелец выбрал `never` для одного или нескольких репо:

1. Читать `CLAUDE.local.md` секцию `## Consumers`
2. Найти или создать поле `exclude_paths` (список путей):
   ```yaml
   ## Consumers
   consumers_root: ..
   marker_file: .claude/.version
   workspace_file: ../It dev methodology.code-workspace
   exclude_paths:
     - /abs/path/to/repo1
     - /abs/path/to/repo2
   ```
3. Дописать новые пути (append, не перетирать существующие)
4. Вывести: «📌 Добавлено в exclude_paths: <repo-name>. /pull-consumers и /init-consumer больше не будут предлагать этот репо.»

> **Известное ограничение:** `CLAUDE.local.md` не коммитится (`.gitignore`). При переустановке машины exclude-решения теряются — принятый риск для single-owner, задокументированный в плане.

---

## Шаг 4 — Финальный Summary

```
✅ /init-consumer done.
   Инициализировано: 2 (legal-ai-assistant-documentation, social-promo-documentation)
   Пропущено (skip): 1 (lead-gen-documentation)
   В exclude_paths (never): 1 (ebay-template-documentation)

Следующие шаги:
   • Для инициализированных репо: закоммить через git в каждом репо
   • После коммита: /pull-consumers увидит их как [marker]
   • Повторный запуск /init-consumer: покажет только skip-репо (never отфильтрованы)
```

---

## Что эта команда НЕ делает

- ❌ НЕ делает `git commit`, `git push` в consumer repos (коммитит пользователь)
- ❌ НЕ синхронизируется консьюмерам (commands-local)
- ❌ НЕ инициализирует несколько репо без per-repo подтверждения
- ❌ НЕ удаляет существующий `.claude/` контент (идемпотентно — только `.claude/commands/` перезапишет sync при следующем `sync-methodology.sh`)
- ❌ НЕ клонирует репо (репо уже должно быть в workspace)

---

## Configuration в CLAUDE.local.md

```yaml
## Consumers
consumers_root: ..
marker_file: .claude/.version
workspace_file: ../It dev methodology.code-workspace
exclude_paths:           # ← /init-consumer пишет сюда при "never"
  - /abs/path/to/repo   # абсолютные пути (resolve при записи)
```

`exclude_paths` читается также `/pull-consumers` Шаг 0 — репо в этом списке пропускается без упоминания в Summary.
