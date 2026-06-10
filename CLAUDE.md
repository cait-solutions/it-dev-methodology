# CLAUDE.md — methodology-platform

Operational rules. Short form. For rationale and history — see [CLAUDE_LONG.md](CLAUDE_LONG.md).

> **Convention:** CLAUDE.md = WHAT (rules). CLAUDE_LONG.md = WHY (rationale, edge cases, examples).

**Project type:** `methodology-platform` — особый. Это продукт методологии для других проектов. Runtime-проверки неприменимы. Применимы: контракты команд, валидность скриптов, кросс-ссылки артефактов.

---

## Read before work

1. [VISION.md](../it-dev-methodology-documentation/VISION.md) перед каждым `/plan`
2. [PRODUCT.md](../it-dev-methodology-documentation/PRODUCT.md) — что методология обещает консьюмерам
3. [SYSTEM-MAP.md](../it-dev-methodology-documentation/docs/architecture/SYSTEM-MAP.md) — связи компонентов
4. [USER-MAP.md](../it-dev-methodology-documentation/docs/product/USER-MAP.md) — пользовательские потоки и capabilities
5. [ARTIFACT-MAP.md](../it-dev-methodology-documentation/docs/product/ARTIFACT-MAP.md) — артефакты и их владельцы

> **Two-repo architecture:** `it-dev-methodology/` = код (commands/, templates/, skills/, scripts/). `it-dev-methodology-documentation/` = документация (VISION.md, PRODUCT.md, DEVLOG.md, ROADMAP.md, IDEAS.md, AGENT-GAPS.md, PRODUCT-GAPS.md, docs/architecture/, docs/product/, docs/adr/). При поиске любого из этих файлов — искать в `../it-dev-methodology-documentation/`, НЕ в корне methodology repo. Closes G-071.

---

## Architecture invariants (MUST / MUST NOT)

Методология = 6 слоёв (см. [SYSTEM-MAP.md](../it-dev-methodology-documentation/docs/architecture/SYSTEM-MAP.md)): команды / шаблоны / хуки / агенты-скелеты / скрипты / **skills** (Agent Skills, knowledge-domain).

**MUST:**
- `commands/`, `templates/`, `templates/.claude/hooks/`, `templates/.claude/agents/`, `skills/` — единственный источник правды (синхронизируются консьюмерам)
- `commands-local/` — methodology-only команды (НЕ синхронизируются консьюмерам; пример: `/pull-consumers`)
- Любая правка синхронизируемого артефакта → bump VERSION
- При **breaking** изменении схемы `triggers.json.template` (удаление / переименование поля, смена типа) → мажор bump + migration инструкция. **Аддитивное** изменение (новое опциональное поле, читаемое через `.get(...) or default`) → minor bump — `merge_triggers_json` дозаливает поле, existing values preserved, старый consumer не падает (graceful read). Критерий: «сломается ли consumer с pre-change triggers.json?» да → major, нет → minor.
- `skills/*/SKILL.md` — YAML frontmatter MUST быть на строке 1; banner идёт в `metadata:` блок, НЕ как HTML-комментарий сверху (Agent Skills spec: frontmatter на line 1 обязательно)

**MUST NOT:**
- ❌ Редактировать `.claude/commands/*.md` напрямую — это банер-prefixed копии; канон в `commands/`
- ❌ Редактировать `.claude/skills/*/SKILL.md` напрямую — копии с `{{SYNCED_AT}}`; канон в `skills/`
- ❌ Удалять команды без мажор bump VERSION + migration инструкция (breaking)
- ❌ Использовать bash 4-features (`${var,,}`, associative arrays) — Git Bash на Windows ставит 3.2
- ❌ Дублировать контент между шаблонами
- ❌ Класть команду которая должна попадать к консьюмерам в `commands-local/` (правило: shared → `commands/`, methodology-only → `commands-local/`)
- ❌ Менять `sync-methodology.sh` / `new-project-init.sh` итерацию команд на recursive (`find`, `**/*.md`) без явного exclude `commands-local/`

Rationale: [CLAUDE_LONG.md § Architecture](CLAUDE_LONG.md).

---

## Stack

- **Скрипты:** Bash 3.2+ (Git Bash on Windows)
- **Хуки:** Python 3.10+
- **Шаблоны:** Markdown + JSON + YAML
- **CI/CD:** ручной push в GitHub
- **Деплой:** `git push origin main`; consumers подтягивают через `sync-methodology.sh`

