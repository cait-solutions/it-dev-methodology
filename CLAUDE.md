# CLAUDE.md — methodology-platform

Operational rules. Short form. For rationale, examples and history — see [CLAUDE_LONG.md](CLAUDE_LONG.md).

> **Convention:** CLAUDE.md = WHAT (rules). CLAUDE_LONG.md = WHY (rationale, edge cases, examples). При добавлении/расширении правила: WHAT (≤~5 строк) сюда, WHY — в CLAUDE_LONG под тем же якорем. Enforcement: `/code` Шаг 5 split-coupling + `validate-artifact-size.sh` (confirmer).

**Project type:** `methodology-platform` — продукт методологии для других проектов. Runtime-проверки неприменимы; применимы контракты команд, валидность скриптов, кросс-ссылки артефактов.

---

## Read before work

1. [VISION.md](../it-dev-methodology-documentation/VISION.md) перед каждым `/plan`
2. [PRODUCT.md](../it-dev-methodology-documentation/PRODUCT.md) — что методология обещает консьюмерам
3. [SYSTEM-MAP.md](../it-dev-methodology-documentation/docs/architecture/SYSTEM-MAP.md) — связи компонентов
4. [USER-MAP.md](../it-dev-methodology-documentation/docs/product/USER-MAP.md) — пользовательские потоки и capabilities
5. [ARTIFACT-MAP.md](../it-dev-methodology-documentation/docs/product/ARTIFACT-MAP.md) — артефакты и владельцы

> **Two-repo architecture:** `it-dev-methodology/` = код (commands/, templates/, skills/, scripts/). `it-dev-methodology-documentation/` = документация (VISION, PRODUCT, DEVLOG, ROADMAP, IDEAS, AGENT-GAPS, PRODUCT-GAPS, docs/). Эти файлы искать в `../it-dev-methodology-documentation/`, НЕ в корне code-repo. (closes G-071)

---

## Architecture invariants (MUST / MUST NOT)

6 слоёв (см. [SYSTEM-MAP.md](../it-dev-methodology-documentation/docs/architecture/SYSTEM-MAP.md)): команды / шаблоны / хуки / агенты-скелеты / скрипты / skills.

**MUST:**
- `commands/`, `templates/`, `templates/.claude/hooks/`, `templates/.claude/agents/`, `skills/` — единственный источник правды (синхронизируются консьюмерам). `commands-local/` — methodology-only (НЕ синхронизируются).
- **Committed derived-layer в консьюмерах** (v7.8.2+): `.claude/commands/`, `.claude/hooks/`, `.claude/model-tiers.md` у консьюмера коммитятся (свежий clone имеет рабочие команды без ручного sync), но остаются derived (канон в `commands/`/`templates/` — не редактировать напрямую). Ignored у консьюмера только runtime-local: `.claude/.version` + `.claude/state/`. Граница: в **самой методологии** `.claude/commands/` gitignored (dogfood-исключение).
- Любая правка синхронизируемого артефакта → bump VERSION.
- Breaking-изменение схемы `triggers.json.template` (удаление/переименование поля, смена типа) → major bump + migration. Аддитивное (новое опциональное поле, `.get(...) or default`) → minor bump.
- `skills/*/SKILL.md` — YAML frontmatter на строке 1; banner в `metadata:` блок, не HTML-комментарий сверху.
- **Dual-copy parity (ADR-014):** файл в `scripts/` И `templates/scripts/` правится синхронно в обе копии в одном PR. Enforcement: `validate-script-parity.sh` (error-gate в `deploy-push.sh`).
- **Schema→skill parity:** capability-поле в consumer-facing schema (`secrets-manifest.yaml.template` и т.п.) обязано сопровождаться апдейтом парного `skills/*/SKILL.md` в том же PR. Enforcement: `validate-schema-skill-parity.sh` (warn, `SCHEMA_SKILL_SEVERITY=error` для блока) + `/review`.

