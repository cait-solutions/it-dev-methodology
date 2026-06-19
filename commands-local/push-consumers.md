# /push-consumers — Доставка обновлений методологии консьюмерам (drift visibility + batch sync + commit-push by default)

> **LOCAL-ONLY command — NEVER syncs to consumer projects.**
> Lives in `commands-local/` (excluded from `sync-methodology.sh` glob).
> Цель: владелец видит drift всех консьюмеров и одной командой доставляет обновления.
>
> **Default (без флага):** sync файлов + автоматический `git commit` (только manifest-пути из `--print-changed`) + `git push` в каждом whitelisted консьюмере. Только репо из `auto_commit_consumers` в `CLAUDE.local.md`. Репо вне whitelist получают только sync (commit невозможен by-construction). Commit scope = точный список файлов записанных sync'ом — гарантия отсутствия pathspec-overcapture (класс a17ecc1).
>
> **С флагом `--sync-only`:** только sync файлов (write-only). Коммит делает владелец самостоятельно. Escape-hatch для случая «хочу просто доставить файлы без коммита».

---

## Рекомендуемая модель

**Default tier** — читаем версии, вызываем sync-methodology.sh, собираем отчёт.
**Fast tier** если ≤2 консьюмера и с `--sync-only` (без commit/push).
Pre-flight model check: спросить только если Capable (Opus) активен — не нужен.

---

## Флаги

| Флаг | Поведение |
|---|---|
| *(без флага — DEFAULT)* | Sync + авто-commit (manifest-scope) + авто-push (reuse deploy-push харнесс). Только whitelisted репо; вне whitelist — только sync. |
| `--sync-only` | Только sync файлов. Коммит и push — ручные. Escape-hatch. |

---

## Шаг 1 — Инициализация (флаги + whitelist)

**Дефолт = commit+push.** Зафиксировать в памяти сессии: `COMMIT_PUSH=true`.

**Флаг `--sync-only`:** если передан — `COMMIT_PUSH=false` (только sync файлов, без commit/push). Whitelist при `--sync-only` не читается.

**Whitelist (при `COMMIT_PUSH=true`, т.е. дефолт):** прочитать `CLAUDE.local.md ## auto_commit_consumers` → список `path`+`branch`. Это **policy gate** — commit+push разрешён ТОЛЬКО для путей в этом списка. Вне списка → только sync. Если секция отсутствует → 🔴 СТОП: «`auto_commit_consumers` не настроен в CLAUDE.local.md — добавь whitelist, или запусти с `--sync-only` для sync без коммита».

---

## Шаг 0.5 — Consumer Pull (ff-only, pre-dirty-check)

**Цель:** подтянуть remote commits перед dirty-check. Если другая сессия уже синкнула и запушила изменения — pull приводит локальный репо в актуальное состояние → dirty-check видит чистое дерево. Закрывает G-118 (perpetual dirty loop — sync писал tracked файлы без commit, dirty-guard пропускал репо, loop повторялся).

**Применяется:** только при `COMMIT_PUSH=true` (дефолт). При `--sync-only` — **пропустить** (нет commit+push → нет риска loop; pull не нужен для read-only синка).

**Для каждого whitelisted repo** (из `auto_commit_consumers`):

```bash
BRANCH=<branch-from-whitelist>  # из auto_commit_consumers для этого репо
PULL_OUT=$(git -C <consumer-path> pull --ff-only origin "$BRANCH" 2>&1)
PULL_EXIT=$?
```

**Интерпретация результата:**
- exit 0, вывод `"Already up to date."` → тихо продолжить (no-op)
- exit 0, вывод содержит `"Fast-forward"` → показать: `  📥 <имя>: pulled from remote (fast-forward)`
- exit ≠ 0 (diverged / conflict / network error) → ⚠️ warn + **пропустить repo** (НЕ abort батча):
  ```
  ⚠️ <имя>: pull --ff-only failed → repo пропущен (diverged или network)
     Причина: <PULL_OUT первые 2 строки>
     Реши вручную: git -C <path> pull [--rebase] origin <branch>
  ```

**Репо без remote origin** (локальный git без push настроенного remote): пропустить pull тихо (не ошибка).

**Инвариант:** `--ff-only` обязателен. Никогда не делать `git pull` (без флага), не делать `--rebase`. Если нельзя fast-forward → warn+skip — пользователь сам решает конфликт.

---

## Шаг 1.5 — Guard: dirty .claude/ pre-check

**Цель:** предупредить перед батч-синком если в whitelisted consumer repo есть грязные `.claude/` файлы. Работает для обоих режимов (`COMMIT_PUSH=true` и `--sync-only`).

