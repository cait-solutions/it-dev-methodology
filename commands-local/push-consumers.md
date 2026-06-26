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

**Extended (UI settings):** effort: **Medium** · thinking: **ON** — drift-таблица + оценка что доставить (лёгкое суждение). См. `.claude/model-tiers.md` § Effort & Thinking.

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

## Шаг Phase 0 — North Star Bootstrap (pre-sync, v7.0.0)

**Цель:** убедиться что каждый consumer имеет заполненный North Star до отправки обновлений методологии. Без North Star `/roadmap` не может приоритизировать по ценности, а PORTFOLIO.md (Layer 2) остаётся заблокированным (VISION Ось 8).

**Когда:** только при `COMMIT_PUSH=true` (дефолт). При `--sync-only` → **пропустить** (write-операция не нужна).

**PRESERVE semantics (ОБЯЗАТЕЛЬНО):** NORTH-STAR.md — project-owned. Агент записывает ТОЛЬКО если файл содержит шаблонные placeholder'ы (`<например:`). Заполненные или кастомные значения — не трогать никогда.

**Discovery:** тот же список consumer repos что Шаг 2. Выполняется ДО pull и init.

**Для каждого consumer из workspace:**

1. **Проверить наличие и заполненность:**
   ```bash
   NS_PATH="<consumer-path>/NORTH-STAR.md"
   # grep -F для literal string (не интерпретировать < > как редирект)
   placeholder_count=$(grep -cF "<например:" "$NS_PATH" 2>/dev/null || echo "0")
   ns_exists=false; [[ -f "$NS_PATH" ]] && ns_exists=true
   ```
   - `ns_exists=false` → файл отсутствует → спросить
   - `placeholder_count > 0` → placeholder присутствует → спросить
   - `placeholder_count = 0` AND `ns_exists=true` → заполнен → `✅ <repo>: North Star OK` → пропустить

2. **Если не заполнен:**
   ```
   ⚠️ <repo>: NORTH-STAR.md не заполнен.
      North Star нужен для /roadmap приоритизации (VISION Ось 8).
      Заполнить сейчас? (y / skip)
        y     — задам несколько вопросов (аналогично /roadmap Шаг 1)
        skip  — пропустить (⚠️ появится в NS-колонке /pull-consumers)
   ```

3. **При `y` — Q&A (по одному вопросу, Recommendation-first rule):**

   Q1: «Главная метрика ценности? [рекомендуется: MRR/выручка для коммерческого проекта]»
   Q2: «project_role: growth или enabling? [рекомендуется: growth если проект напрямую продаёт; enabling если инструмент/инфраструктура]»
   Q3: «Target и горизонт? [можно: `<не задан>` — не блокирует]»
   Q4: «Baseline / текущее значение? [опционально — нажми Enter чтобы пропустить]»

4. **Write NORTH-STAR.md (write-if-empty):**
   - Заменить placeholder-значения в таблицах на введённые ответы
   - ⛔ PRESERVE: если строка НЕ содержит `<например:` — не трогать (кастомный fill)
   - Дата создания в нижней строке: `*Создан: YYYY-MM-DD.*`
   - **NO auto-commit** — файл попадёт в commit Шага 5 как часть manifest-scope (если NORTH-STAR.md в списке changed)
   - Показать: `✅ <repo>: NORTH-STAR.md заполнен.`

5. **При `skip`:** продолжить. NS-колонка в `/pull-consumers` покажет ⚠️.

6. **Anti-friction (после 2-го `skip` подряд):** показать один раз:
   ```
   Пропустить North Star для всех оставшихся? (y / n)
   ```
   Закрывает Pre-Mortem риск (32 вопроса при 8 consumers).

**После обхода всех consumers:**
```
North Star bootstrap: ✅ X заполнено / ⏭ Y пропущено
```
→ продолжить к Шагу 0.5

⛔ **Batch defaults запрещены:** авто-заполнять без Q&A нельзя. Forcing function — интерактивность делает заполнение осмысленным.

