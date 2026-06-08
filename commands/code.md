# /code — Реализация по плану

> **Цель:** реализовать утверждённый /plan атомарными commits + обновить документацию (PRODUCT.md, карты, ADR) в том же PR. /code НЕ генерирует план — он его исполняет. Branch check + self-review 11 точек + финализация Mermaid карт + sync validators в /review.

После `/plan` и его подтверждения — реализация ОБЯЗАТЕЛЬНО через `/code`. Прямая реализация запрещена.

---

## Рекомендуемая модель

**Strategy:** наследуется из `/plan`. Default (Sonnet) — основной выбор.

**Default tier (Sonnet):** Наследуется из `/plan`. Используется для большинства /code работ.

**Upgrade to Capable tier (Opus) if:**
- new class bug обнаружен mid-task (требует grep по всему проекту)
- 50+ файлов в scope после верификации гипотезы
- задачи появились вне scope плана (требуется переплан)
- Шаг 1.5 reassessment найдёт триггер escalation

**❌ Downgrade to Fast tier:** НЕ рекомендуется даже если scope < 30 строк
- Риск: неправильный синтез, пропущены побочные эффекты
- Лучше переплатить на Default чем потерять качество

**Mid-task escalation:** **да — Шаг 1.5 Complexity reassessment** (обязательная остановка, может рекомендовать upgrade)

**Pre-flight model check:** **да — при старте команды** спроси пользователя какая модель активна (или используй ранее подтверждённую в сессии) и сравни с tier из `/plan` рекомендации. Если mismatch ≥ 2 ступени — пауза + рекомендация перед началом реализации.

---

## Режим (наследуется из /plan)

**Lite mode** — багфикс < 20 строк, изменения комментариев, простой рефакторинг.
В Lite: Шаг 0 без warnings, Шаг 1 только целевой файл, Шаг 4 только 2 точки (пункты 1-2).

**Full mode** — всё остальное. Все 6 шагов целиком.

> При сомнении — Full mode.

---

## Шаг 0 — State check

1. Прочитать `.claude/state/triggers.json`
2. Если применимо для проекта — проверить триггеры (architecture_audit, etc)
3. Установить `last_plan_session.code_run = true`
4. Сохранить triggers.json
5. **Branch check:** `git branch --show-current`
   - Прочитать `CLAUDE.local.md` → секция `## Branching` (или defaults если секции нет):
     - `agent_branch` — единственный enforced source of truth для AI-ветки. Default: `ai-dev`. Универсально для всех типов репо (различение doc-репо vs code-репо обеспечивается изоляцией репозитория).
     - `production_branch` (default: `main`)
     - `integration_branch` (solo: = `production_branch`; team: из конфига)
     - `worktree_isolation` (default: `off`) — если `auto`, допустимы namespaced ветки (см. ниже)
   - Текущая ветка = `agent_branch` → ✅ продолжить
   - **Текущая ветка = `{agent_branch}/<...>` (namespaced, напр. `ai-dev/checkout-fix`)** → ✅ продолжить если `worktree_isolation: auto`. Это concurrent-session ветка из изолированного worktree. Если `worktree_isolation: off` а ветка namespaced → 🟡 warning "namespaced branch but worktree_isolation is off — set it to auto in CLAUDE.local.md if running concurrent sessions" + продолжить.
   - Текущая ветка = `production_branch`, `master`, `develop`, `staging`, `integration_branch` → ⛔ СТОП
   - Сообщить: "AI-агенты коммитят только в `{agent_branch}` (или `{agent_branch}/<task>` при worktree_isolation: auto). Переключись: `git checkout {agent_branch}` или `git checkout -b {agent_branch}`"
   - `CLAUDE.local.md` отсутствует → ⛔ "CLAUDE.local.md not found — run new-project-init.sh first"
   - `agent_branch` отсутствует в `## Branching` → fallback на `ai-dev` + 🟡 warning "agent_branch missing in CLAUDE.local.md — add it (see CLAUDE_LOCAL.template.md)."
   - Явное разрешение разработчика → продолжить, записать `[branch-override]` в DEVLOG
   - Git не инициализирован → пропустить проверку