> **Почему:** sync перезапишет dirty файлы даже при `--sync-only`. Пользователь должен явно подтвердить что это его намерение.

**Для каждого whitelisted repo** (из `auto_commit_consumers`):
```bash
git -C <consumer-path> status --short -- .claude/ 2>/dev/null | head -1
```
- exit ≠ 0 → skip с предупреждением `⚠️ git недоступен для <repo>`, продолжить

**Если dirty обнаружены:**
```
⚠️ Dirty .claude/ обнаружены перед синком:
   • ai-assistant-documentation: .version, commands/code.md, ...
   • social-promo-documentation: settings.json, ...

Синк перезапишет эти файлы (даже при --sync-only).
Рекомендация: запусти /sync-audit (Gap 17) чтобы разрешить dirty ПЕРЕД синком.

Продолжить несмотря на dirty? (y = продолжить / n = выйти)
```
- **y** → продолжить Шаг 2 (решение пользователя, его ответственность)
- **n** → `Запусти /sync-audit (Gap 17) для разрешения dirty, затем повтори /push-consumers.` → выход

**Если все clean:**
→ продолжить к Шагу 2 (без сообщения)

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

## Шаг 3 — Pre-check (parallel-session safety) + init [not-initialized]

Для каждого консьюмера со статусом `[drift]`:

```bash
git -C <consumer-path> status --short -- .claude/ 2>/dev/null
```

- Вывод непустой → пометить `[skip: dirty]` + причина. **НЕ синкать** — dirty `.claude/` = in-progress работа параллельной сессии. Запусти `/sync-audit` Gap 17 для разрешения (stash / ignore / ignore-always), затем повтори `/push-consumers`.
- Вывод пустой → добавить в список «будет обновлено».

**`[not-initialized]` — inline init (Gap 14 pattern, closes P-010):**

Репо без `.claude/` не может быть sync'нуто напрямую. Предложить per-repo выбор сразу в drift-таблице до батч-подтверждения Шага 4:

```
⚠️ [not-initialized]: lead-gen-documentation
   Репо обнаружен в workspace, но не инициализирован методологией.

   init    — запустить new-project-init.sh, затем включить в батч sync+commit+push
   skip    — пропустить в этом прогоне (останется [not-initialized])
   never   — исключить из всех будущих прогонов (добавить в exclude_paths)

Выбор для lead-gen-documentation: (init / skip / never)
```

**При ответе `init` — ⛔ pre-init pre-flight (G-118: distributed-state check ОБЯЗАТЕЛЕН):**

Перед запуском `new-project-init.sh` — убедиться что репо пустое во всех клонах, не только локально. Другой клон с незапушенными артефактами невидим через `git ls-files` / `find` → init поверх него создаёт дивергенцию и merge-конфликты при последующем push пользователя.

**Шаг A — Git fetch + remote check:**
```bash
git -C "<consumer-path>" fetch origin 2>/dev/null
REMOTE_BRANCHES=$(git -C "<consumer-path>" branch -r 2>/dev/null)
```
- Fetch упал (network/auth) → предупредить: «не смог проверить remote, init заблокирован» → задать вопрос Шага B вручную без fetch-данных.
- Remote ветки содержат коммиты с `.claude/` или `docs/` → показать:
  ```
  ⚠️ pre-init: <repo-name> уже имеет инициализированные ветки на remote.
     Возможно, другой клон уже содержит методологию или продуктовые файлы.
     Push-first путь: git -C <consumer-path> pull origin <branch> → затем /push-consumers синкнет как [drift].
     Init поверх существующего remote создаст дивергенцию.
  ```
  → предложить pull-first вместо init; пропустить init.

**Шаг B — Явный вопрос про другой клон:**
```
❓ pre-init: <repo-name> не инициализирован.
   Есть ли другой клон этого репо (на другой машине или в другой папке) с незапушенными файлами?

   нет  — репо действительно пустое, продолжить init
   да   — в другом клоне есть работа → сначала запушь её, затем повтори /push-consumers
   пропустить — отложить init (статус [not-initialized] останется)

Ответ (нет / да / пропустить):
```
- `да` → ⛔ **init ЗАПРЕЩЁН**: «Сначала запусти `git push` из клона с незапушенными файлами. После push повтори /push-consumers — репо появится как [drift] и будет синкнут без потерь.» → пропустить init, статус `[not-initialized, blocked: other-clone]`.
- `пропустить` → показать как `[not-initialized, skipped]`, не включать в батч.
- `нет` → продолжить к стандартному init.

**Шаг C — Стандартный init (только после подтверждения «нет»):**
```bash
# Определить project_name из basename репо (без суффиксов -documentation/-docs)
PROJECT_NAME="$(basename <consumer-path> | sed 's/-documentation$//' | sed 's/-docs$//')"
bash scripts/new-project-init.sh "$PROJECT_NAME" "<consumer-path>"
```