---

## Шаг 0.5 — Consumer Pull (ff-only, pre-dirty-check)

**Цель:** подтянуть remote commits перед dirty-check. Если другая сессия уже синкнула и запушила изменения — pull приводит локальный репо в актуальное состояние → dirty-check видит чистое дерево. Закрывает G-118 (perpetual dirty loop — sync писал tracked файлы без commit, dirty-guard пропускал репо, loop повторялся).

**Применяется:** только при `COMMIT_PUSH=true` (дефолт). При `--sync-only` — **пропустить** (нет commit+push → нет риска loop; pull не нужен для read-only синка).

**Для каждого whitelisted repo** (из `auto_commit_consumers`):

```bash
BRANCH=<branch-from-whitelist>  # из auto_commit_consumers для этого репо
PREV_SHA=$(git -C <consumer-path> rev-parse HEAD 2>/dev/null)   # baseline ДО pull — для NEW-колонок Шага 2.5
PULL_OUT=$(git -C <consumer-path> pull --ff-only origin "$BRANCH" 2>&1)
PULL_EXIT=$?
HEAD_SHA=$(git -C <consumer-path> rev-parse HEAD 2>/dev/null)   # состояние ПОСЛЕ pull
```

**Интерпретация результата:**
- exit 0, вывод `"Already up to date."` → тихо продолжить (no-op); `PULL_OK=true`
- exit 0, вывод содержит `"Fast-forward"` → показать: `  📥 <имя>: pulled from remote (fast-forward)`; `PULL_OK=true`
- exit ≠ 0 (diverged / conflict / network error) → ⚠️ warn + **пропустить repo** (НЕ abort батча); `PULL_OK=false`:
  ```
  ⚠️ <имя>: pull --ff-only failed → repo пропущен (diverged или network)
     Причина: <PULL_OUT первые 2 строки>
     Реши вручную: git -C <path> pull [--rebase] origin <branch>
  ```

**Репо без remote origin** (локальный git без push настроенного remote): пропустить pull тихо (не ошибка); `PULL_OK=false`.

**Сохранить per-repo** `PREV_SHA` / `HEAD_SHA` / `PULL_OK` — используются Шагом 2.5 для вычисления `NEW gaps` / `NEW devlog` из уже-подтянутого диапазона (без нового fetch). При `PULL_OK=false` (failed / diverged / нет origin) baseline недоступен → колонки покажут `—`, не ложный `0`.

**Инвариант:** `--ff-only` обязателен. Никогда не делать `git pull` (без флага), не делать `--rebase`. Если нельзя fast-forward → warn+skip — пользователь сам решает конфликт.

---

## Шаг 1.5 — Guard: dirty .claude/ pre-check (info-only)

**Цель:** дать обзор dirty `.claude/` перед батч-синком. ⚠️ Это **информационный** pre-check — реальную триаж-логику исполняет `push-consumer-single.sh` (Шаг 5 Режим B): **derived churn** (commands/hooks/skills/model-tiers/task-types/.version/settings.json) авто-разрешается (sync переприменит, commit захватит, включая удаления deprecated-команд); блокируется **только** non-derived работа (`.claude/state/` per-developer счётчики, `.claude/agents/` consumer-body, secrets-manifest, локальные правки) → repo пропускается с конкретным сообщением. Deadlock структурно невозможен: derived churn всегда re-resolvable.

**Для каждого whitelisted repo** (из `auto_commit_consumers`):
```bash
git -C <consumer-path> status --short -- .claude/ 2>/dev/null | head -1
```
- exit ≠ 0 → skip с предупреждением `⚠️ git недоступен для <repo>`, продолжить