**MUST NOT:**
- ❌ Редактировать `.claude/commands/*.md` / `.claude/skills/*/SKILL.md` напрямую — банер-prefixed копии; канон в `commands/` / `skills/`.
- ❌ Удалять команды без major bump + migration.
- ❌ Bash 4-features (`${var,,}`, associative arrays) — Git Bash Windows = 3.2.
- ❌ Дублировать контент между шаблонами.
- ❌ Класть shared-команду в `commands-local/` (shared → `commands/`, methodology-only → `commands-local/`).
- ❌ Менять итерацию команд в `sync-methodology.sh` / `new-project-init.sh` на recursive без exclude `commands-local/`.

Rationale: [CLAUDE_LONG.md § Architecture](CLAUDE_LONG.md).

---

## Stack

- **Скрипты:** Bash 3.2+ (Git Bash on Windows) · **Хуки:** Python 3.10+ · **Шаблоны:** Markdown + JSON + YAML · **CI/CD:** ручной push в GitHub.
- **Деплой:** агент — `git push origin ai-dev` (через `deploy-push.sh`); merge `ai-dev → main` — владелец (PR / `/push-merge`); consumers подтягивают из `main` через `sync-methodology.sh`.

---

## Data ownership (short)

| Слой | Источник правды | Кто пишет |
|---|---|---|
| `commands/*.md` · `templates/*` · `templates/.claude/hooks/*.py` · `skills/*/SKILL.md` · `VERSION` | да | владелец (при правке + push) |
| `templates/.claude/agents/*.template.md` | да (структура) | владелец (структура) · консьюмер (тело) |
| `.claude/` (этот репо) · консьюмер `.claude/commands|skills/` | нет (производное) | `sync-methodology.sh` |