Guard: если `.claude/` уже существует после `init` (повторный запуск) → пропустить init, продолжить к sync как `[drift]`.

После успешного init → добавить репо в батч Шага 4 со статусом `[initialized → sync]`. Применяется стандартный sync + commit + push Шага 5 Режима B (если whitelisted).

**При ответе `skip`:** показать в таблице как `[skipped]`, не включать в батч.

**При ответе `never`:** добавить в `exclude_paths` в `CLAUDE.local.md ## Consumers`:

```yaml
# exclude_paths: []
exclude_paths:
  - <absolute-path-to-consumer>
```

Затем пропустить в текущем и всех будущих прогонах (тот же механизм что `/sync-audit` Gap 14 never-flow).

---

## Шаг 4 — Одно подтверждение на весь батч

Показать итоговую таблицу. При `COMMIT_PUSH=true` (дефолт) — добавить колонку `Commit+Push`. При `--sync-only` — колонку не показывать:

```
Drift-таблица (methodology vX.Y.Z):

| Репо | ver | Δ | Статус | Commit+Push |
|---|---|---|---|---|
| erp-documentantion | v4.47.5 | +94 | [drift] → обновить | ✅ whitelisted |
| it-dev-documentation | v4.45.0 | +96 | [drift] → обновить | ✅ whitelisted |
| some-other | v5.0.0 | +3 | [drift] → обновить | ⚠️ не в whitelist — только sync |
| lead-gen | — | — | [initialized → sync] | ✅ whitelisted |
| shopware | — | — | [not-initialized, skipped] | — |

Будет обновлено: 4 | Пропущено: 1 (skipped)
Будет сделан commit+push: 3 (whitelisted) | Только sync: 1 (not in whitelist)

Продолжить? (y/n/список через запятую для выборочного)
```

- **y** → все со статусом [drift] и [initialized → sync] (кроме dirty, never, skipped)
- **n** → выход, ничего не делать
- **«1,3»** → только указанные номера строк

---

## Шаг 5 — Батч синк (+ manifest-commit-push если флаг)

Для каждого согласованного консьюмера — **два режима** (выбор по `COMMIT_PUSH`):

### Режим A (`--sync-only` — только sync)

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

### Режим B (DEFAULT — commit+push, только whitelisted репо)

Для каждого консьюмера — **один вызов скрипта** (L4 structural fix, closes P-013):

```bash
bash scripts/push-consumer-single.sh "<consumer-abs-path>" "<branch-from-whitelist>"
```

Скрипт атомарно выполняет: sync (--print-changed) → symmetric dirty-check → manifest-scope commit → `check-gh-account.sh` (explicit whitelist lookup) → push с error classification.

**❌ НЕ реализовывать логику push inline** — это обходит `check-gh-account.sh` (P-013). Каждая новая сессия должна вызывать скрипт, не воссоздавать логику.

**Интерпретация exit code:**
- exit 0 → `  ✅ <имя>: sync + commit + push` (или `ℹ️ нечего коммитить` — тоже exit 0)
- exit 1 → `  ❌ <имя>: failed (см. вывод скрипта)` — continue к следующему (не abort батча)
- exit 2 → usage error (не должен случиться при правильном вызове)

**Invariants (проверяются внутри скрипта):**
- ❌ НИКОГДА не делать `git add` — только explicit pathspec из манифеста.
- ❌ НИКОГДА не делать push если commit вернул ненулевой exit.
- ❌ НИКОГДА не делать push в репо вне `auto_commit_consumers` whitelist.
- ❌ Fail одного консьюмера → continue к следующему (не abort батча).

---

## Шаг 6 — Финальный отчёт

**Дефолт (commit+push):**

```
=== /push-consumers результаты (methodology vX.Y.Z) ===

✅ erp-documentantion:          v4.47.5 → vX.Y.Z  (sync + commit + push ✅)
✅ it-dev-documentation:        v4.45.0 → vX.Y.Z  (sync + commit + push ✅)
✅ ai-assistant:                v4.10.6 → vX.Y.Z  (sync + commit + push ✅)
🆕 lead-gen:                    — → vX.Y.Z  (init ✅ + sync + commit + push ✅)
⚠️ some-other:                  v5.0.0  → vX.Y.Z  (sync ✅, commit+push пропущен — не в whitelist)
⏭ shopware:                    [not-initialized] — пропущен (skipped)

Sync: 5/5 ✅  |  Commit+Push: 4/4 whitelisted ✅  |  Init: 1 🆕  |  Пропущено: 1
```