**Если dirty обнаружены:** показать обзор (info, не блок):
```
ℹ️ Dirty .claude/ перед синком (триаж в push-consumer-single.sh):
   • ai-assistant-documentation: commands/code.md (derived → авто-разрешится)
   • some-repo: .claude/state/triggers.json (non-derived → repo будет пропущен)

Derived churn авто-разрешается синком. Non-derived (state/agents/secrets/локальные правки)
→ repo пропускается, разреши вручную (commit / stash / discard) и повтори.
Продолжить? (y = продолжить / n = выйти)
```
- **y** → продолжить Шаг 2 (per-repo триаж выполнит скрипт)
- **n** → выход

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

## Шаг 2.5 — Drift-таблица

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
5. **NEW gaps / NEW devlog (pre-push consumer-authored visibility):** для whitelisted репо где Шаг 0.5 выполнил pull (`PULL_OK=true`) — вычислить число новых consumer-authored записей из уже-подтянутого диапазона `PREV_SHA..HEAD_SHA` (данные локальны после Шага 0.5, **нового fetch не требуется**):
   ```bash
   # AGENT-GAPS (корень И docs/) — новые Gap-ID: в диапазоне pull
   NEW_GAPS=$(git -C <consumer-path> diff "$PREV_SHA..$HEAD_SHA" -- AGENT-GAPS.md docs/AGENT-GAPS.md 2>/dev/null \
     | grep -cE '^\+Gap-ID:' || echo 0)
   # DEVLOG (корень И docs/) — новые записи (заголовки ## 20…)
   NEW_DEVLOG=$(git -C <consumer-path> diff "$PREV_SHA..$HEAD_SHA" -- DEVLOG.md docs/DEVLOG.md 2>/dev/null \
     | grep -cE '^\+## 20' || echo 0)
   ```
   - `PULL_OK=false` (pull failed / diverged / нет origin) ИЛИ **не-whitelisted** репо (только sync, без pull) → `NEW_GAPS="—"`, `NEW_DEVLOG="—"` (baseline недоступен — не показывать ложный `0`).
   - Файл отсутствует у консьюмера → `git diff` по несуществующему пути пуст → `0` (корректно: нет файла = нет новых).
   - `PREV_SHA == HEAD_SHA` (уже актуально) → diff пуст → `0` (корректно).

**Пример drift-таблицы:**

| Репо | Consumer ver | Synced | Δ | NEW gaps | NEW devlog | Статус |
|---|---|---|---|---|---|---|
| erp-documentantion | v4.47.5 | 2026-06-01 | +94 minor | 2 | 5 | [drift] |
| it-dev-methodology-documentation | v4.45.0 | 2026-06-01 | +96 minor | 0 | 1 | [drift] |
| ai-assistant-documentation | v4.10.6 | 2026-05-27 | +131 minor | — | — | [skip: pull failed] |
| ebay-template-documentation | v4.60.0 | 2026-06-04 | +81 minor | 0 | 0 | [drift] |
| lead-gen-documentation | — | — | — | — | — | [not-initialized] |

> **NEW gaps / NEW devlog** = consumer-authored записи, появившиеся в диапазоне Шага 0.5 ff-pull (`PREV_SHA..HEAD_SHA`) — то что консьюмер накопил с момента последнего локального состояния владельца. Видны **до** подтверждения push (Шаг 4) → последний checkpoint перед пропагацией методологии на fleet. `—` = pull не выполнялся (не-whitelisted / failed / нет origin). Полный **контент** этих записей — в Шаге 8 (`/pull-consumers`); здесь только счётчик-сигнал.

---

## Шаг 3 — Pre-check (parallel-session safety) + init [not-initialized]

Для каждого консьюмера со статусом `[drift]`:

```bash
git -C <consumer-path> status --short -- .claude/ 2>/dev/null
```

- Вывод непустой → **не помечать слепо `[skip: dirty]`** — финальный триаж в `push-consumer-single.sh` (Шаг 5): derived churn авто-разрешается, только non-derived (`.claude/state/`, `.claude/agents/`, secrets, локальные правки) → repo пропускается с конкретным сообщением, разрешается вручную (commit / stash / discard).
- Вывод пустой → добавить в список «будет обновлено».