5.5. **Concurrent-session ownership check** (только если `worktree_isolation: auto`) — closes P-001 Layer 2 (encapsulation):
   - Если `worktree_isolation: off` → пропустить тихо (single-session проект, AGENTS.md не нужен).
   - Если `auto` И `AGENTS.md` существует → прочитать секцию `## Active claims`:
     - Определить file-scope текущей задачи (пути которые план будет менять — Шаг 1 Затронутые файлы).
     - Сравнить с claimed file-scope других строк (другие активные сессии/разработчики).
     - **Пересечение найдено** → ⛔ СТОП: "File-scope текущей задачи (`<paths>`) пересекается с активным claim '<task>' (owner: <owner>). Layer 2 (one-file-one-owner) нарушится. Варианты: (a) выбрать непересекающийся scope, (b) дождаться очистки claim, (c) скоординироваться с владельцем claim. НЕ редактировать до разрешения."
     - **Нет пересечения** → добавить **свою** claim-строку в `## Active claims` (Task / Owner / Branch / File-scope / дата) **до первой правки файла** (ordering invariant: claim ДО edit). На merge — строка убирается (в /deploy).
   - `auto` но `AGENTS.md` отсутствует → 🟡 warning "worktree_isolation: auto but AGENTS.md missing — run sync-methodology.sh to add it" + продолжить (не блок).
6. **Repo ownership check:** перед каждым коммитом убедиться что текущий repo = target repo из задания (обычно it-dev-methodology). Консьюмер-репо (erp-*, ai-assistant-*, etc.) = **read-only** для анализа; их артефакты (AGENT-GAPS.md, DEVLOG.md) обновляет владелец проекта вручную — агент методологии туда не коммитит. (closes G-032)

---

## Шаг 0.5 — Системная причина (для багфиксов)

Этот баг **локальный** или **системный**? ⛔ Классификация на глаз = красный флаг — определи через **доказательство**, не интуицию.

**Discipline-creating проверка (не отвечай по памяти):**
1. Определи паттерн бага (имя функции / тип конструкции / класс ошибки).
2. Посчитай вхождения паттерна по кодовой базе:
   ```bash
   grep -rn "<паттерн>" <relevant-dirs> | wc -l    # сколько мест с этим паттерном
   git log --all -S"<паттерн>" --oneline | head     # история — паттерн вводился разово или копировался?
   ```
3. Классификация **по числу**, не по ощущению:
   - **≥ 2 места с тем же паттерном** → **СИСТЕМНЫЙ** → архитектурный фикс (декоратор / middleware / schema constraint / validator), не точечная правка одного места. Вернуться в /plan если scope расширяется.
   - **1 место, паттерн уникален** → **ЛОКАЛЬНЫЙ** → точечный фикс + обязательно: «что структурно предотвращает рецидив в этой точке?»

⛔ «Локальный» заявлен без показанного результата grep = не зачтено (это и есть «классификация на глаз»). Покажи число.

---

## Шаг 1 — Верификация гипотезы