**Если передан `--sync-only` — формат с ручным шагом коммита:**

```
=== /push-consumers результаты (--sync-only) ===

✅ erp-documentantion:     v4.47.5 → vX.Y.Z  (sync успешен)
...

⚠️ Коммит — твоё действие (одной командой):
   git -C ../erp-documentantion commit .claude/ docs/adr/_TEMPLATE.md scripts/ -m "sync methodology vX.Y.Z" && \
   git -C ../it-dev-methodology-documentation commit .claude/ docs/adr/_TEMPLATE.md scripts/ -m "sync methodology vX.Y.Z" && \
   ...
   (скопируй всё одним paste — или запусти без `--sync-only` для авто commit+push)
```

---

## Шаг 7 — Post-sync adoption audit sweep

**Условие:** выполняется только если Шаг 5 успешно синкнул ≥1 консьюмера. Пропускается тихо если Шаг 5 = 0 синков или если передан `--sync-only`.

**Цель:** немедленно после синка показать adoption gaps каждого консьюмера — чтобы pre-flight tax при последующем открытии репо = 0.

**Для каждого успешно синкнутого консьюмера:**

```bash
METH_PATH="$(pwd)"   # запускается из корня methodology repo
DOCTOR_OUT=$( (cd "<consumer-path>" && bash "$METH_PATH/scripts/sync-doctor.sh" --json --methodology-path "$METH_PATH") 2>&1 )
DOCTOR_EXIT=$?       # 0=PASS, 1=FAIL, 2=error/invalid-JSON
```

**Интерпретация:**
- exit 0 → все секции PASS → пометить `✅`
- exit 1 → есть FAIL секции → извлечь имена секций → записать как gap
- exit 2 или нечитаемый вывод → `⚠️ doctor error` — пропустить репо, не abort батча

**Агрегированная gap-таблица (выводить всегда, даже если все ✅):**

```
=== Post-sync adoption audit (sync-doctor) ===

| Репо                        | version | hooks | secrets | deps | Overall |
|-----------------------------|---------|-------|---------|------|---------|
| erp-documentantion          | ✅      | ✅    | ⚠️ FAIL | ✅   | ⚠️      |
| ai-assistant-documentation  | ✅      | ⚠️ FAIL | ✅    | ✅   | ⚠️      |
| it-dev-methodology-docs     | ✅      | ✅    | ✅      | ✅   | ✅      |
```

**Gap-список (если есть FAIL):**

```
Gaps требующие /plan:
  • erp-documentantion — [secrets]: secrets-manifest.yaml отсутствует
  • ai-assistant-documentation — [hooks]: run-hook.sh не найден на диске

→ /plan для каждого gap выше (per-repo, per-category)
```

**Если все ✅:**

```
✅ Все консьюмеры adoption-healthy — дополнительные /plan не нужны.
```

**Авто-переход к Шагу 8 (без отдельного запроса):**

После вывода gap-таблицы — немедленно перейти к Шагу 8 (/pull-consumers). Не спрашивать подтверждения. Пользователь явно выбрал `/push-consumers` → весь workflow (sync → audit → pull) выполняется как единая операция.

---

## Шаг 8 — Auto /pull-consumers (без запроса)

**Выполняется автоматически** сразу после Шага 7.

**Цель:** получить свежие consumer-authored данные (AGENT-GAPS, DEVLOG, IDEAS) — нужны как контекст для `/plan` на фиксы из gap-таблицы Шага 7.

**Логика порядка:** push = methodology → consumers (Шаг 5) → audit (Шаг 7) → pull = consumer-authored данные → methodology owner (этот шаг). Только после pull owner видит полную картину: что доставлено + что consumers сами накопили.

Выполнить `/pull-consumers` полностью (весь её workflow: discovery → git pull → diff артефактов → отчёт).

По завершении — показать:

```
=== /push-consumers + /pull-consumers завершены ===

Следующий шаг:
  /plan per gap — по таблице adoption audit выше (если есть ⚠️)
  Данные для анализа: gap-таблица (Шаг 7) + consumer-diff (Шаг 8 выше)
```

**Если `--sync-only`:** Шаг 8 пропускается (нет commit/push → pull не нужен).

---

## Когда запускать

- **После каждого релиза** методологии (рекомендация в `/deploy` финале). Дефолт = zero-step deploy: sync + commit + push + audit для всех whitelisted в одном прогоне.
- **Перед `/retro`** — убедиться что консьюмеры на свежей версии и adoption-healthy
- **`--sync-only`** — когда нужно только доставить файлы без коммита (Шаг 7 пропускается)
- ❌ НЕ запускать автоматически — manual trigger only (решение владельца)
