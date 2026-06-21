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
- **Dual-copy parity (ADR-014, closes G-122):** файл существующий И в `scripts/`, И в `templates/scripts/` — правится **синхронно в обе копии** в одном PR (канон = `scripts/`, templates = consumer-delivery). Enforcement: `validate-script-parity.sh` — первый gate в `deploy-push.sh` (error, блок) + ось `/doc-audit`. Намеренные расхождения запрещены (whitelist = slope)
- **Schema→skill parity (closes G-120):** добавление capability-поля в **consumer-facing schema** (`templates/secrets-manifest.yaml.template` и т.п.) ОБЯЗАНО сопровождаться апдейтом соответствующего **knowledge-skill** (`skills/*/SKILL.md`) в том же PR — skill = поверхность авто-активации, которую агент консультирует в runtime. Механизм только в template+validator **невидим агенту** (рекуррент «патч в data-слой, но не в agent-knowledge surface»: type:file v6.4.7 был в validator+template+.gitignore, но `secrets-management/SKILL.md` молчал → агент re-derive'ил с нуля). Enforcement (двухслойный, L3 detect): **`validate-schema-skill-parity.sh`** — deploy-time detector в `deploy-push.sh` (token-presence schema-поле ↔ парный SKILL.md; severity=warn по умолчанию, `SCHEMA_SKILL_SEVERITY=error` для блока; declarative pairs-карта в шапке скрипта) **+** `/review` Schema↔skill parity ось (pre-merge). ⚠️ Это L3 (присутствие токена), не L4 семантика — pure-config / non-agent-knowledge поля допустимо не зеркалить (WARN, не блок)

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

## Design Spec vs ADR

Два типа документации решений. Выбор по одному вопросу:

| Вопрос | Артефакт |
|---|---|
| Это архитектурное **решение** (принято навсегда, с отвергнутыми альтернативами)? | **ADR** (`docs/adr/ADR-NNN-*.md`) |
| Это **спецификация** как именно работает фича/механизм (может уточняться)? | **Design Spec** (`docs/services/<svc>/<FEATURE>_DESIGN.md`) |
| Нужна аргументация per-requirement + пример на каждый пункт? | **Design Spec** |
| Одно предложение «мы решили X потому что Y, отвергли Z»? | **ADR** |

**Совместное использование:** ADR принимает решение → Design Spec описывает детали реализации этого решения. Пример: ADR-009 (разделить Substitution/BOM/Succession) + `SUBSTITUTION_DESIGN.md` (как именно работает механизм замен).

**Шаблон:** `templates/DESIGN_SPEC.template.md` (синхронизируется консьюмерам).
**Skill:** `/design-spec` — интерактивное создание/обновление по VCD-протоколу (Anti-Loss, Draft/Final, аргументация + пример на каждый пункт).

**Место хранения в консьюмер-проекте:**
- Фича одного сервиса → `docs/services/<service>/<FEATURE>_DESIGN.md`
- Cross-service / платформенная → `docs/architecture/<FEATURE>_DESIGN.md`

---

## Workflow rules

**Command-first invariant (первичная персона = AI engineer):** целевой пользователь методологии — **AI engineer**, который оркеструет AI через **команды и skills** (PRODUCT.md «Целевые пользователи»). Скрипты **не скрыты и доступны** — но это **внутренняя реализация**, не пользовательский путь. Правило:
- ❌ НЕ рекомендовать пользователю «запусти `bash scripts/...`» как действие. Направлять на **команду** (`/sync-audit`, `/deploy`, `/secrets`, …). Скрипт упоминать только как «что команда делает внутри».
- ✅ **Архитектуру взаимодействия выстраивать через команды:** новая операция доступная консьюмеру ОБЯЗАНА иметь command/skill точку входа. Если операция требует ручного `bash scripts/X.sh` от пользователя → это gap, обернуть в команду. Скрипт = как, команда = интерфейс.
- ✅ Исключение: **владелец методологии** (this repo) при разработке самой методологии запускает скрипты напрямую (сопровождение, не consumer-path). Внутри команд агент тоже вызывает скрипты — это реализация. Запрет узкий: не инструктировать **консьюмера** запускать скрипт вместо команды.

**Implementation through /code:** после `/plan` — реализация через `/code`. Прямая правка нетривиальных изменений запрещена.

**Commit-discipline (parallel-safe):** коммить через explicit pathspec — `git commit <пути> -m`, НЕ `git add <file>` + bare `git commit`. Bare commit коммитит **весь staging-индекс**, включая файлы застейдженные параллельной сессией → захват чужой работы (инцидент a17ecc1). Перед commit: `git diff --cached --name-only` → staged ⊆ `/plan` Шаг 1 scope. Деталь: [/code Шаг 2](commands/code.md), [ADR-002 § Index-capture](../it-dev-methodology-documentation/docs/adr/ADR-002-branching-mode-contract.md).

**Parallel-session rule (честные regulator-levels — closes «объявили L4, построили L1» класс):** при рутинной параллельной работе (≥2 сессии) — `worktree_isolation: auto` в `CLAUDE.local.md`. ⚠️ **`auto` НЕ создаёт worktree автоматически** — методология не имеет актора, запускающего `git worktree add`; изоляция требует, чтобы агент/пользователь **реально создал worktree** (opt-in, Windows-verified-once). Только при созданном worktree dirty-коллизия невозможна by-construction (отдельные деревья → отдельные копии VERSION/CHANGELOG/DEVLOG → merge через PR).

**Floor для non-worktree случая** (две сессии в ОДНОМ дереве — частый реальный случай):
- `git commit <pathspec>` discipline — **L3** (защищает от multi-file index-capture a17ecc1, НЕ от same-file interleave).
- monotonic VERSION-bump в `deploy-push.sh` — **L4** для version-race (единая точка аллокации на merge; работает через Bash/git, не Edit-tool).
- **`merge=union` в `.gitattributes`** для append-heavy журналов (CHANGELOG, DEVLOG, AGENT-GAPS, PRODUCT-GAPS, IDEAS) — **L4 для separate-branch/PR-пути**: при 3-way merge обе стороны добавленных строк сохраняются by-construction (verified 2026-06-20: union-драйвер держит оба блока, 0 конфликт-маркеров). Работает ТОЛЬКО при true 3-way merge — `deploy-push.sh` использует `gh pr merge --merge` (не squash), драйвер срабатывает. Детект регрессии merge-стратегии: `validate-log-merge.sh` (section-count guard, warn). ⚠️ **Граница:** union покрывает merge **разных веток**; две сессии в ОДНОМ дереве на ОДНОЙ ветке union не покрывает (нет merge) → для этого случая нужен **worktree** (отдельные деревья → отдельные ветки → PR → union держит). Closes G-117 same-file interleave для worktree/PR-пути. /opinion+ council 7/7 2026-06-20: fragment-files отвергнут (assemble-race + index-overcapture + disproportionate при 0 рецидивах) в пользу union.
- ⛔ **Остаётся открытым:** shared-tree same-branch hand-edit + index-capture незакоммиченного файла чужой сессией. By-construction фикс = **worktree** (уже сконфигурирован `worktree_isolation: auto`, но opt-in — реально создавать при ≥2 сессиях). Не «сторожем» (lock-hook отвергнут /opinion+ 2026-06-20: PreToolUse не видит Bash-запись + `session_id` непроверен).
- `AGENTS.md` = prompt-coordination doc (**L1** read-and-claim), НЕ L4-enforcement как ошибочно заявлял ADR-002 (исправлено amendment 2026-06-20).

Consumers: `auto` + **ручное** создание worktree при multi-session. `off` достаточен только при гарантированно одной сессии.

**Deploy branch tracing (F5):** Деплой через `/deploy` команду выполняется на ветке `ai-dev` (или другой designated для agent deploys) чтобы различить agent-automated от manual human work. Team collaboration: git log показывает "commit by Claude on ai-dev" vs "commit by John on feature/auth". Это важно для audit trail и regression tracking.

**Deploy rule:** "деплой" = `git push origin main`. Перед каждым push:
1. `/review` если не запускался
2. DEVLOG запись `[deploy]` / `[feat:X]` / `[fix:X]` / `[methodology]`
3. Bump VERSION если изменены команды / шаблоны / хуки

**Architecture decision rule:** новая команда / шаблон / изменение `triggers.json` схемы → делегировать `architect` sub-agent. Сначала собственная рекомендация, потом architect. **NB:** architect вызывается **on-demand** через Claude Code auto-discovery (frontmatter `description`), не hard-wired обязательный pass — Claude Code делегирует когда уместно. `qa`/`security` суб-агенты доступны, но **только опционально** (например `/review` Шаг 3.5 при `[security]`/`[quality]` gap); фиксированный multi-agent конвейер отвергнут (VISION Граница 8). Rationale + примеры: [CLAUDE_LONG.md § Architecture decision rule](CLAUDE_LONG.md).

**Fix rule:**
- Симптом или причина? Симптом → найди причину
- Локальный или системный? Локальный без обоснования = красный флаг

**Anti-cheat rule (no-gate-weakening, closes no-gate-weakening class):** ⛔ Никогда не ослабляй **артефакт** или **критерий**, чтобы пройти квалити-гейт. Удовлетвори гейт по существу — измеряемое, не измеритель. Применяется к ЛЮБОМУ гейту (универсальный core, не только тесты): `/review`, `/doc-audit`, `validate-maps-coverage`, acceptance-критерий, тест.
- **Домен разработки (пример):** не отключай падающий тест · не правь реализацию только чтобы check позеленел · не over-mock'ай чтобы обойти coverage.
- **Не-dev домены (пример):** не удаляй обязательную секцию артефакта чтобы пройти `/doc-audit` · не ослабляй acceptance чтобы пройти `/review` · не выкидывай узел карты чтобы пройти `validate-maps-coverage`.
- **Граница (легитимно ≠ cheat):** изменить гейт/критерий как явное решение с named обоснованием (гейт был неверным) — допустимо. Изменить ради прохождения без обоснования — cheat.
- Enforcement: `/code` Шаг 3 п.4 (L1 prompt-rule) + `/review` Completeness-check no-gate-weakening класс (L3 detect). Дополняет «Не маскировать симптом» (`/code` Шаг 3) осью «не ослабляй гейт».

**Ground-before-act rule (closes assumption-gap recurrence class — `/architecture-audit` recurrence_rate=0.53, самый высокий из всех категорий):** ПЕРЕД любым утверждением или действием о **структуре / состоянии / версии / cross-repo workflow** — прочитать live-источник, не отвечать из внутренней модели или generic-конвенции. Это **общий L3-регулятор**, обобщающий разрозненные per-command pre-flights (DOM-rule, commit-discipline, cite-gate), которые чинили класс локально → паттерн возвращался на каждой непокрытой поверхности (free-chat, draft-фаза, version bump, инструкции третьей стороне).

Канонические триггеры и обязательная верификация (если хоть один сработал — СНАЧАЛА читать, потом отвечать):

| Если вопрос/действие про… | Прочитать ПЕРЕД ответом | Закрывает |
|---|---|---|
| структуру проекта / «где что лежит» / setup / workspace | USER-MAP + SYSTEM-MAP (always-available canon) | G-109 |
| текущее состояние репо / «репо пустой?» / init | `git -C <repo> ls-remote` + `git log` (не single-clone view) | G-117 |
| VERSION bump / «свободна ли версия» | `git show HEAD:VERSION` + `git log --oneline -3` | G-116 |
| cross-repo git-инструкция третьей стороне | `git ls-remote --heads origin` (фактические ветки, не generic flow) | G-014, [[G-018]], 2026-… |
| «что делает команда / методология X» | актуальный текст `commands/<X>.md` (не по памяти) | L778-класс |
| описание legacy/механизма в design-spec/доке | real code `file:line` (не по памяти модели) | G-105 |
| sync/adoption «версия актуальна?» у консьюмера | `.claude/.version` consumer vs актуальный `VERSION` клона | sync-audit-version |

⛔ «Уверен на N%» про структуру/состояние **без чтения источника** = это hunch, не evidence → понизить до verify-first. Пользовательская инструкция «проверь не галлюцинируешь ли» — человек, компенсирующий именно этот класс; правило делает компенсацию структурной. Detection: `/retro` + `/architecture-audit` Шаг 6.3 мониторят recurrence_rate по `assumption-gap` — рост ≥0.4 = правило не держит, нужен L4. Закрывает класс G-039/G-085/G-100/G-105/G-106/G-109/G-116/G-117 (один корень, ≥8 раз cross-ref в AGENT-GAPS).

**Completeness rule:**
Каждое решение (в /plan, /code, /review, /deploy) ДОЛЖНО явно указать:
- Что закрывается (main path, happy cases)
- Что НЕ закрывается (gaps, edge cases, параллельные пути)
- Почему эти gaps OK или требуют дополнительных шагов
Без этого анализа → план не утверждён, код не merged, деплой не выполнен.

**Sustainment rule (closes G-099 class):** Каждый Full `/plan`, создающий или меняющий механизм/артефакт, **обязан** выполнить Шаг 97 Sustainment Declaration и вывести пользователю отдельную секцию **«## Жизнеобеспечение (Sustainment)»** с per-артефакт таблицей: Trigger · Refresh · Detection · Owner. «❌ НЕТ» в ячейке без шага/commitment в плане → Self-Lint не passed. `/review` gate: новый механизм в diff без `sustainment[]` в triggers.json → 🔴. После /code — добавить строку нового механизма в `docs/architecture/LIVING-ARTIFACTS.md` (PR-coupling, closes LAR-integration). Детали: [/plan Шаг 97](commands/plan.md).

**HIGH risks action rule:** Если `RISKS.md` существует — `/plan` pre-flight проверяет open HIGH severity риски без запланированного фикса. Любой HIGH риск старше 14 дней без связанного /plan → агент показывает его до начала анализа. Закрывает паттерн «долгого пути»: баг найден → записан в RISKS.md → лежит в backlog без action неделями. Если `RISKS.md` отсутствует → пропустить тихо.

**Frontend DOM verification rule:** Любая задача затрагивающая файлы `.vue` / `.tsx` / `.jsx` / `.svelte` / `.css` / `.html` — верификация реального DOM обязательна до commit. Три допустимых пути: (1) Playwright E2E тест запуск, (2) screenshot через Claude Code + Read tool с явным описанием что видно в DOM, (3) explicit skip с письменной причиной. «Написал код → должно работать» без одного из трёх = шаг не завершён.

**ROADMAP Done-trigger rule (closes G-101, P-008):** Каждый `/code`, завершающий methodology milestone, **обязан** добавить запись в `## Done` в том же PR (/code Шаг 5 ROADMAP PR-coupling).
- **Planner path** (задача была в `## Now`) → переместить запись из `## Now` в `## Done`.
- **Reactive path** (задача не была в `## Now` — gap → /plan → /code) → создать новую строку в `## Done` с кратким описанием.
Критерий «milestone»: задача имеет самостоятельный task_id И закрывает gap или добавляет capability методологии. Typo/bugfix без самостоятельного milestone → пропускать. Критерий «завершён»: основная часть реализована и задеплоена, edge cases могут быть отложены.

**Recommendation-first rule (closes G-102):** При любом clarifying question — **сначала дать собственную рекомендацию с обоснованием**, затем спрашивать если нужно. «Не знаю куда» без рекомендации = agent gap. Исключение: вопрос принципиально требует выбора владельца (security-решение, бизнес-приоритет). Применяется в `/plan` Шаг 0 и везде где агент задаёт вопрос пользователю.

**Research-capture rule (closes knowledge-evaporation class):** При обнаружении решение-влияющего вывода в процессе исследования (WebSearch + явный verdict) — **предложить запись `[research:X]` в DEVLOG** до конца сессии.
- **Incidental finding** (находка попутно во время любой задачи): Stop hook детектирует автоматически (WebSearch + verdict-keyword → напоминание).
- **Planned research** ([/research](commands/research.md)): запись в DEVLOG (Шаг 5 команды) обязательна.
- **Scope:** ANY research — маркетплейс, технология, конкурент, регуляторика, API, domain knowledge — если вывод влияет на будущее решение.
- ❌ Не пропускать запись под предлогом «это понятно из контекста» — следующая сессия не имеет этого контекста.

**Inline `[?]` convention:** лёгкий маркер для встраивания в любой текст запроса — означает «нужно твоё честное мнение здесь». Агент при обнаружении `[?]` — применяет Opinion Protocol ([/opinion](commands/opinion.md)): North Star extraction → committed verdict → «Что меня беспокоит». Примеры: `«Думаю добавить X [?]»` · `«[?] стоит ли разделять Y?»` · `«Как думаешь [?]?»`. ❌ Агент НЕ пропускает `[?]` и НЕ даёт generic ответ без VISION.md anchor.

**Self-apply rule (methodology-platform only):** `deploy-push.sh` автоматически запускает `sync-methodology.sh .` после каждого merge через guard `[ -d commands ] && [ -f scripts/sync-methodology.sh ]`. Guard-маркер: consumers не имеют `commands/` source-dir → guard false → consumer не затронут. Ручной self-apply нужен только если deploy-push.sh не использовался.

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

**L2 agent-responsibility rule (closes silent-hook class):** после любого `Edit`/`Write` файла содержащего ` ```mermaid ` блок — агент **обязан** запустить скрипт напрямую:
- single-repo: `bash scripts/update-mermaid-links.sh <file>`
- two-repo, файл в doc-repo: `bash scripts/update-mermaid-links.sh --root ../it-dev-methodology-documentation`

`post-edit-watchdog.py` остаётся страховкой — **не primary механизм**. Если скрипт не найден → сообщить явно, не игнорировать молча.

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
| **roadmap-view** | Temporal/Priorities | Что и в каком порядке строить? Status-карта: Now/Next/Considered/Hold | Developer, /vision review, /vision strategy | Developer после /vision review, /vision strategy, /plan (при добавлении/закрытии узлов) |
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

**URL над блоком: bare URL only** — никаких `[текст](url)` обёрток. Вставляется скриптом (L2 rule выше), не агентом вручную. Пример нарушения: `` [Открыть в Mermaid Live](https://mermaid.live/...) ``.

**`diagram-sources` annotation (closes G-114, v5.48.0):** каждый mermaid-блок в living-scope `.md` файлах ДОЛЖЕН иметь HTML-комментарий непосредственно перед mermaid.live URL:

```
<!-- diagram-sources: <type>:<Section>[, <type>:<Section>] -->
```

Типы (закрытый enum):
- `table:<Section>` — pipe-table строки в секции (первая ячейка после `|`)
- `list:<Section>` — top-level bullets `- **Name**` в секции
- `max-version:<Section>` — максимальная `vX.Y` из секции vs маркер `до vX.Y` в диаграмме
- `axes` — диаграмма показывает фиксированные оси/структуру (не данные); freshness не применима
- `none` — статическая диаграмма (концептуальная); freshness не применима

`validate-maps-coverage.sh --report` проверяет каждый mermaid-блок на наличие annotation и на соответствие диаграммы источнику данных. Диаграмма без annotation = WARN (ненулевой exit). Файл с annotation без совпадающей секции = WARN. Severity: `DIAGRAM_FRESHNESS_SEVERITY="warn"` (конфиг в шапке скрипта).

**USER-MAP MUST NOT содержать скрипт-узлы** — только команды (`/cmd`), skills, affordance-узлы (класс `affordance`). Скрипты = внутренняя реализация команд, не user-facing capability. Нарушение: `new-project-init.sh`, `sync-methodology.sh`, `set-secret.sh` как mermaid-узлы. Structural enforcement: `validate-maps-coverage.sh` `USER_MAP_NO_SCRIPTS="gate"` — флагует `.sh`/`.py` внутри mermaid-блоков (не таблиц). Closes G-116. Исключение: `Initial Setup` текстовая секция (bash-команды для bootstrap до `.claude/`) — легитимна. ADR-013.

**Гибридный язык:** технические термины/файлы/команды — EN; описания поведения/аннотации — RU.
❌ Транслитерация кириллицы латиницей (`"Stanet"`, `"Zapuskaet"`, `"dobavlen"`) — нарушение: это НЕ является RU. Только настоящая кириллица.
Пример: `Workflow["🔄 Workflow Cycle<br/>/plan → /code → /review → /deploy"]`

**Формат node-описания (closes G-121, v5.57.0):** каждая **компонентная** нода ДОЛЖНА содержать три строки — понятные нетехническому читателю:

```
NodeID["🔹 Простое имя компонента<br/>Зачем: одно предложение — зачем это нужно<br/>Без него: что сломается или перестанет работать"]
```

- **Строка 1 — Имя:** простое название без file-path и жаргона. Emoji опционально.
- **Строка 2 — Зачем:** ≤ 60 символов, объясняет назначение простым языком.
- **Строка 3 — Без него:** ≤ 60 символов, конкретный impact если компонента нет.

**Освобождены** от формата (навигационные по природе, не компоненты системы):
- affordance-ноды (класс `affordance`) — `📋 Отложенный scope → /scope-out`, Legend, Workflow-Cycle, repo/setup-контекст
- deferred-кластер (subgraph «🟪 Отложено»)

**Blob-нода** (несколько компонентов с одинаковыми связями, label через `·`) → один общий Зачем + один общий «Без них».

**Few-shot:**
✅ `CMDS["📋 Команды (/plan, /code...)<br/>Зачем: пошаговые инструкции для AI<br/>Без них: AI работает хаотично, нет проверок качества"]`
❌ `CMDS["commands/<br/>slash-команды (полный реестр в таблице)"]` — file-path + жаргон, не зачтено
❌ `CMDS["📋 Команды<br/>Зачем: нужно<br/>Без них: плохо"]` — формально (perfunctory), не зачтено

**Enforcement:** `validate-maps-coverage.sh` `NODE_READABILITY_SEVERITY="warn"` — WARN если нода без второй/третьей строки через `<br/>`. `/review` проверяет глазами что текст не perfunctory. Миграция существующих карт — отдельный PR.

**Применяется ко ВСЕМ создаваемым mermaid-диаграммам:** living maps, draft maps (/plan Шаг 99.54), design-spec §8 (/design-spec), ad-hoc «было→станет» — везде где пишется компонентная нода.

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

**Semantic fidelity (ADR-015, closes P-009 BS-2/BS-5):** presence узла в карте (валидатор) ≠ верность его **семантики** (стрелки отражают реальные связи, label «Зачем» актуален). Семантика поддерживается **detect+couple, не авто-генерацией** (генерация = OQ-008, отвергнута: ломает рукописную arc42-выразительность): (1) **PR-couple L3** — `/code` Шаг 4 п.9.5 + `/review`: diff трогает компонент → сверить узел/связи/label → обновить в том же PR; (2) **periodic safety-net** — `/architecture-audit` Способность D (semantic review всех living-карт, Capable). Не 100%-гарантия — для рукописной диаграммы выше L3 нельзя.

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

`[research:X]` — знание зафиксировано исследованием (WebSearch + явный вывод). `X` = kebab-case slug темы (`otto.de`, `stripe-fees-de`, `gdpr-email-collect`, `react-perf-2026`). Формат строки в DEVLOG: `[research:<slug>] → <что изучали>: <вывод>. <verdict: viable/not-viable/blocked/confirmed/conditional/unclear>. Source: <url>`. Covers **ANY** research: маркетплейс, технология, конкурент, регуляторика, API, domain knowledge — если вывод влияет на решение. Stop hook детектирует WebSearch + verdict-keyword → предлагает запись если не записано. Плановое исследование: [/research](commands/research.md) (interactive, ≤3 чекпоинта, DEVLOG-only).

`[opinion:X]` — мнение агента по конкретному вопросу с контекстом проекта (VISION-anchored). `X` = kebab-case slug вопроса. Формат строки в DEVLOG: `[opinion:<slug>] → <вопрос кратко>: <verdict ✅/⚠️/❌/🤷>. <главный тезис ≤60 символов>`. Команда: [/opinion](commands/opinion.md). Записывается **только** при decision-relevant мнении (не при каждом /opinion запросе). Inline-аналог: `[?]` маркер в тексте (см. «Inline `[?]` convention» ниже).

Phase-теги: `[phase-a]` … — milestone history.

Команды методологии: `[architecture-audit]` `[sync-vision]` `[retro]` `[diagnose]` `[product-vision]` `[product-review]` `[product-check]` `[research]` `[opinion]`

**Semantic tagging rule (D6):** Проблемы categorize семантически, не по surface name.

Одна проблема — один semantic indicator, даже если люди называют по-разному:
- `[git-failure]` — не `[git_push-failed]` ИЛИ `[github-error]` ИЛИ `[branch-push-issue]` (все sync failures)
- `[async-failure:operation]` — не `[vault-sync-error]` И `[queue-dropped]` (оба fire-and-forget failures)
- `[state-pollution]` — не `[history-leak]` И `[cache-contamination]` (оба внутренние состояния)

**Reason:** Regex-based detection fails когда люди называют одно разными именами. Semantic category stays stable.

**Domain-indicator для `[fix:X]` (D6-enforcement, closes S-1 / push-кластер урок):** surface-тег `[fix:X]` именует **компонент** (`[fix:consumer-push]`, `[fix:deploy-push]`) — этого мало для кластер-детекта. При каждом `[fix:X]` в DEVLOG **добавляй рядом domain-indicator** `[domain:<семантический-домен>]` — общий для всех фиксов одного корня, независимо от того какой компонент чинился:
- `[fix:consumer-push] [domain:git-push]` · `[fix:deploy-push] [domain:git-push]` · `[fix:command] [domain:git-push]` — три разных компонента, ОДИН домен.
- Домены гранулярны по корню, не по слою: `git-push` / `git-remote` / `secrets` / `sync` / `mermaid` / `hooks-delivery` — НЕ `methodology` (слишком широко → ложные группировки).

**Зачем:** `/plan` Шаг -1.3 п.3 (N-й фикс) и `/diagnose` grep'ают DEVLOG **по `[domain:X]`**, не только по точному `[fix:X]`. Кластер симптомов одного корня детектится на 3-м фиксе домена даже при разных surface-тегах → /diagnose предлагается рано, не на 9-м симптоме (урок push-кластера v5.19-5.24: первые 3 фикса имели разные теги → grep не сгруппировал → корень P-006 назван поздно). Старые `[fix:X]` без `[domain:X]` → grep fallback на точный тег (graceful).

**Few-shot:**
✅ `## 2026-06-09 — [fix:consumer-push][domain:git-push] классификация push-failure` → 3-й [domain:git-push] за период → /plan предложит /diagnose.
❌ `[fix:consumer-push]` без domain → grep по domain пуст → кластер невидим (старое поведение, fallback на точный тег).

---

## Security: real threats

**Утечка GitHub PAT и других токенов (was High → Mitigated):** Структурно закрыто секцией [Secrets & Credentials](#secrets--credentials) — 4 слоя защиты (gitignore, pre-commit hook, /review detector, tool deny). См. ниже.

**Прямой push в main (High → Mitigated v5.43.0):** Структурно закрыто тремя слоями: (1) `setup-branch-protection.sh` — required PR, enforce_admins, no force-push (GitHub layer); (2) `deploy-push.sh` GH006-классификация — при блоке направляет на PR-путь, а не ложный auth-flow; (3) `/sync-audit` Gap 13 — WARN если protection отключена. Emergency: `--off --yes` + re-apply. ADR-002 amendment 2026-06-11.

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
- [templates/DESIGN_SPEC.template.md](templates/DESIGN_SPEC.template.md) — шаблон Design Spec (VCD-протокол: Anti-Loss, Draft/Final, аргументация + пример per-requirement)
- [templates/LIVING-ARTIFACTS.template.md](templates/LIVING-ARTIFACTS.template.md) — шаблон Living Artifact Registry (lifecycle-реестр: что живёт и требует поддержания; синхронизируется консьюмерам)
- [../it-dev-methodology-documentation/docs/architecture/LIVING-ARTIFACTS.md](../it-dev-methodology-documentation/docs/architecture/LIVING-ARTIFACTS.md) — dogfood-инстанс LAR для methodology-platform (40+ строк; обновляется в /code Шаг 5 при новом механизме)
- [skills/design-spec/SKILL.md](skills/design-spec/SKILL.md) — Agent Skill `/design-spec`: интерактивное создание/обновление Design Spec
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