Перед первой строкой кода:
- [ ] Прочитан актуальный код целевого файла
- [ ] Подтверждена точка входа (route → controller → service)
- [ ] Зависимости существуют (grep импортов)
- [ ] Если целевой файл = методологический артефакт (ARTIFACT-MAP / SYSTEM-MAP / USER-MAP / docs/product/*.md) → прочитать файл **ПОЛНОСТЬЮ**, не только изменяемую секцию
- [ ] Сверить список смежных зон из /plan Шаг -1.3 — все ли действительно не затронуты?
- [ ] **Gitignore ownership check:** если целевой файл gitignored (`git check-ignore -v <path>` даёт hit) И является methodology artifact (`.claude/commands/`, `commands/`, `templates/`) → ⛔ СТОП: файл принадлежит upstream repo; изменение = PR туда, не здесь. Build-артефакты (`dist/`, `*.pyc`) — исключение, редактировать нормально. Если git недоступен → предупредить разработчика. (closes G-007)
- [ ] **External service pre-check (closes G-060):** если задача взаимодействует с внешним сервисом (Keycloak, database, API, SMTP, S3, и т.п.) — проверить наличие секретов ДО начала реализации:
  ```bash
  bash scripts/check-secret.sh KEY_NAME   # exit 0 = установлен, exit 1 = missing
  ```
  Если **missing** → показать `how_to_obtain` из `.claude/secrets-manifest.yaml` для этого KEY, вывести точную команду установки, **HARD BLOCK** до подтверждения пользователем что установил:
  ```
  ⛔ SECRET MISSING: KEY_NAME не установлен.
     Как получить: <how_to_obtain из manifest>
     Установить: bash scripts/set-secret.sh KEY_NAME  (интерактивно)
     После установки напиши "готово" — продолжу.
  ```
  Если `scripts/check-secret.sh` **недоступен** (consumer на старой версии без secrets infra) → 🟡 warn: "Нет secrets infrastructure — запусти sync-methodology.sh . чтобы получить скрипты. Пока продолжаю без проверки." → не блокировать.
  Если задача не требует external сервисов — явно написать `[N/A — задача не требует external services]` и продолжить.

Если что-то не найдено — СТОП, сообщи разработчику.

---

## Шаг 1.5 — Complexity reassessment (обязательный)

После Шага 1 верификации — переоценить сложность задачи vs первоначальная оценка из `/plan`. Триггеры upgrade:

**Scope-ось (объём работы):**
- [ ] Обнаружен class bug в ≥3 файлах (фикс одного места недостаточен)?
- [ ] Нужно прочитать ≥50 файлов для proper analysis?
- [ ] Появились задачи вне scope плана (требуется параллельный refactor)?
- [ ] Обнаружено что текущий tier (см. `.claude/model-tiers.md`) не соответствует Capable когда задача того требует?

**Reasoning-depth ось (глубина, не объём — closes G-082) — двухступенчатая escalation ladder:**
- [ ] N-я итерация (N≥3) над ОДНИМ visual/CSS/поведенческим багом без подтверждённого root cause? Задача "маленькая" по файлам, но не сходится — это reasoning-depth сигнал, не scope.
  - Это ловит и `iteration-watchdog.py` (PostToolUse, L4) — он считает повторные Edit одного frontend-файла без commit и выводит сигнал автоматически (двухступенчато). Чекбокс здесь — backup на случай если hook отсутствует/отключён. **NB:** если hook молча не работает → SessionStart hook-drift detector предупредит «run sync» (closes класс «settings→missing hook»).
  - **Ступень 1 (на N-й итерации, ТЕКУЩАЯ модель):** СТОП локальные патчи → найди РАБОТАЮЩИЙ эталон-аналог (grep похожий компонент), сравни **механизм** не симптом (урок G-047: sidebar через `inline style width` анимировался, через Tailwind class switch — нет) → измерь реальный DOM (Playwright/getBoundingClientRect), не рассуждай из source (урок G-039). Дай текущей модели шанс через reasoning-подход, без эскалации модели.
  - **Ступень 2 (на N2-й итерации, default N+2=5, ЕСЛИ ступень-1 не помогла):** баг всё ещё не сходится → сообщить **ПОЛЬЗОВАТЕЛЮ**: «закрой сессию → новая сессия на Capable (Opus) reasoning-модели — задача deep-reasoning, текущая не сходится» (эмпирика G-082: Sonnet циклил sidebar, Opus решил за раз). Смена модели = действие пользователя (агент не может сам), поэтому ступень-2 — рекомендация, не auto-switch.

Если **любой** триггер сработал — СТОП. Вывести:

```
⚠️ Сложность задачи выше плановой оценки.
   Текущая модель: <current model name>
   Рекомендуемая: <upgrade tier> (см. .claude/model-tiers.md)
   Причина: <конкретно что обнаружено>

Варианты:
  a) Продолжить на текущей модели (зафиксировать в DEVLOG как accepted risk)
  b) Переключиться (закрыть сессию → выбрать новую модель → новая сессия) (рекомендуется)
  c) Прервать /code и вернуться в /plan для пересмотра scope

Жду ответа: (a/b/c)
```

Если триггеры не сработали — продолжить на текущей модели, перейти к Шагу 1.7.

---

## Шаг 1.7 — Class bug grep anticipation (D4: where else does this pattern exist?)

**Принцип:** Когда найден баг в точке A, вопрос "где ещё такой же паттерн" — это не опция, это обязательный рефлекс.

Перед первой строкой кода:

1. **Определи паттерн:** Какой именно паттерн менялся?
   - Пример: "обработка ошибки при API call" 
   - Пример: "валидация входных данных перед сохранением"
   - Пример: "очистка состояния при переходе"

2. **Grep по паттерну:** Ищи аналогичный паттерн без защитных обёрток в других файлах
   - `grep -r "api_call" --include="*.py"` (найти все API calls)
   - `grep -r "validate(" --include="*.py"` (найди все валидации)
   - Для каждого результата: "здесь нужна та же защита?"

3. **Mandatory output (S-028) — обязателен если grep нашёл ≥1 результат:**

   ⛔ Нельзя написать "проверил, всё ок" без явной таблицы. Пустой вывод grep = явно написать "0 результатов".

   | Файл | Паттерн найден | Действие |
   |---|---|---|
   | `path/to/file.md` | да / нет | защищён / нужна защита / N/A |
   | `path/to/other.md` | да / нет | защищён / нужна защита / N/A |

   Таблица заполняется **до** первой строки кода. Пустая таблица без строк = шаг не выполнен.

4. **Partial-check вопрос** (обязательный для однотипных элементов):
   - Задача меняет **N из M** однотипных элементов одного класса (ноды диаграммы, поля шаблона, секции команды, файлы одного паттерна)?
   - Если да → **grep всех M**, не только затронутых N. Пример: добавляешь Q-ветку для 2 команд → проверить все 5 health-check команд.
   - ⛔ Без этой проверки — partial fix, не полный.

**Результат:** Если найдены ≥2 места без защиты → фикс не просто в целевом файле, а архитектурный (декоратор, middleware, schema constraint). Вернуться в /plan для пересмотра scope.

---

## Шаг 2 — Реализация

Каждый шаг плана = один атомарный commit.

**Не выходи за рамки плана** — только согласованные изменения.

**⛔ Commit-discipline (parallel-safe — closes index-capture класс, инцидент a17ecc1):**

Коммить через **explicit pathspec**, НЕ через `git add <file>` + bare `git commit`:
```bash
git commit <конкретные-пути> -m "..."     # ✅ коммитит ТОЛЬКО указанные файлы
```
⛔ **НЕ** делать `git add <file>` затем `git commit` (без путей) — `git commit` без pathspec коммитит **весь staging-индекс**, включая файлы которые застейджила **другая параллельная сессия** → захват чужой незакоммиченной работы.

**Verify-before-commit gate (один проход перед каждым commit):**
1. `git diff --cached --name-only` — что реально застейджено?
2. Сверить: staged-set ⊆ «Затронутые файлы» из `/plan` Шаг 1 (твой declared scope).
3. Если в staged есть файл **вне** твоего scope → ⛔ СТОП: это либо твоя ошибка scope, либо staged другой сессией. Коммить через pathspec только свои файлы, чужие оставить.
   - `git diff --cached` пуст / git недоступен → graceful skip (нет staged — нечего проверять).

**Few-shot (антипример a17ecc1, 2026-06-06):** агент сделал `git add iteration-watchdog.py` + `git commit` — но параллельная сессия уже застейджила `push-merge.md` + `consumer-push.sh` + VERSION → `git commit` (без pathspec) захватил **весь** индекс → чужая работа смешалась в один коммит. Правильно было: `git commit templates/.claude/hooks/iteration-watchdog.py -m "..."` (только свой файл).

> **NB:** работает при любом `worktree_isolation`. При `auto` отдельный индекс per worktree уже изолирует; при `off` (default) — pathspec единственная защита от index-capture.

---

## Шаг 3 — Анализ первопричины (при баге)

1. Воспроизвести → минимальный тест-кейс
2. Найти корень: данные / логика / контракт / конфигурация?
3. **Не маскировать симптом:** запрещены `try/except: pass`, `?? null` без обоснования
4. Если причина в другом сервисе → СТОП, OPEN-QUESTIONS.md

---

## Шаг 4 — Self-review

**Lite mode (2 точки):**
1. Границы модуля — нет ли логики чужого домена?
2. Безопасность — нет утечек, нет хардкода

**Full mode (11 точек):**
1. Границы модуля
2. Владение данными (data-map)
3. События/контракты — Outbox/idempotency
4. Безопасность + audit
5. Type/Schema constraints используются
6. Миграции безопасны (rollback)
7. **External state checklist** (D2: какое состояние я не контролирую?):
   - [ ] Внешний API доступен? (что при quota exceeded, network error, 5xx?)
   - [ ] Версия зависимости стабильна? (что если major version меняется?)
   - [ ] OS/environment состояние (case sensitivity FS, permissions, etc.)?
   - [ ] Кеши (browser, CDN, Redis) стабильны или могут быть stale?
   - [ ] Concurrency — есть race conditions если 2 процесса одновременно?
   - Для каждого: явно описать "если это не true — что сломается?"
8. **Adjacent impact актуален:** смежные зоны из /plan Шаг -1.3 проверены? Если был затронут методологический артефакт (ARTIFACT-MAP и т.п.) — полный аудит всех стрелок/секций, не только изменённых *(closes G-001)*
9. **Mermaid изменён:** авто-обновить ссылки + валидировать. **Сначала определи структуру репо** (closes G-076):

   **⛔ Placeholder-check (closes G-086):** перед запуском `update-mermaid-links.sh` — проверить нет ли строк-placeholder в map-файлах которые ты только что записал:
   ```bash
   grep -rn "_(ссылка: запусти" docs/architecture/ docs/product/ 2>/dev/null
   ```
   - Найдены строки → проверить каждый mermaid-блок под placeholder:
     - Блок содержит `TODO:` → placeholder **корректен** (диаграмма не заполнена), пропустить
     - Блок **не содержит** `TODO:` → ⛔ БЛОК: `update-mermaid-links.sh` заменит placeholder реальным URL — запусти его прямо сейчас и убедись что URL появился. Не оставлять `_(ссылка: запусти...)_` в committed файле с заполненной диаграммой.
   - Нет hits → продолжить.

   **Почему:** `post-edit-watchdog.py` автоматически запускает скрипт при Edit/Write с mermaid. Но если хук не сработал (старая methodology, ручное редактирование, Write без mermaid в `new_string`) — placeholder остаётся как текст. Этот check — fallback-защита.

   - Прочитать `CLAUDE.local.md ## Auto-update → doc_repo_path`.
   - **`doc_repo_path: null` (single-repo, default):** артефакты локальны:
     ```bash
     bash scripts/update-mermaid-links.sh
     bash scripts/validate-mermaid-links.sh
     ```
   - **`doc_repo_path: <путь>` (two-repo):** обновить ОБА — локальный + doc-репо:
     ```bash
     bash scripts/update-mermaid-links.sh --root <doc_repo_path>
     bash scripts/update-mermaid-links.sh
     bash scripts/validate-mermaid-links.sh --root <doc_repo_path>
     bash scripts/validate-mermaid-links.sh
     ```
   MISSING_LINK или STALE_LINK после update = блок до ручного фикса.
10. **Изменён артефакт-инструкция** (CLAUDE.md, карты, runtime-промпт бота/агента): запустить `bash scripts/validate-artifact-size.sh` (two-repo — также `--root <doc_repo_path>` из `CLAUDE.local.md`). `SIZE_EXCEEDED` или `PROMPT_BLOAT` = 🔵 Recommendation → разобрать в /review (размер vs оправдано; плотность запретов душит ли tools). Не блок, но не игнорировать.
11. ⛔ **[methodology] Формат артефакта изменён** — «формат» = новый паттерн ссылок / placeholder'ов / секций / Mermaid URL-стиля в картах или командах. **Нет понятия "незначительный"** — любое изменение формата обязательно применяется к шаблонам.
    ```bash
    grep -r "<старый паттерн>" templates/
    ```
    - Несоответствие найдено → ⛔ **БЛОК до исправления шаблона в этом же PR**. Продолжить без исправления = нарушение.
    - Соответствующего `templates/*.template.md` нет → явный `[N/A — шаблон не существует: <причина>]`.
    *(closes G-068)*

    **Автоматическая проверка (S-026):** запустить после любого изменения команд или templates:
    ```bash
    bash scripts/validate-template-format.sh
    ```
    - `PASS` → ✅ продолжить
    - `FAIL` → ⛔ БЛОК: исправить нарушения до коммита (stale mermaid format, отсутствующие секции, placeholders)

    **Включает Check 6 — delivery-consistency (R-029, L4 enforcement):** для PR трогающих `templates/.claude/hooks/*`, `settings.template.json`, или `scripts/sync-methodology.sh` — `validate-template-format.sh` вызывает `validate-delivery.sh`, проверяя что hook-ref реально доедет до консьюмера через sync (распознаётся `hook_name()` парсером, существует на диске). Закрывает класс v5.12.0 «wired в template, но sync не доставляет» **pre-merge** (раньше ловился только /deploy dogfood post-merge → re-release). FAIL = БЛОК.

Если хоть одна точка не пройдена → исправить до коммита.

---

## Шаг 5 — Документация

**Часть PR (коммитится с кодом):**
- [ ] Если изменилась коммуникация → SYSTEM-MAP.md
- [ ] Если реализовано ADR → обновить статус ADR
- [ ] Если изменились данные → data-map.md
- [ ] Если изменилось поведение → PRODUCT.md
- [ ] Если изменилось количество шагов, точек или числовые параметры → PRODUCT.md данные актуальны?
- [ ] Если изменились пользовательские возможности (новая команда, изменён UX, убрана фича) → USER-MAP.md
- [ ] Если изменился рекомендуемый workflow или prerequisites для возможностей → USER-MAP.md потоки обновлены?
- [ ] Если добавлена/изменена зависимость между компонентами → SYSTEM-MAP.md edges обновлены?
- [ ] **CHANGELOG.md rule:** если PR добавляет новый consumer-facing feature (новый скрипт в templates/scripts/, новая команда, новое правило поведения агента, изменение формата) — добавить запись в `CHANGELOG.md` сверху с: version, title, что добавилось, actions (ordered bash commands), priority (🔴/🟡/🟢). Без этого `/sync-audit` delta analysis не увидит новый feature для consumers.
- [ ] ⛔ **Maps no-exceptions rule (closes G-055):** если PR добавляет новый компонент / edge / capability / шаг в priority chain — SYSTEM-MAP.md + USER-MAP.md + ARTIFACT-MAP.md ОБЯЗАНЫ быть обновлены **в этом же PR**. Нет понятия "незначительный edge — следующий цикл". Единственное допустимое skip: явное `[N/A — причина]` в PR description (например: "text-only change, no new components").
- [ ] Если изменилось поведение команды по отношению к артефактам (новый read/write) → ARTIFACT-MAP.md стрелки обновлены?
- [ ] Если изменились правила AI-агента или рабочего процесса → CLAUDE.md
- [ ] Если `/plan` Шаг 99.54 создал `[DRAFT]` артефакты → финализировать каждый затронутый draft **постоянной карты**:
  ⛔ **НЕ брать draft как основу** — draft содержит только touched scope (~15 nodes) и перезапишет полную карту если использовать его как базу.
  ⛔ **Ad-hoc «было→станет» (вариант 4 Шага 99.54) НЕ финализируется** — это preview-only эскиз, постоянной карты для него нет. Пропустить.
  1. Прочитать **существующий файл карты целиком** (USER-MAP.md / SYSTEM-MAP.md / ARTIFACT-MAP.md)
  2. Применить изменения из плана к существующей полной карте (добавить/изменить nodes и edges из draft)
  3. **Проверить что финальная карта содержит:**
     - 🗺 USER-MAP: все акторы проекта + все capabilities/flows (в т.ч. незатронутые); полная `subgraph` структура; `style` для всех nodes; потоки ДОЛЖНЫ включать outcome-артефакты (`DEVLOG.md`, `HYPOTHESES.md`, `RISKS.md`, и т.п.) — модель `actor → trigger → flow → outcome-artifact`, не только UI-переходы
     - 🏗 SYSTEM-MAP: все architectural layers + все межслойные edges; Легенда с описанием arrow types
     - 📦 ARTIFACT-MAP: все команды + все артефакты; все edges (R/W/RW/C); `classDef` для всех категорий; Legend subgraph
  4. **Hybrid language self-check** (CLAUDE.md правило): пройти по всем labels nodes и edges финальной карты:
     - Имена файлов / команд / технических identifiers → EN (`CLAUDE.local.md`, `/plan`, `auto-update-watchdog.py`)
     - Названия слоёв / описания поведения / глаголы действий → RU (`Слой хуков`, `читает интервал`, `пишет last_pull`, `вызывает при bootstrap`)
     - ❌ Anti-pattern: `"Hooks Layer"`, `"reads to detect"`, `"writes last_pull"`, `"invokes if bootstrap"` — всё EN, нарушает hybrid правило
     - ❌ Anti-pattern (транслитерация): `"Stanet"`, `"Zapuskaet skript"`, `"dobavlen hook"` — русские слова латиницей НЕ являются RU. Только настоящая кириллица. (НЕ относится к техническим identifiers: `hooks/`, `/plan`, `trigger`)
     - ✅ Pattern: `"🪝 Слой хуков"`, `"читает чтобы определить bootstrap"`, `"пишет last_pull"`, `"вызывает при bootstrap"`
     - Если хоть один label полностью на EN (кроме технических identifiers) → исправить **до** запуска `update-mermaid-links.sh` (закрывает G-049 класс «agent ignores hybrid language rule when generating Mermaid»)
  5. Запустить `bash scripts/update-mermaid-links.sh <file>` → ссылка обновится автоматически
  6. Убрать маркер `[DRAFT]` из ссылки (в /plan Шаг 99.54 — draft ссылка отдельная, файл карты не трогается)

- [ ] Финализация карт завершена (запись в файлы через `update-mermaid-links.sh`). **Показ обновлённых карт пользователю** — переместился в Шаг 6 (предпоследним пунктом, перед self-lint), чтобы ссылки были рядом с финальным `/review` prompt. Здесь — только write/finalize, не display.

**⛔ Frontend DOM verification rule (closes retro R-B — «Playwright как реальная верификация»):**

Если задача затрагивает файлы с расширением `.vue` / `.tsx` / `.jsx` / `.svelte` / `.css` / `.html` — **DOM verification обязательна до commit**. Не «должно работать по коду», а «проверено в реальном браузере».

Trigger по расширению (не только по типу задачи — агент не всегда классифицирует как `[frontend]`):
```
grep -lE "\.(vue|tsx|jsx|svelte|css|html)$" <changed_files_list>
```

**Три допустимых пути верификации (выбрать один):**

1. **Playwright E2E** (рекомендуется если настроен):
   ```bash
   npx playwright test --headed   # или: npx playwright test <spec>
   ```
   Цель: убедиться что компонент рендерится, форма работает, API вызов проходит.

2. **Screenshot через Claude Code** (если Playwright не настроен):
   - Запустить dev server: `npm run dev` / `pnpm dev`
   - Открыть в браузере соответствующую страницу
   - Сделать screenshot → прочитать через Read tool
   - Явно описать что видно в реальном DOM (не в коде)

3. **Explicit skip с причиной** (только в обоснованных случаях):
   ```
   ⚠️ DOM verification skipped: [причина]
      Например: "изменение только в типах TypeScript без render impact"
      Например: "unit тест Vitest покрывает единственную изменённую ветку"
      Например: "CSS-only изменение цвета переменной, визуально проверено вручную разработчиком"
   ```

⛔ **«Написал код → должно работать» без одного из трёх путей выше = шаг не завершён.**

Rationale: frontend задачи в erp показали что реальный DOM — отдельная реальность от кода. Компонент может не рендериться, props не прокидываться, CSS скрывать элемент, API возвращать 422 при реальных данных. Только Playwright/screenshot даёт достоверную верификацию. Методологический принцип: «нельзя говорить "frontend выполнен" без проверки реального DOM» — аналогично "нельзя говорить "секрет установлен" без `check-secret.sh`».

**После деплоя (в /deploy):**
- [ ] Milestone в DEVLOG.md

---

## Шаг 6 — Запрос /review

**Финальный summary пользователю** *(closes G-030):*
- Если задача меняла строки таблицы (Confidence Declaration, ARTIFACT-MAP, USER-MAP, любая markdown-таблица в commands/templates) — показать изменённые/новые строки **целиком с полным содержимым ячеек**, не сокращать ячейки до имён/заголовков
- Brevity vs verification: для табличных артефактов verification важнее. Сокращение убивает суть когда задача = добавить содержимое в ячейку
- Для не-табличных изменений — обычная краткость

**🗺 Показ обновлённых карт пользователю** *(предпоследним перед self-lint и /review prompt — closes display-near-final-artifact pattern):*

После Шага 5 финализации карт (`update-mermaid-links.sh` уже отработал) — вывести список map-артефактов которые этот `/code` реально обновил, со свежими mermaid.live ссылками **и текстовым описанием что изменилось** в каждой карте:

```
🗺 Обновлённые карты (проверь визуально):
- USER-MAP.md → [Открыть в Mermaid Live](<свежий url>)
  Изменения: + нода "Marketing Skills"; ~ связь /plan→draft (теперь "всегда визуализирует"); − удалена нода "Обзор"
- ARTIFACT-MAP.md → [Открыть в Mermaid Live](<свежий url>)
  Изменения: + связь define-positioning ⟶ MARKETING.md (RW)
```

- **Текстовый diff** под каждой ссылкой — это замена визуальной подсветки в самой карте (style-строки хранили бы прошлое состояние). Формат: `+ добавлено`, `~ изменено`, `− удалено`; ноды и связи. Перечислять **все** изменения карты этим `/code`, не сокращать.
- Показывать **только реально обновлённые** карты (не все существующие).
- Если `/code` не менял ни одной карты → одна строка: "🗺 Карты не изменялись."
- URL берётся из обновлённой ссылки в файле (та что только что записал `update-mermaid-links.sh`).

**Размещение (норматив):** этот блок выводится **после финального summary табличных артефактов и перед `<self-lint>`** — рядом с финальным `/review` prompt. Пользователь видит результат `/code` визуально подтверждённым перед тем как одобрить запуск `/review`.

<self-lint>
Lint-1 Параллельные пути: есть ли такая же логика в других файлах не обновлённая? [ответ]
Lint-2 Регрессии: все ветки изменённых хендлеров пройдены? [ответ]
Lint-3 Рамки плана: нет ли изменений вне согласованного? [ответ]
Lint-4 Числовые литералы обоснованы или помечены арбитражными? [ответ]
Lint-5 Локальный vs системный фикс — где зафиксирован архитектурный? [ответ]
Lint-6 External state: какое состояние внешнего сервиса я не контролирую? [ответ]
Lint-7 Summary fidelity: если меняли табличный артефакт — summary показывает строки целиком? [ответ]
</self-lint>

✅ Self-lint passed

⚠️ "Запустить /review? (y / n)"

- **Lite mode:** можно пропустить
- **Full mode:** настоятельно рекомендуется
- **[security] / [data] / [contract]:** ОБЯЗАТЕЛЬНО

При пропуске → инкремент `skipped_warnings.review_skipped` + запись в DEVLOG.

---

⛔ После review жди подтверждения. Не запускай деплой.

---

## Шаг 7 — Обновление state (обязательный финальный шаг после deploy)

После каждого успешного deploy — **обязательно** обновить `.claude/state/triggers.json`:

```json
"last_plan_session": {
  "completed_at": "<ISO8601 текущая дата/время>",
  "task_id": "<id из плана>",
  "service": "<сервис из плана>",
  "mode": "<Lite|Full>",
  "code_run": true,
  "commitments": [ ... обновлённые status ... ]
},
"last_deploy": {
  "date": "<YYYY-MM-DD>",
  "status": "ok",
  "phase": "<краткое описание деплоя>"
}
```

⛔ Пропуск этого шага = счётчики и флаги сессии устаревают → /plan следующей сессии видит `code_run: false` и предлагает вернуться к «незавершённому» плану. *(closes G-063)*

**⛔ Commitment status update (plan→code→review traceability):** прежде чем записать `last_plan_session` — пройти по `commitments[]` (если есть) и обновить `status` каждой записи **по факту реализации** (агент уже знает что сделал в Шаге 2, не отдельный опрос):
- Реализовано → `"status": "done"`.
- Намеренно НЕ реализовано (deferred mid-task, оказалось не нужно, заблокировано) → `"status": "skipped"` + **обязательно** `"skip_reason": "<конкретная причина одной строкой>"`.
- ⛔ Оставить `pending` нельзя если работа закончена — `pending` без причины блокирует merge в `/review` Шаг 3. Если реально не сделал и не знаешь почему — это сигнал вернуться в Шаг 2, не пометить skipped без причины.
- `commitments` отсутствует / пустой (план на старой версии до schema-бампа, или Lite без обязательств) → пропустить тихо.
- Carried-over записи (`carried_over: true`, уже `done` из прошлого re-plan) — не трогать, они уже зачтены.

$ARGUMENTS