---

## Data ownership (short)

| Слой | Источник правды | Кто пишет | Инвалидация |
|---|---|---|---|
| `commands/*.md` | да | владелец | при правке + push |
| `templates/*.md` | да | владелец | при правке + push |
| `templates/.claude/hooks/*.py` | да | владелец | при правке + push |
| `templates/.claude/agents/*.template.md` | да | владелец (структура); консьюмер (тело) | при правке + push |
| `skills/*/SKILL.md` | да | владелец | при правке + push |
| `VERSION` | да | владелец | при ручном bump |
| `.claude/` (этот репо) | нет (производное) | `sync-methodology.sh .` | при self-sync |
| Консьюмер `.claude/commands/*.md` | нет (производное) | `sync-methodology.sh` | при sync |
| Консьюмер `.claude/skills/*/SKILL.md` | нет (производное) | `sync-methodology.sh` | при sync |

Full table with examples and trade-offs: [CLAUDE_LONG.md § Data map](CLAUDE_LONG.md#карта-данных-полная).

---

## Don'ts

- ❌ Не редактировать `.claude/commands/*.md` напрямую (банер-prefixed копии)
- ❌ Не удалять команды без мажор bump + migration
- ❌ Не ломать `methodology-platform` плейсхолдер
- ❌ Не использовать bash 4+
- ❌ Не коммитить `.claude/settings.local.json`
- ❌ Не дублировать контент между шаблонами
- ❌ Не использовать project-specific имена в templates (canon + consumers должны быть абстрактны; примеры в comments только)

---

## Workflow rules

**Command-first invariant (первичная персона = AI engineer):** целевой пользователь методологии — **AI engineer**, который оркеструет AI через **команды и skills** (PRODUCT.md «Целевые пользователи»). Скрипты **не скрыты и доступны** — но это **внутренняя реализация**, не пользовательский путь. Правило:
- ❌ НЕ рекомендовать пользователю «запусти `bash scripts/...`» как действие. Направлять на **команду** (`/sync-audit`, `/deploy`, `/secrets`, …). Скрипт упоминать только как «что команда делает внутри».
- ✅ **Архитектуру взаимодействия выстраивать через команды:** новая операция доступная консьюмеру ОБЯЗАНА иметь command/skill точку входа. Если операция требует ручного `bash scripts/X.sh` от пользователя → это gap, обернуть в команду. Скрипт = как, команда = интерфейс.
- ✅ Исключение: **владелец методологии** (this repo) при разработке самой методологии запускает скрипты напрямую (сопровождение, не consumer-path). Внутри команд агент тоже вызывает скрипты — это реализация. Запрет узкий: не инструктировать **консьюмера** запускать скрипт вместо команды.

**Implementation through /code:** после `/plan` — реализация через `/code`. Прямая правка нетривиальных изменений запрещена.

**Commit-discipline (parallel-safe):** коммить через explicit pathspec — `git commit <пути> -m`, НЕ `git add <file>` + bare `git commit`. Bare commit коммитит **весь staging-индекс**, включая файлы застейдженные параллельной сессией → захват чужой работы (инцидент a17ecc1). Перед commit: `git diff --cached --name-only` → staged ⊆ `/plan` Шаг 1 scope. Деталь: [/code Шаг 2](commands/code.md), [ADR-002 § Index-capture](../it-dev-methodology-documentation/docs/adr/ADR-002-branching-mode-contract.md).

**Deploy branch tracing (F5):** Деплой через `/deploy` команду выполняется на ветке `ai-dev` (или другой designated для agent deploys) чтобы различить agent-automated от manual human work. Team collaboration: git log показывает "commit by Claude on ai-dev" vs "commit by John on feature/auth". Это важно для audit trail и regression tracking.

**Deploy rule:** "деплой" = `git push origin main`. Перед каждым push:
1. `/review` если не запускался
2. DEVLOG запись `[deploy]` / `[feat:X]` / `[fix:X]` / `[methodology]`
3. Bump VERSION если изменены команды / шаблоны / хуки

**Architecture decision rule:** новая команда / шаблон / изменение `triggers.json` схемы → запустить `architect` sub-agent. Сначала собственная рекомендация, потом architect.

**Fix rule:**
- Симптом или причина? Симптом → найди причину
- Локальный или системный? Локальный без обоснования = красный флаг

**Completeness rule:**
Каждое решение (в /plan, /code, /review, /deploy) ДОЛЖНО явно указать:
- Что закрывается (main path, happy cases)
- Что НЕ закрывается (gaps, edge cases, параллельные пути)
- Почему эти gaps OK или требуют дополнительных шагов
Без этого анализа → план не утверждён, код не merged, деплой не выполнен.

**Sustainment rule (closes G-099 class):** Каждый Full `/plan`, создающий или меняющий механизм/артефакт, **обязан** выполнить Шаг 97 Sustainment Declaration и вывести пользователю отдельную секцию **«## Жизнеобеспечение (Sustainment)»** с per-артефакт таблицей: Trigger · Refresh · Detection · Owner. «❌ НЕТ» в ячейке без шага/commitment в плане → Self-Lint не passed. `/review` gate: новый механизм в diff без `sustainment[]` в triggers.json → 🔴. Детали: [/plan Шаг 97](commands/plan.md).

**HIGH risks action rule:** Если `RISKS.md` существует — `/plan` pre-flight проверяет open HIGH severity риски без запланированного фикса. Любой HIGH риск старше 14 дней без связанного /plan → агент показывает его до начала анализа. Закрывает паттерн «долгого пути»: баг найден → записан в RISKS.md → лежит в backlog без action неделями. Если `RISKS.md` отсутствует → пропустить тихо.

**Frontend DOM verification rule:** Любая задача затрагивающая файлы `.vue` / `.tsx` / `.jsx` / `.svelte` / `.css` / `.html` — верификация реального DOM обязательна до commit. Три допустимых пути: (1) Playwright E2E тест запуск, (2) screenshot через Claude Code + Read tool с явным описанием что видно в DOM, (3) explicit skip с письменной причиной. «Написал код → должно работать» без одного из трёх = шаг не завершён.

Rationale and historical examples: [CLAUDE_LONG.md § Workflow rules](CLAUDE_LONG.md).

---

## Regulator levels (Level-4 framework)

Strong → weak: Schema constraint > No alternative path > Input structure > Few-shot > Description > Prompt rule.

При добавлении правила → спросить "есть ли level-4+ структурный фикс?". Если да — primary, правило secondary.

Пример: defensive `triggers.json` чтение в командах = level-1. Level-4 — единая схема в `templates/triggers.json.template`.

Details: [CLAUDE_LONG.md § Level-4 framework](CLAUDE_LONG.md).

---

## Model tier rule

Каждая команда методологии MUST содержать секцию `## Рекомендуемая модель` (5 полей: Default tier / Upgrade / Downgrade / Mid-task escalation / Pre-flight model check).

Канон: [.claude/model-tiers.md](.claude/model-tiers.md). При добавлении новой команды → добавь строку в матрицу + секцию в command-файл; `/review` блокирует merge без обеих.

Pre-flight check **спрашивает пользователя** о текущей модели (не self-detect — system prompt unreliable). Подтверждённое значение переиспользуется в сессии.

Когда Anthropic переименовывает модели — обнови **только** Mapping таблицу в `model-tiers.md`.

Details: [CLAUDE_LONG.md § Model tier rule](CLAUDE_LONG.md).

---

## Mermaid link rule

При каждой записи или обновлении ` ```mermaid ` блока в артефакте — **автоматически** обновить ссылку:

```bash
# Авто-обновление всех ссылок в documentation repo (предпочтительно):
bash scripts/update-mermaid-links.sh --root ../it-dev-methodology-documentation

# Авто-обновление конкретного файла:
bash scripts/update-mermaid-links.sh ../it-dev-methodology-documentation/docs/product/USER-MAP.md

# Ручная генерация URL для одного файла (если скрипт недоступен):
py scripts/mermaid-link.py <file>
```

Ссылка — дополнение к коду диаграммы, не замена. Self-hosted: изменить `BASE_URL` в `scripts/mermaid-link.py`.

**Формат над каждым mermaid-блоком** (вставляется автоматически скриптом):

```
https://mermaid.live/edit#pako:...
```

Голый URL на отдельной строке без обёрток. Ctrl+Click открывает в браузере (VSCode auto-linkify), тройной клик выделяет **только** URL для копирования.

**Одна диаграмма — одна ссылка.** Разбивать на mini + full запрещено: дублирование и путаница.

**⛔ pako-URL НЕ проходит через генерацию модели (G-100):** модель не выводит pako-строки в чат — ни целиком, ни частично. Причина: токен-за-токеном транскрипция 1200+ символов base64 не гарантирует точность — один искажённый символ рушит zlib-поток (доказано: index 71, `X`→`W`). Единственный валидный путь: `update-mermaid-links.sh` пишет URL прямо в файл → агент даёт в чат `[filename:line](path#Lline)` ссылку → пользователь Ctrl+Click по URL внутри файла. Это дополняет G-085 cite-gate (origin) осью fidelity.

**Авто-обновление (two-repo):** для methodology-platform — выполни ОБЕ команды:
- `bash scripts/update-mermaid-links.sh` — methodology repo
- `bash scripts/update-mermaid-links.sh --root ../it-dev-methodology-documentation` — documentation repo

**Валидация:** `bash scripts/validate-mermaid-links.sh [--root DIR]`
Exit 1 = MISSING_LINK или STALE_LINK. Для single-repo проектов — только одна команда.

---

## Maps Standard Rule

Единый стандарт написания и поддержания **views** (карт и связанных артефактов) проекта. Основан на **arc42 multi-viewpoint** + Living Documentation principles + **C4-inspired diagram discipline** (нотация, не таксономия).

> **Точность модели (исправлено по methodology-audit):** три основные карты — это **arc42-style viewpoints** (ортогональные плоскости одной системы), НЕ C4 zoom levels (C4 = один axis granularity: Context→Container→Component→Code). Раньше CLAUDE.md ошибочно заявлял «основан на C4» — наша таксономия ближе к arc42 / 4+1 (Kruchten) views. C4 берём только для **дисциплины диаграмм внутри SYSTEM-MAP** (уровни детализации), не для разделения карт.

### 1. Полный набор views (6, не «3 карты»)

**Living maps (3 — обновляются регулярно, под Maps Standard ниже):**

| Карта | Viewpoint (4+1/arc42) | Отвечает на вопрос | Читает | Пишет |
|---|---|---|---|---|
| **SYSTEM-MAP** | Logical + Development | Как устроена система продукта? Первичны продуктовые сервисы/модули (OrderService, PartyService, CatalogService и т.п.); инфраструктура — вторичный слой. | Developer, /architecture-audit | Developer + /code при структурных изменениях |
| **USER-MAP** | Scenarios | Что умеет пользователь? | Developer, /product-check, /onboard | Developer + /code при новых capabilities |
| **ARTIFACT-MAP** | Data-lineage | Какой документ описывает эту часть продукта, кто его владелец и когда он устаревает? Первичны продуктовые артефакты (orders.md, parties.md, flows.md); методологические (DEVLOG, triggers.json) — вторичный слой. | /review, /retro, Developer | Developer при добавлении продуктового или методологического артефакта |

**Supporting views (3 — существуют, обновляются по событию, НЕ living maps):**

| View | Viewpoint | Когда обновляется | Файл |
|---|---|---|---|
| **roadmap-view** | Temporal/Priorities | Что и в каком порядке строить? Status-карта: Now/Next/Considered/Hold | Developer, /product-review, /product-vision | Developer после /product-review, /product-vision, /plan (при добавлении/закрытии узлов) |
| **data-map** | Process/data flow | при изменении хранилищ/схемы данных | `docs/data-map.md` (если есть runtime-данные) |
| **ADR catalog** | Decisions (arc42 §9) | при принятии/superseding решения | `docs/adr/` + `README.md` каталог |
| **threat-model** | Trust-boundary | на `[security]` планах | `docs/threat-model-*.md` (instantiate из template) |

**Dependency direction:** SYSTEM-MAP ← USER-MAP ← ARTIFACT-MAP. Обратные ссылки = circular reference, запрещено. Нет дублирования фактов между views — cross-reference вместо копирования.

**Слепое пятно (methodology-audit finding):** текущий набор НЕ покрывает **Temporal/Sequence viewpoint** (порядок: `/plan→/code→/review→/deploy`, порядок хуков PreToolUse→PostToolUse→Stop). Карты показывают *кто что делает*, не *в каком порядке*. Ordering-баги (sync до merge, hook-reordering) структурно невидимы. Кандидат на 7-й view — добавляется только при подтверждённом ordering-инциденте (anti-over-engineering: не добавлять для теоретической полноты).

### 2. Обязательная структура каждой карты

```
# [ТИП] — {{Project Name}}
**Версия:** vX.Y  |  **Обновлён:** YYYY-MM-DD  |  **Граф проверен:** YYYY-MM-DD

## Agent TL;DR      ← 5-15 строк, scan-friendly (подсистемы, источники правды, gaps)
## [Диаграмма]      ← Mermaid с URL выше
## [Таблицы]        ← полный реестр компонентов/capabilities/артефактов
## Refresh Policy   ← когда обновлять + когда НЕ обновлять
```

### 3. Правила диаграммы

**Mermaid-only.** ASCII art, PlantUML — запрещены.

**Гибридный язык:** технические термины/файлы/команды — EN; описания поведения/аннотации — RU.
❌ Транслитерация кириллицы латиницей (`"Stanet"`, `"Zapuskaet"`, `"dobavlen"`) — нарушение: это НЕ является RU. Только настоящая кириллица.
Пример: `Workflow["🔄 Workflow Cycle<br/>/plan → /code → /review → /deploy"]`

**Детализация:**
- Отдельный нод = уникальные связи (читает/пишет иначе чем соседи)
- Группа-blob = одинаковые связи → один нод, label через `·`
- Диаграмма ~15-20 нодов (обзор). Детали — в таблице.
- ⛔ Не дублировать в диаграмме то что уже полностью в таблице

**Группировка по доменам** (не по типу): `subgraph SecretsSkills` + `subgraph MarketingSkills` — раздельно, не `subgraph AllSkills`.

**Repo/setup контекст обязателен в USER-MAP** — показать откуда берутся команды/шаблоны если внешний repo.

**Типы стрелок (единообразно):** `-->` W · `-.->` R · `===` RW · `--o` git · `--x` C · `==>` agent-write

**Класс `affordance` — навигационные узлы (НЕ модельные компоненты):** карта = «что ЕСТЬ» (arc42 viewpoint). Узел, который говорит о **месте карты в workflow** (а не утверждает что компонент существует в системе) — навигационный affordance, а не scope-claim. Примеры: `📋 Отложенный scope → /scope-out`, Workflow-Cycle, Legend, repo/setup-контекст. Помечать стилем:
```
classDef affordance fill:#3b0764,stroke:#a855f7,color:#f3e8ff,stroke-dasharray:4 3
NodeID["📋 Отложенный scope → /scope-out"]:::affordance
```
- **Зачем класс, не просто стиль:** `/architecture-audit` Шаг 3 исключает узлы класса `affordance` из phantom/drift-сравнения по **классу** (не по ID — ID-whitelist = slope). Affordance не имеет code-counterpart by design → без класса аудит ложно флагует его как phantom.
- **Граница:** affordance ≠ deferred-компонент. ❌ НЕ добавлять в living maps узлы «planned/deferred component» (ломает «карта = что ЕСТЬ», даёт ложный drift). Отложенный scope визуализируется **отдельно** через `/scope-out` (эфемерно), а в карте присутствует только **навигационный anchor** к нему. Closes P-002.

### 4. Правила таблиц

Таблицы = полный реестр (каждый компонент — отдельная строка).

**Taxonomy триггеров:** `🔁` каждый цикл · `📊` по счётчику · `🔭` стратегический · `⚡` по событию

**Taxonomy акторов:** Developer · PM/Owner · System · External · AI Agent

### 5. Governance

**PR-coupling:** обновить карту в том же PR что и изменение. Рефакторинг без поведенческих изменений, performance-fix, typo — не обновлять.

**In-progress signal (closes assumption-gap класс «тихое перетирание»):** незакоммиченные изменения в файлах связанных с блоком карты (SYSTEM-MAP, USER-MAP, ROADMAP.md и т.п.) — сигнал что над этим блоком активно работают. Перед правкой карты → `git status` + `git diff --name-only`. Если обнаружены незакоммиченные файлы связанного блока — не перезаписывать, спросить пользователя (merge или сначала закоммить текущие?). Иначе риск потери незавершённой работы параллельной сессии.

**Audit schedule:** SYSTEM-MAP `/architecture-audit` ≥5 планов · USER-MAP `/product-check` ≥5 · ARTIFACT-MAP `/retro` ≥15.

**`/review` блокирует merge если:**
1. SYSTEM-MAP или USER-MAP изменены и Mermaid удалён
2. Новый разработчик не поймёт структуру из диаграммы
3. Новая команда/skill/артефакт добавлена — карта не обновлена

---

## DEVLOG теги

`[fix:component]` `[feat:command]` `[feat:template]` `[feat:hook]` `[feat:script]` `[methodology]` `[process:X]` `[milestone]`

`[test-found:category]` — баг найден тестированием (`/test`, Playwright, Schemathesis, прод). `category` = `frontend-visual` / `frontend-logic` / `backend-contract` / `backend-crash` / `regression` / `perf` / … (открытый список, см. `skills/testing-strategy`). **Указатель**, не замена: сам баг + статус ведутся в `CODE-GAPS.md` (регистр), fix-событие дублируется `[fix:component]` (сохраняет QB3 regression-grep `/review`). Closes testing layer Phase 1.

Phase-теги: `[phase-a]` … — milestone history.

Команды методологии: `[architecture-audit]` `[sync-vision]` `[retro]` `[diagnose]` `[product-vision]` `[product-review]` `[product-check]`

**Semantic tagging rule (D6):** Проблемы categorize семантически, не по surface name.

Одна проблема — один semantic indicator, даже если люди называют по-разному:
- `[git-failure]` — не `[git_push-failed]` ИЛИ `[github-error]` ИЛИ `[branch-push-issue]` (все sync failures)
- `[async-failure:operation]` — не `[vault-sync-error]` И `[queue-dropped]` (оба fire-and-forget failures)
- `[state-pollution]` — не `[history-leak]` И `[cache-contamination]` (оба внутренние состояния)

**Reason:** Regex-based detection fails когда люди называют одно разными именами. Semantic category stays stable.

---

## Security: real threats

**Утечка GitHub PAT и других токенов (was High → Mitigated):** Структурно закрыто секцией [Secrets & Credentials](#secrets--credentials) — 4 слоя защиты (gitignore, pre-commit hook, /review detector, tool deny). См. ниже.

**Прямой push в main (High):** Branch protection не настроен. Будущая задача — required PR + review.

**Drift между методологией и консьюмерами (Med):** Sync ручной. Будущая задача — auto version-drift check в `/plan` Шаг -3.

**Sync overwrites local fills (Low):** `docs_reminder.py` LIBS заполняется per-project. Будущая задача — поддержка `*.local.py` соседних файлов.

Details with mitigation scenarios: [CLAUDE_LONG.md § Security threats](CLAUDE_LONG.md).

---

## Secrets & Credentials

> **Phase 1 / v4.32.0:** Foundation слой. Phases 2-5 (command integration, full docs/Mermaid, sync rules, consumer migration) — отдельные релизы. Сейчас доступны: templates, scripts core, hooks, tool deny rules.

### Canonical storage

Один источник правды для секретов per проект:

| Источник | Назначение | Прио |
|---|---|---|
| `./.env` | per-project секреты (gitignored, chmod 600) | 1 |
| `~/.config/it-dev/secrets.env` | cross-project shared (опционально) | 2 |
| process env vars | CI/CD compatibility | 3 |

Декларация требуемых секретов: `.claude/secrets-manifest.yaml` (committed, без значений — только names + `how_to_obtain`).

### MUST

- ✅ Использовать `bash scripts/with-secret.sh KEY -- <command>` чтобы передать секрет subprocess'у — значение **не попадает** в stdout агента.
- ✅ Использовать `bash scripts/check-secret.sh KEY` для boolean проверки (exit 0/1, без значения).
- ✅ Использовать `bash scripts/set-secret.sh KEY value` для **одноразового** добавления секрета пользователем (это **пользователь** запускает, не агент).
- ✅ Для git operations с HTTPS — configure `git-credential-from-env.sh` как credential helper (git сам читает токен, агент не в цепочке).
- ✅ При отсутствии required секрета — HARD BLOCK + показать `how_to_obtain` из manifest. Не запрашивать токен через chat — только one-time setup через `set-secret.sh`.
- ✅ **Перед `/secrets` и любым `secrets-*.sh`** — проверить что `.claude/secrets-manifest.yaml` существует в текущем `cwd`. Если нет — найти репо с manifest в workspace и сообщить откуда запускать. Никогда не делать вывод "секреты отсутствуют" только из-за отсутствия manifest в текущем cwd (closes G-065).

### MUST NOT

- ❌ Агент НЕ ЧИТАЕТ `.env` / `secrets.env` напрямую (Read tool / `cat .env` / `head .env` блокируются через `settings.json` deny + `bash_protect.py`).
- ❌ Агент НЕ ВЫПОЛНЯЕТ `env`, `printenv`, `set | grep`, `echo $SECRET_*` — блокируется hook'ом `bash_protect.py`.
- ❌ Агент НЕ ВПИСЫВАЕТ значения секретов в chat / DEVLOG / commit messages / любые файлы. Если случилось — `bash scripts/secrets-scrub.sh` (Phase 2) + rotate token.
- ❌ **Агент НЕ ВЫЗЫВАЕТ `_get-secret-raw.sh`** — этот скрипт выводит значение секрета в stdout → попадает в transcript → Anthropic API. Блокируется `bash_protect.py`. Исключительно для ручного запуска пользователем в терминале вне Claude Code. (closes G-062)
- ❌ **Агент НЕ КОНСТРУИРУЕТ inline env assignment с реальным значением секрета** — паттерн `KEY="secret_value" bash script.sh` виден в tool input → transcript. Использовать `bash scripts/with-secret.sh KEY -- bash script.sh` вместо этого. Блокируется `bash_protect.py`. (closes G-062)
- ❌ Не storage'ить `sensitivity: high` ключи в shared scope (`set-secret.sh --shared` blocked manifest-ом).
- ❌ Не bypass-ить pre-commit hook через `--no-verify` без рукописного обоснования в DEVLOG (`/review` всё равно catch-ит leak).
- ❌ Не editить `templates/.claude/hooks/secrets-guard.py` и `templates/.claude/hooks/bash_protect.py` без понимания whitelist semantics — false negative означает утечку.

### Threat model (краткая)

| Вектор | Защита (слой) | Регулятор |
|---|---|---|
| Случайный `git add .env` | `.gitignore` excludes `.env`, `.env.*` (whitelist `.env.example`) | L4 — отсутствие альтернативного пути |
| Force `git add -f .env` | `secrets-guard.py` PreToolUse блокирует commit | L4 — Schema constraint (hook exit 2) |
| Token в коде | `secrets-guard.py` token-prefix + entropy на staged diff; `/review` detector на PR | L4 + L3 (двойная проверка) |
| Агент читает `.env` любой командой (cat/grep/sed/awk/python -c/node -e/...) | `bash_protect.py` **inverted-match**: любая non-whitelisted команда с `.env` arg блокируется. Закрывает класс bypass'ов, не enumerate-list | L5 — нет alternative path |
| Агент дампит ENV (`env`, `printenv`, `echo $VAR`) | `bash_protect.py` `ENV_DUMP_PATTERNS` блокирует | L5 |
| Агент читает через Read tool | `settings.json` `permissions.deny` для `Read(./.env)` etc | L5 — tool permission |
| Утечка через chat history | `secrets-scrub.sh` (Phase 2) cleanup в `~/.claude/projects/`; ротация токена | L2 — reactive |

### Scope limits (что Phase 1 НЕ закрывает)

Phase 1 защищает **agent-mediated утечки** (через transcript, git commits, file system). Эти векторы остаются **открытыми** и требуют OS/process-level mitigation:

- **`/proc/<pid>/environ` visibility** — `with-secret.sh` injects через env subprocess; другие процессы того же UID могут видеть `environ`. Mitigation: trust local OS boundary; full disk encryption; не запускать untrusted code локально.
- **Core dumps** — содержат full memory с секретами. Mitigation: `ulimit -c 0` в shell init.
- **Verbose process monitoring** (htop с `-S`) — показывает env vars. Mitigation: не запускать с такими флагами на dev машине.
- **Git history** — если секрет уже committed, удаление из HEAD не очищает клоны/бэкапы. Mitigation: rotation токена при провайдере + Phase 2 `secrets-scrub.sh`. **Phase 1 предотвращает попадание в первый коммит**, не лечит existing exposure.
- **CI/CD artifacts** — если CI baking `.env` в images/builds, secrets leak там. Mitigation: mount secrets at runtime, не at build time. Phase 5 skill даст guidance.
- **OS keyring vs `.env`** — `.env` это **default**, не **mandate**. Consumer проекты с enterprise требованиями могут использовать Vault / AWS Secrets / Azure Key Vault через priority chain step 3 (process env): `vault kv get ... | export KEY=VALUE && bash scripts/with-secret.sh KEY -- cmd`. Phase 5 skill документирует integration patterns.
- **Token rotation и audit log** — manual через `set-secret.sh`; auto-rotation requires provider-specific adapters (out of methodology scope). Phase 2 skill даст rotation workflow per common providers (GitHub, Anthropic, AWS).

### Что осталось на Phase 2-5

- `/secrets` команда (audit / setup / list / scrub)
- `secrets-scrub.sh` для cleanup transcripts
- `clone-consumer.sh` через credential helper
- `_get-secret-raw.sh` escape-hatch с `--explicit-stdout` forcing function
- `/code`, `/review`, `/plan` интеграция секций "before any operation requiring secret"
- Skill `secrets-management/SKILL.md` (knowledge-domain)
- SYSTEM-MAP / USER-MAP / ARTIFACT-MAP updates
- `deploy-push.sh` миграция на credential helper
- `pull-consumers.md` миграция

---

## Key files

- [scripts/new-project-init.sh](scripts/new-project-init.sh) — bootstrap (`--with-marketing` flag для skills слоя)
- [scripts/sync-methodology.sh](scripts/sync-methodology.sh) — sync (включает `sync_skills()` для `.claude/skills/`)
- [scripts/deploy-push.sh](scripts/deploy-push.sh) — deploy push (reads mode from CLAUDE.local.md, enforces solo/team pattern)
- [scripts/update-mermaid-links.sh](scripts/update-mermaid-links.sh) — **авто-обновление** mermaid.live URL во всех .md файлах (MISSING/STALE → fresh); URL любой длины
- [scripts/migrate-claude-md.sh](scripts/migrate-claude-md.sh) — Phase G2 split migration helper
- [commands/plan.md](commands/plan.md) — workflow entry point
- [commands-local/pull-consumers.md](commands-local/pull-consumers.md) — **LOCAL-ONLY** команда: pull всех consumer repos из workspace + diff новых methodology-tracked записей (AGENT-GAPS/PRODUCT-GAPS/DEVLOG/etc). НЕ синхронизируется консьюмерам
- [templates/triggers.json.template](templates/triggers.json.template) — canonical state schema
- [templates/model-tiers.md](templates/model-tiers.md) — model recommendation registry
- [templates/AGENT-GAPS.md.template](templates/AGENT-GAPS.md.template) — AI gap capture (consumer artifact)
- [templates/MARKETING.template.md](templates/MARKETING.template.md) — marketing central context (consumer artifact, --with-marketing)
- [templates/.claude/hooks/agent-gaps-watchdog.py](templates/.claude/hooks/agent-gaps-watchdog.py) — Stop hook: admission detector
- [templates/.claude/hooks/post-edit-watchdog.py](templates/.claude/hooks/post-edit-watchdog.py) — PostToolUse hook: после Edit/Write с mermaid-блоком → авто-запуск `update-mermaid-links.sh`. Config в `CLAUDE.local.md ## Post-edit hooks`
- [skills/define-positioning/SKILL.md](skills/define-positioning/SKILL.md) — Agent Skill: positioning framework (12 секций)
- [scripts/with-secret.sh](scripts/with-secret.sh) — **secrets injection** (primary tool): `bash scripts/with-secret.sh KEY -- <cmd>` — значение не в stdout
- [scripts/check-secret.sh](scripts/check-secret.sh) — boolean existence check (exit 0/1, без значения)
- [scripts/set-secret.sh](scripts/set-secret.sh) — atomic write в `.env` (one-time setup пользователем)
- [scripts/validate-secrets.sh](scripts/validate-secrets.sh) — manifest vs `.env` consistency check
- [scripts/git-credential-from-env.sh](scripts/git-credential-from-env.sh) — git credential helper для HTTPS push/pull без агента в цепочке
- [templates/.env.example.template](templates/.env.example.template) — template для consumer `.env`
- [templates/secrets-manifest.yaml.template](templates/secrets-manifest.yaml.template) — declared secrets schema
- [templates/.claude/hooks/secrets-guard.py](templates/.claude/hooks/secrets-guard.py) — PreToolUse: блокирует commit с tokens/staged .env
- [VERSION](VERSION) — semver

**Skills layer:** `skills/*/SKILL.md` — Agent Skills (knowledge-domain, auto-activation). Синхронизируются в `.claude/skills/` через `sync_skills()`. Banner в `metadata:` блоке frontmatter (НЕ HTML-комментарий — YAML frontmatter must be line 1). Workflow-команды (`/plan /code /review /deploy` и др.) остаются slash — это инвариант (VISION Граница 8).

---

## External links

- GitHub: https://github.com/cait-solutions/it-dev-methodology
- Примеры консьюмер-проектов:
  - **Single-developer project** (e.g., solo-dev consumer) — single-tier vision
  - **Multi-service platform** (e.g., team-based consumer) — multi-tier vision, per-service триггеры, inbox, ADR