Full table: [CLAUDE_LONG.md § Data map](CLAUDE_LONG.md#карта-данных-полная).

---

## Don'ts

- ❌ Редактировать `.claude/commands/*.md` напрямую · удалять команды без major bump+migration · ломать `methodology-platform` плейсхолдер · bash 4+ · коммитить `.claude/settings.local.json` · дублировать контент между шаблонами · использовать project-specific имена в templates (canon + consumers абстрактны; примеры только в comments).

---

## Design Spec vs ADR

| Вопрос | Артефакт |
|---|---|
| Архитектурное **решение** (навсегда, с отвергнутыми альтернативами)? | **ADR** (`docs/adr/ADR-NNN-*.md`) |
| **Спецификация** как работает фича/механизм (уточняется)? Аргументация per-requirement + пример? | **Design Spec** (`docs/services/<svc>/<FEATURE>_DESIGN.md`) |

ADR решает → Design Spec описывает детали реализации. Шаблон: `templates/DESIGN_SPEC.template.md`. Skill: `/design-spec` (VCD-протокол). Место: фича одного сервиса → `docs/services/<svc>/`; cross-service → `docs/architecture/`. Детали: [CLAUDE_LONG.md § Design Spec](CLAUDE_LONG.md).

---

## Workflow rules

**Command-first invariant:** целевой пользователь = AI engineer, оркеструющий AI через **команды и skills**. ❌ Не рекомендовать пользователю «запусти `bash scripts/...`» — направлять на команду; скрипт = «что команда делает внутри». ✅ Новая consumer-операция обязана иметь command/skill точку входа. Исключение: владелец методологии запускает скрипты напрямую (сопровождение). Детали: [CLAUDE_LONG.md § Command-first](CLAUDE_LONG.md).

**Implementation through /code:** после `/plan` — реализация через `/code`. Прямая правка нетривиальных изменений запрещена.

**Commit-discipline (parallel-safe):** коммить explicit pathspec — `git commit <пути> -m`, НЕ `git add` + bare `git commit` (bare коммитит весь индекс → захват чужой работы). Перед commit: `git diff --cached --name-only` ⊆ scope. Детали: [/code Шаг 2](commands/code.md), ADR-002.

**Parallel-session rule:** при ≥2 сессиях — `worktree_isolation: auto` в `CLAUDE.local.md`. ⚠️ `auto` НЕ создаёт worktree сам — изоляция требует, чтобы агент/пользователь реально создал worktree (opt-in). Non-worktree floor (две сессии в одном дереве): explicit-pathspec commit (L3) + monotonic VERSION-bump в `deploy-push.sh` (L4) + `merge=union` в `.gitattributes` для append-журналов (L4 для PR-пути). Остаточный same-region риск держит агентская `/code` дисциплина (pathspec + commit-immediately), НЕ человек. `AGENTS.md` = L1 read-and-claim. Детали и regulator-разбор: [CLAUDE_LONG.md § Parallel-session](CLAUDE_LONG.md).

**Deploy branch tracing (F5):** `/deploy` на ветке `ai-dev` — различает agent-automated от manual (audit trail).

**Deploy rule:** «деплой» агента = `git push origin ai-dev` (через `deploy-push.sh`). Merge `ai-dev → main` — владелец (PR / `/push-merge`), не агент. Перед каждым push: (1) `/review` если не запускался; (2) DEVLOG `[deploy]`/`[feat:X]`/`[fix:X]`/`[methodology]`; (3) bump VERSION если менялись команды/шаблоны/хуки.

**Architecture decision rule:** новая команда/шаблон/изменение схемы `triggers.json` → делегировать `architect` sub-agent (сначала своя рекомендация, потом architect). architect/qa/security — on-demand через auto-discovery, не hard-wired конвейер (VISION Граница 8). Детали: [CLAUDE_LONG.md § Architecture decision rule](CLAUDE_LONG.md).

**Opinion canonical practice:** high-stakes планы (новый механизм / breaking change / `[critical]`) — `/opinion` перед `/code` = канонная практика (explicit opt-in, не hard-block). `/plan` Шаг -3 рекомендует автоматически; skip → `skipped_warnings.opinion_skipped` → `/retro` rate.

**Fix rule:** симптом → найди причину. Локальный фикс без обоснования = красный флаг (default — системный).

**Anti-cheat rule (no-gate-weakening):** ⛔ Никогда не ослабляй артефакт/критерий чтобы пройти гейт — меняй измеряемое, не измеритель. Любой гейт (`/review`, `/doc-audit`, `validate-*`, acceptance, тест). Граница: изменить гейт как явное решение с named-обоснованием (гейт был неверным) — допустимо; ради прохождения без обоснования — cheat. Enforcement: `/code` Шаг 3 п.4 + `/review`. Примеры: [CLAUDE_LONG.md § Anti-cheat](CLAUDE_LONG.md).

**Ground-before-act rule:** ПЕРЕД утверждением/действием о структуре / состоянии / версии / cross-repo workflow — прочитать live-источник, не отвечать из памяти или generic-конвенции. Триггеры → что читать:

| Вопрос/действие про… | Прочитать ПЕРЕД ответом |
|---|---|
| структуру / «где что» / setup | USER-MAP + SYSTEM-MAP |
| состояние репо / init | `git ls-remote` + `git log` (не single-clone) |
| VERSION bump / «свободна ли версия» | `git show HEAD:VERSION` + `git log --oneline -3` |
| cross-repo git-инструкция третьей стороне | `git ls-remote --heads origin` |
| «что делает команда/методология X» | актуальный текст `commands/<X>.md` |
| legacy/механизм в design-spec/доке | real code `file:line` |
| «версия актуальна?» у консьюмера | `.claude/.version` vs `VERSION` (drift-таблица `/push-consumers`) |

⛔ «Уверен на N%» без чтения источника = hunch, не evidence → verify-first. Detection: `/retro` + `/architecture-audit` мониторят recurrence_rate по `assumption-gap` (рост ≥0.4 = нужен L4). Детали: [CLAUDE_LONG.md § Ground-before-act](CLAUDE_LONG.md).

**Completeness rule:** каждое решение (/plan, /code, /review, /deploy) явно указывает: что закрывается (happy path) · что НЕ закрывается (gaps, edge cases) · почему gaps OK или требуют шагов. Без этого → план не утверждён, код не merged, деплой не выполнен.

**Sustainment rule:** каждый Full `/plan`, создающий/меняющий механизм, обязан выполнить Шаг 97 Sustainment Declaration + вывести секцию «## Жизнеобеспечение» (Trigger · Refresh · Detection · Owner). «❌ НЕТ» без commitment → Self-Lint не passed. `/review`: новый механизм в diff без `sustainment[]` → 🔴. После /code — строка в `docs/architecture/LIVING-ARTIFACTS.md`. Детали: [/plan Шаг 97](commands/plan.md).

**HIGH risks action rule:** если `RISKS.md` есть — `/plan` pre-flight проверяет open HIGH без запланированного фикса; HIGH старше 14 дней без /plan → показать до анализа. Нет `RISKS.md` → пропустить тихо.

**Frontend DOM verification rule:** задача трогающая `.vue`/`.tsx`/`.jsx`/`.svelte`/`.css`/`.html` — верификация DOM до commit. Три пути: (1) Playwright E2E; (2) screenshot + Read tool с описанием DOM; (3) explicit skip с письменной причиной. «Написал → должно работать» без одного из трёх = не завершено.

**ROADMAP Done-trigger rule:** каждый `/code`, завершающий methodology milestone, добавляет запись в `## Done` в том же PR (planner path — из `## Now`; reactive path — новая строка). Typo/bugfix без milestone → пропустить.

**Recommendation-first rule:** при любом clarifying question — сначала своя рекомендация с обоснованием, потом вопрос. «Не знаю куда» без рекомендации = agent gap. Исключение: вопрос принципиально требует выбора владельца (security/бизнес-приоритет).

**Actor-burden rule:** ⛔ Решение, перекладывающее на **человека** повторяющуюся remembered-обязанность («не забывай делать X»), при наличии агентского/структурного актора — нарушение Ось 1. Дефолт: human-remember = красный флаг → назови агент/структурный актор или обоснуй отсутствие. Освобождены: one-time setup, решения принципиально требующие человека, осознанный opt-in. Enforcement: `/plan` Шаг 1.5 + `/review` eyes-check.

**Research-capture rule:** решение-влияющий вывод (WebSearch или direct-experience + verdict) → предложить `[research:X]` в DEVLOG до конца сессии (закрывает cross-session gap). Incidental — Stop hook детектирует; planned — `/research`. ❌ Не пропускать под «это понятно из контекста».

**Inline `[?]` convention:** маркер `[?]` в тексте → применить Opinion Protocol ([/opinion](commands/opinion.md)): North Star extraction → committed verdict → «Что меня беспокоит». Не давать generic-ответ без VISION-anchor.

**Self-apply rule (methodology-platform only):** `deploy-push.sh` авто-запускает `sync-methodology.sh .` после merge через guard `[ -d commands ] && [ -f scripts/sync-methodology.sh ]` (consumers не имеют `commands/` → guard false → не затронуты).

Rationale и исторические примеры: [CLAUDE_LONG.md § Workflow rules](CLAUDE_LONG.md).

---

## Regulator levels (Level-4 framework)

Strong → weak: Schema constraint > No alternative path > Input structure > Few-shot > Description > Prompt rule.

При добавлении правила → спросить «есть ли level-4+ структурный фикс?». Если да — primary, правило secondary. Пример: defensive `triggers.json` чтение = L1; L4 — единая схема в `templates/triggers.json.template`. Details: [CLAUDE_LONG.md § Level-4 framework](CLAUDE_LONG.md).

---

## Model tier rule

Каждая команда MUST содержит секцию `## Рекомендуемая модель` с 6 полями: Default tier / Extended (effort + thinking) / Upgrade / Downgrade / Mid-task escalation / Pre-flight model check.

**Рекомендации трёхмерны:** любая рекомендация модели — в команде И в любой динамической точке (включая свободный чат) — в формате `tier · effort · thinking`, не только tier. Effort (Low/Medium/High) + Thinking (ON/OFF) — UI-настройки. Дефолты класса + task-shape модификаторы (deep-reasoning/`[critical]` → High+ON; mechanical → Low+OFF): [.claude/model-tiers.md](.claude/model-tiers.md).

Pre-flight check **спрашивает пользователя** о модели (не self-detect). При добавлении команды → строка в матрицу model-tiers.md + секция в файл; `/review` блокирует без обеих. Anthropic renames → обновить только Mapping-таблицу. Детали + few-shot: [CLAUDE_LONG.md § Model tier rule](CLAUDE_LONG.md).

---

## Mermaid link rule

При каждой записи/обновлении ` ```mermaid ` блока — авто-обновить ссылку:

```bash
bash scripts/update-mermaid-links.sh --root ../it-dev-methodology-documentation   # все ссылки doc-repo
bash scripts/update-mermaid-links.sh <file>                                        # конкретный файл
py scripts/mermaid-link.py <file>                                                  # ручная генерация URL
```

- Голый URL (`https://mermaid.live/edit#pako:...`) на отдельной строке над блоком, без `[текст](url)` обёрток. Ссылка — дополнение к коду, не замена. Одна диаграмма — одна ссылка.
- ⛔ **pako-URL НЕ проходит через генерацию модели (G-100):** модель не выводит pako-строки в чат (транскрипция рушит zlib-поток). Только: скрипт пишет URL в файл → агент даёт `[file:line](path#Lline)` → пользователь Ctrl+Click.
- **Two-repo:** выполнить ОБЕ команды (methodology repo + `--root ../it-dev-methodology-documentation`). Валидация: `bash scripts/validate-mermaid-links.sh` (exit 1 = MISSING/STALE).
- **L2 agent-responsibility:** после любого Edit/Write файла с ` ```mermaid ` блоком — агент **обязан** запустить скрипт напрямую (`post-edit-watchdog.py` — страховка, не primary). Скрипт не найден → сообщить явно.

---

## Artifact Storage Rule

> ⚠️ Термин-коллизия: skill `/artifact-design` (built-in) — про HTML-страницы на claude.ai, НЕ про методологические артефакты (DEVLOG, ADR, карты). Ниже — про хранение doc-артефактов.

Где живут артефакты (полная таксономия — в ARTIFACT-MAP):

| Класс | Дом |
|---|---|
| Living-артефакт (DEVLOG, IDEAS, ROADMAP, RISKS, *-GAPS, HYPOTHESES) | корень / `docs/…` |
| Пришло извне (VCD, чужой анализ, дамп) | `inbox/` → `_processed/` |
| Durable-спека (ADR, design-spec, architecture) | `docs/adr` · `docs/architecture` · `docs/services/<svc>/` |
| Research-вывод (verdict) | `DEVLOG.md` строка `[research:X]` |
| Продукт работы (отчёт, аналитика, контент, deliverable) | `work/<stream>/` в **documentation-repo** (не code-repo) |
| Эфемерное (черновик-превью) | scratchpad вне репо / gitignored `_tmp_*` |

**MUST:** продукт работы → `work/<stream>/` (структура папок = живой индекс, не ручной README). Two-repo: `work/` всегда в documentation-repo. Эфемерное не оседает в корне. Research-вывод — строка в DEVLOG, не дублировать в `work/`.
**MUST NOT:** ❌ ad-hoc папки под deliverables (`docs/content/`, корневой `research/`) · разрастание `work/<stream>/` вместо promote в свой documentation-repo · `work/` в code-repo.
**Forward-only (grandfather):** правило для НОВЫХ артефактов; существующие организованные папки (`docs/analysis/`, `docs/design/`, `contracts/`) остаются (git mv порвёт входящие ссылки). Детектор `validate-work-home.sh` сканирует только корневой litter (`-maxdepth 1`). Enforcement: warn в `deploy-push.sh`. Rationale: `work/README.md` + [CLAUDE_LONG.md § Artifact Storage](CLAUDE_LONG.md).

---

## Maps Standard Rule

Стандарт **views** проекта. Основа: arc42 multi-viewpoint + Living Documentation + C4-inspired диаграмм-дисциплина (нотация, не таксономия — карты это ортогональные viewpoints, не C4 zoom levels).

### 1. Полный набор views (6)

**Living maps (3 — обновляются регулярно):**

| Карта | Viewpoint | Вопрос |
|---|---|---|
| **SYSTEM-MAP** | Logical+Development | Как устроена система (продуктовые сервисы первичны, инфра вторична)? |
| **USER-MAP** | Scenarios | Что умеет пользователь? |
| **ARTIFACT-MAP** | Data-lineage | Какой документ описывает часть продукта, кто владелец, когда устаревает? |

**Supporting views (3 — по событию, НЕ living):** roadmap-view (Now/Next/Considered/Hold) · data-map (`docs/data-map.md`) · ADR catalog (`docs/adr/`) · threat-model (`docs/threat-model-*.md`).

**Dependency direction:** SYSTEM-MAP ← USER-MAP ← ARTIFACT-MAP (обратные ссылки запрещены). Нет дублирования фактов — cross-reference. Слепое пятно: Temporal/Sequence viewpoint (порядок команд/хуков) не покрыт — 7-й view только при подтверждённом ordering-инциденте (anti-over-engineering).

### 2. Обязательная структура карты

```
# [ТИП] — {{Project Name}}
**Версия:** vX.Y | **Обновлён:** YYYY-MM-DD | **Граф проверен:** YYYY-MM-DD
## Agent TL;DR      ← 5-15 строк scan-friendly
## [Диаграмма]      ← Mermaid с URL выше
## [Таблицы]        ← полный реестр
## Refresh Policy   ← когда обновлять + когда НЕ
```

### 3. Правила диаграммы

- **Mermaid-only** (ASCII/PlantUML запрещены). URL над блоком: bare URL, вставляется скриптом (L2), не вручную.
- **`diagram-sources` annotation** (G-114): HTML-комментарий перед URL — `<!-- diagram-sources: <type>:<Section> -->`. Типы (enum): `table:` / `list:` / `max-version:` / `axes` / `none`. `validate-maps-coverage.sh --report` проверяет наличие + соответствие (WARN).
- **USER-MAP MUST NOT содержать скрипт-узлы** — только команды (`/cmd`), skills, affordance. Скрипты = внутренняя реализация. Enforcement: `USER_MAP_NO_SCRIPTS="gate"`. Исключение: `Initial Setup` bash-секция (ADR-013).
- **Гибридный язык:** технические термины/файлы/команды — EN; описания поведения — RU. ❌ Транслитерация кириллицы латиницей (`"Stanet"`) — не RU.
- **Формат node-описания (G-121):** компонентная нода = три строки `NodeID["🔹 Имя<br/>Зачем: ≤60 симв<br/>Без него: ≤60 симв impact"]`. Освобождены: affordance-ноды, deferred-кластер. Blob-нода → один общий Зачем/Без них. Enforcement: `NODE_READABILITY_SEVERITY="warn"` + `/review` глазами. Применяется ко всем mermaid-диаграммам (living, draft, design-spec §8, ad-hoc). Few-shot: [CLAUDE_LONG.md § Node format](CLAUDE_LONG.md).
- **Детализация:** отдельный нод = уникальные связи; blob = одинаковые связи (label через `·`). ~15-20 нодов (детали в таблице). Группировка по доменам, не по типу. Repo/setup контекст обязателен в USER-MAP.
- **Типы стрелок:** `-->` W · `-.->` R · `===` RW · `--o` git · `--x` C · `==>` agent-write.
- **Класс `affordance`** — навигационные узлы (не модельные компоненты): `classDef affordance ...` + `:::affordance`. `/architecture-audit` Шаг 3 исключает класс из phantom/drift-сравнения (не ID-whitelist). Граница: affordance ≠ deferred-компонент (не добавлять planned-узлы в living maps — ломает «карта = что ЕСТЬ»; отложенное — через `/scope-out`). Детали: [CLAUDE_LONG.md § affordance](CLAUDE_LONG.md).

### 4. Правила таблиц

Полный реестр (каждый компонент — строка). Триггеры: `🔁` цикл · `📊` счётчик · `🔭` стратегический · `⚡` событие. Акторы: Developer · PM/Owner · System · External · AI Agent.

### 5. Governance

- **PR-coupling:** обновить карту в том же PR. Рефакторинг без поведенческих изменений / performance-fix / typo — не обновлять.
- **Semantic fidelity (ADR-015):** presence узла (валидатор) ≠ верность семантики. Detect+couple, не авто-генерация: (1) PR-couple L3 — `/code` Шаг 4 п.9.5 + `/review`; (2) periodic — `/architecture-audit` Способность D.
- **In-progress signal:** незакоммиченные изменения в файлах блока карты = активная работа. Перед правкой → `git status` + `git diff --name-only`; обнаружены — не перезаписывать, спросить.
- **Audit schedule:** SYSTEM-MAP `/architecture-audit` ≥5 · USER-MAP `/product-check` ≥5 · ARTIFACT-MAP `/retro` ≥15.
- **`/review` блокирует merge если:** (1) SYSTEM/USER-MAP изменены и Mermaid удалён; (2) новый разработчик не поймёт структуру; (3) новая команда/skill/артефакт — карта не обновлена.

Полный rationale (arc42 vs C4, viewpoints): [CLAUDE_LONG.md § Maps Standard](CLAUDE_LONG.md).

---

## DEVLOG теги

`[fix:component]` `[feat:command]` `[feat:template]` `[feat:hook]` `[feat:script]` `[methodology]` `[process:X]` `[milestone]`

- `[test-found:category]` — баг найден тестированием (category: frontend-visual/frontend-logic/backend-contract/backend-crash/regression/perf/…). Указатель; сам баг в `CODE-GAPS.md`, fix дублируется `[fix:component]`.
- `[research:X]` — знание из исследования/опыта. Формат: `[research:<slug>] → <что>: <вывод>. <verdict: viable/not-viable/blocked/confirmed/conditional/unclear>. Source: <url | direct-experience>`. Covers любой research если влияет на решение. Плановое: [/research](commands/research.md).
- `[opinion:X]` — мнение агента VISION-anchored. Формат: `[opinion:<slug>] → <вопрос>: <✅/⚠️/❌/🤷>. <тезис ≤60 симв>`. Только при decision-relevant. Команда: [/opinion](commands/opinion.md).
- Phase-теги `[phase-a]`… — milestone history. Команды: `[architecture-audit]` `[sync-vision]` `[retro]` `[diagnose]` `[product-vision]` `[product-review]` `[product-check]` `[research]` `[opinion]`.

**Semantic tagging rule (D6):** проблемы categorize семантически, не по surface name — одна проблема = один semantic indicator (`[git-failure]` не `[git_push-failed]`/`[github-error]`; `[state-pollution]` не `[history-leak]`/`[cache-contamination]`). Regex-detection ломается когда одно называют по-разному.

**Domain-indicator для `[fix:X]`:** при каждом `[fix:X]` добавляй `[domain:<корень>]` — общий для всех фиксов одного корня (`[fix:consumer-push] [domain:git-push]` · `[fix:deploy-push] [domain:git-push]`). Домены гранулярны по корню (`git-push`/`secrets`/`sync`/`mermaid`), не по слою. `/plan` Шаг -1.3 и `/diagnose` grep'ают по `[domain:X]` → кластер детектится рано. Старые без domain → fallback на точный тег. Детали: [CLAUDE_LONG.md § Domain-indicator](CLAUDE_LONG.md).

---

## Security: real threats

- **Утечка GitHub PAT / токенов (was High → Mitigated):** структурно закрыто секцией [Secrets & Credentials](#secrets--credentials) — 4 слоя (gitignore, pre-commit hook, /review detector, tool deny).
- **Прямой push в main (High → Mitigated v5.43.0):** (1) `setup-branch-protection.sh` (required PR, no force-push); (2) `deploy-push.sh` GH006-классификация → PR-путь. Emergency: `--off --yes` + re-apply. ADR-002.
- **Drift методология↔консьюмеры (Med):** sync ручной; будущее — auto version-drift check в `/plan` Шаг -3.
- **Sync overwrites local fills (Low):** `docs_reminder.py` LIBS per-project; будущее — `*.local.py`.

Mitigation-сценарии: [CLAUDE_LONG.md § Security threats](CLAUDE_LONG.md).

---

## Secrets & Credentials

**Canonical storage** (приоритет): `./.env` (per-project, gitignored, chmod 600) → `~/.config/it-dev/secrets.env` (shared, опц.) → process env (CI/CD). Декларация: `.claude/secrets-manifest.yaml` (committed, без значений).

**MUST:**
- ✅ `bash scripts/with-secret.sh KEY -- <cmd>` — передать секрет subprocess'у (значение не в stdout).
- ✅ `bash scripts/check-secret.sh KEY` — boolean (exit 0/1).
- ✅ `bash scripts/set-secret.sh KEY value` — one-time добавление (запускает **пользователь**).
- ✅ git HTTPS — `git-credential-from-env.sh` как credential helper.
- ✅ Отсутствует required секрет — HARD BLOCK + `how_to_obtain` из manifest (не запрашивать через chat).
- ✅ Перед `/secrets` / `secrets-*.sh` — проверить наличие `.claude/secrets-manifest.yaml` в cwd; нет — найти репо с manifest, не делать вывод «секретов нет» из отсутствия manifest в cwd (G-065).

**MUST NOT:**
- ❌ Агент НЕ читает `.env`/`secrets.env` напрямую (Read/`cat`/`head` блокируются `settings.json` deny + `bash_protect.py`).
- ❌ Агент НЕ выполняет `env`/`printenv`/`echo $SECRET` (блок `bash_protect.py`).
- ❌ Агент НЕ вписывает значения в chat/DEVLOG/commit/файлы (случилось → `secrets-scrub.sh` + rotate).
- ❌ Агент НЕ вызывает `_get-secret-raw.sh` (выводит значение в stdout → transcript; блок `bash_protect.py`; только для пользователя в терминале). (G-062)
- ❌ Агент НЕ конструирует `KEY="value" bash script.sh` (видно в tool input → transcript; вместо — `with-secret.sh KEY -- ...`; блок `bash_protect.py`). (G-062)
- ❌ Не storage'ить `sensitivity: high` в shared scope · не bypass pre-commit hook через `--no-verify` без обоснования в DEVLOG · не редактировать `secrets-guard.py`/`bash_protect.py` без понимания whitelist.

**Threat model + scope limits** (что защищено agent-mediated: transcript / git / fs; что вне scope: `/proc/environ`, core dumps, process monitoring, git history existing exposure, CI artifacts, OS keyring) + Phase 2-5 roadmap: [CLAUDE_LONG.md § Secrets](CLAUDE_LONG.md). External managers (Vault/AWS/Azure) — через priority chain step 3. Skill: `secrets-management/SKILL.md`.

---

## Key files

- **Bootstrap/sync:** [new-project-init.sh](scripts/new-project-init.sh) (`--with-marketing`) · [sync-methodology.sh](scripts/sync-methodology.sh) (вкл. `sync_skills()`) · [deploy-push.sh](scripts/deploy-push.sh) (mode из CLAUDE.local.md) · [update-mermaid-links.sh](scripts/update-mermaid-links.sh) · [migrate-claude-md.sh](scripts/migrate-claude-md.sh).
- **Workflow:** [commands/plan.md](commands/plan.md) (entry point) · [commands-local/pull-consumers.md](commands-local/pull-consumers.md) (LOCAL-ONLY).
- **Schemas/templates:** [triggers.json.template](templates/triggers.json.template) · [model-tiers.md](templates/model-tiers.md) · [AGENT-GAPS.md.template](templates/AGENT-GAPS.md.template) · [MARKETING.template.md](templates/MARKETING.template.md) · [DESIGN_SPEC.template.md](templates/DESIGN_SPEC.template.md) · [LIVING-ARTIFACTS.template.md](templates/LIVING-ARTIFACTS.template.md).
- **Hooks:** [agent-gaps-watchdog.py](templates/.claude/hooks/agent-gaps-watchdog.py) (Stop: admission detector) · [post-edit-watchdog.py](templates/.claude/hooks/post-edit-watchdog.py) (PostToolUse: mermaid autolink) · [secrets-guard.py](templates/.claude/hooks/secrets-guard.py) (PreToolUse: commit block).
- **Secrets scripts:** [with-secret.sh](scripts/with-secret.sh) · [check-secret.sh](scripts/check-secret.sh) · [set-secret.sh](scripts/set-secret.sh) · [validate-secrets.sh](scripts/validate-secrets.sh) · [git-credential-from-env.sh](scripts/git-credential-from-env.sh).
- **Skills layer:** `skills/*/SKILL.md` — Agent Skills (knowledge-domain, auto-activation); синкаются в `.claude/skills/` через `sync_skills()`; banner в `metadata:` frontmatter. Workflow-команды остаются slash (VISION Граница 8). LAR dogfood: [../it-dev-methodology-documentation/docs/architecture/LIVING-ARTIFACTS.md](../it-dev-methodology-documentation/docs/architecture/LIVING-ARTIFACTS.md).
- [VERSION](VERSION) — semver.

---

## External links

- GitHub: https://github.com/cait-solutions/it-dev-methodology
- Примеры консьюмеров: single-developer project (single-tier vision) · multi-service platform (multi-tier, per-service триггеры, inbox, ADR).