**`[not-initialized]` — inline init (closes P-010):**

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

Затем пропустить в текущем и всех будущих прогонах (never-flow: добавление в `exclude_paths`).

**`[inited, not-whitelisted]` — onboarding в whitelist (closes «update ALL = только те, кого вспомнили внести»):**

Консьюмер **обнаружен** в workspace И **имеет** `.claude/` (инициализирован), но **отсутствует** в `auto_commit_consumers` → по конструкции получит только sync, без commit/push (молчаливый sync-only bucket). Discovery (Шаг 2) и push-gating (whitelist) — два раздельных списка; их рассинхрон делает «обновить ВСЕ» = «обновить всех, кого вручную внесли». Для каждого такого репо — per-repo prompt **до** батч-подтверждения Шага 4:

```
⚠️ [inited, not-whitelisted]: <repo>
   Инициализирован методологией, но НЕ в auto_commit_consumers → push невозможен.

   add   — добавить в whitelist (предложу branch + gh_account), затем включить в commit+push батч
   sync  — только sync в этом прогоне (останется не-whitelisted)
   never — exclude_paths (исключить из всех будущих прогонов)

Выбор для <repo>: (add / sync / never)
```

**При `add` (Recommendation-first):**
1. Прочитать `<repo>/CLAUDE.local.md ## Branching` → `agent_branch`. Предложить его как `branch:` (дефолт). ⚠️ **G-117 branch-mismatch:** whitelist `branch` ДОЛЖЕН равняться `agent_branch` целевого репо — если у репо solo-on-main, branch=`main`; если team/ai-dev → `ai-dev` (и push в `main` делает человек через PR).
2. Определить `gh_account`: предложить owner из `git -C <repo> remote get-url origin` (сегмент после хоста). Подтвердить у владельца (это его решение — какой gh-аккаунт имеет write-доступ).
3. **Append** запись в `CLAUDE.local.md ## auto_commit_consumers` (explicit pathspec edit, не нарушая human-форматирование/комментарии блока):
   ```yaml
     - path: <relative-path>
       branch: <agent_branch>
       gh_account: <owner>
   ```
4. Включить репо в батч Шага 4 со статусом `[onboarded → sync+commit+push]`.

**При `sync`:** оставить как `[not-whitelisted]` — только sync в этом прогоне (Шаг 5 Режим A).
**При `never`:** добавить в `exclude_paths` (тот же flow что выше).

> **NB:** drift («inited + не в whitelist») сюрфейсится здесь, в `/push-consumers` — единственной точке доставки (push-only). Отдельной adoption-команды у консьюмера нет by-design.

---

## Шаг 4 — Одно подтверждение на весь батч

Показать итоговую таблицу. При `COMMIT_PUSH=true` (дефолт) — добавить колонку `Commit+Push`. При `--sync-only` — колонку не показывать:

```
Drift-таблица (methodology vX.Y.Z):

| Репо | ver | Δ | NEW gaps | NEW devlog | Статус | Commit+Push |
|---|---|---|---|---|---|---|
| erp-documentantion | v4.47.5 | +94 | 2 | 5 | [drift] → обновить | ✅ whitelisted |
| it-dev-documentation | v4.45.0 | +96 | 0 | 1 | [drift] → обновить | ✅ whitelisted |
| some-other | v5.0.0 | +3 | — | — | [drift] → обновить | ⚠️ не в whitelist — только sync |
| lead-gen | — | — | — | — | [initialized → sync] | ✅ whitelisted |
| shopware | — | — | — | — | [not-initialized, skipped] | — |

Будет обновлено: 4 | Пропущено: 1 (skipped)
Будет сделан commit+push: 3 (whitelisted) | Только sync: 1 (not in whitelist)

ℹ️ NEW gaps/devlog (Шаг 2.5) — consumer-authored записи с момента последнего pull. Ненулевые = консьюмер что-то накопил; просмотри ДО подтверждения, если хочешь придержать push (полный контент — Шаг 8).

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

## Шаг 5.6 — One-time delivery-rudiment sweep (parallel-safe)

**Условие:** выполняется только для whitelisted репо где Шаг 5 Режим B прошёл. Цель — снять
stale-копии maintainer-only скриптов (`clone-consumer.sh`, `sync-doctor.sh`), снятых из
`templates/scripts/` в v7.6.0. Sync **не удаляет** removed-upstream скрипты → нужна явная чистка.
Миграция применяется автоматически при sync (`_runner.sh` в `sync-methodology.sh`); этот шаг — явная чистка removed-upstream скриптов на push-стороне.

**Per-whitelisted-consumer (parallel-safe, идемпотентно):**

```bash
# 1. Применить миграции (включая remove-consumer-delivery-rudiments) — git rm стейджит удаление.
#    _runner.sh — КАНОНИЧЕСКИЙ механизм, не реимплементировать inline (как push-consumer-single.sh, P-013).
bash scripts/migrations/_runner.sh "<consumer-abs-path>"

# 2. Закоммитить ТОЛЬКО staged-удаление (explicit pathspec — закрывает index-capture a17ecc1).
#    ⛔ -m ДО `--` (иначе `--` делает -m и сообщение pathspec'ами → "did not match any file").
#    Если ни один файл не застейджен (parallel-сессия уже снесла / уже чисто) → no-op, пропустить репо.
staged=$(git -C "<consumer-abs-path>" diff --cached --name-only -- scripts/clone-consumer.sh scripts/sync-doctor.sh)
if [ -n "$staged" ]; then
  git -C "<consumer-abs-path>" commit -m "chore: remove maintainer-only delivery rudiments (methodology v7.6.0)" \
    -- scripts/clone-consumer.sh scripts/sync-doctor.sh
  # 3. Сначала gh-аккаунт по whitelist (P-012/P-013, не угадывать из URL):
  bash scripts/check-gh-account.sh "<consumer-abs-path>" || echo "  ⚠️ <имя>: gh-account check failed — push пропущен"
  # 4. Push ff-only через HEAD:<branch> (НЕ `push origin <branch>` — упадёт "src refspec does not
  #    match any" если локальная ветка ≠ <branch>; HEAD:<branch> пушит текущий HEAD в remote-ветку).
  #    Одна fetch-retry; non-ff (parallel-сессия запушила) → skip+warn, НЕ force.
  git -C "<consumer-abs-path>" push origin HEAD:"<branch-from-whitelist>" 2>/dev/null \
    || { git -C "<consumer-abs-path>" fetch origin "<branch>" --quiet; \
         git -C "<consumer-abs-path>" push origin HEAD:"<branch>" 2>/dev/null \
         || echo "  ⚠️ <имя>: push non-ff (parallel-сессия?) — пропускаю, не форсирую"; }
fi
```

**Parallel-safety инварианты (≥2 сессии /push-consumers одновременно):**
- ✅ **Idempotent no-op:** оба рудимента отсутствуют → миграция SKIP → нет staged → репо пропущен (нет пустого коммита, нет push). Покрывает «parallel-сессия уже снесла».
- ✅ **Explicit pathspec** — коммитятся только 2 удаляемых файла, не весь индекс (a17ecc1).
- ✅ **ff-only + fetch-retry-once**, иначе skip+warn. ❌ Никакого force, не блокировать другую сессию.
- ✅ Dirty-check по этим 2 путям (`diff --cached -- <2 пути>`), не по всему дереву.

**Граница read-only:** только whitelisted `*-documentation` репы (CLAUDE.local.md `auto_commit_consumers`).
Код-репы консьюмеров **не трогаются** — они самочистятся миграцией при следующем sync. Финальный
push — после твоего подтверждения (Шаг 4 батч-confirm покрывает).

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
