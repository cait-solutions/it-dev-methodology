# CLAUDE.md

Operational rules for AI agents. Short form, scan-friendly. For rationale, edge cases, and historical context — see [CLAUDE_LONG.md](CLAUDE_LONG.md).

> **Convention:**
> - This file (CLAUDE.md) = **WHAT** — methodology rules. Auto-updated by `sync-methodology.sh`. **Do NOT edit.**
> - [CLAUDE_LONG.md](CLAUDE_LONG.md) = **WHY** — rationale, edge cases, examples. Read on demand.
> - [CLAUDE.local.md](CLAUDE.local.md) = project-specific config (stack, architecture invariants, security threats, key files, external links). **Edit freely.**

---

## Read before any work

1. `VISION.md` (or `docs/vision/*_GLOBAL_AGENT_VISION.md`) before every `/plan`.
2. Relevant ADRs / SYSTEM-MAP for the task domain.
3. `docs/data-map.md` (if exists) before storage-touching changes.
4. [CLAUDE.local.md](CLAUDE.local.md) — project stack, architecture invariants, security threats, key entry points.
5. [`.claude/rules/project-context.md`](.claude/rules/project-context.md) (if exists) — **shared project context**: Design Spec links, domain knowledge, onboarding pointers. Tracked in git — all developers receive it.

---

## Workflow rules

**Implementation through /code:** after `/plan` confirmation — implementation **mandatory** via `/code`. Direct edits forbidden for non-trivial changes. Reason: `/code` updates `triggers.json.last_plan_session.code_run` — without this, methodology state drifts.

**Deploy rule:** before every deploy → `/review` if not run in session → DEVLOG entry with `[deploy]` / `[feat:X]` / `[fix:X]` tag → update data map if changed.

**Architecture decision rule:** new modules / data flows / services / integrations → run `architect` sub-agent. Claude gives own recommendation BEFORE invoking architect (independent second opinion, not confirmation).

**Fix rule:**
- Symptom or cause? Symptom → find cause. Cause → class-level fix preferred.
- Local or systemic? Local needs justification why won't repeat. Default to systemic (decorator / middleware / schema constraint).

**Completeness rule:** Each plan / code / review / deploy decision MUST explicitly state:
- What is covered (main path, happy cases)
- What is NOT covered (gaps, edge cases, parallel paths)
- Why gaps are OK or require action
Without this analysis → plan not approved, code not merged, deploy blocked.

**Anti-cheat rule (no-gate-weakening):** ⛔ Never weaken an **artifact** or **criterion** to pass a quality gate. Satisfy the gate on merit — change the measured, not the measuring instrument. Applies to ANY gate (universal core): `/review`, `/doc-audit`, acceptance criteria, tests, map validators.
- **Dev domain (example):** don't disable a failing test · don't patch implementation just to make a check green · don't over-mock to bypass coverage.
- **Non-dev domains (example):** don't delete a required artifact section to pass `/doc-audit` · don't weaken acceptance criteria to pass `/review` · don't remove a map node to pass `validate-maps-coverage`.
- **Boundary (legitimate ≠ cheat):** changing a gate/criterion as an explicit decision with named justification (the gate was wrong) = legitimate. Changing it to pass without justification = cheat.

**Adjacent Impact rule:** Before planning, enumerate adjacent zones (what reads this component / what depends on it). Explicitly mark each as in-scope or out-of-scope with reason. Classify solution as Point fix / Structural / Level 4+. Without this classification → plan incomplete. See `/plan` Step -1.3 for protocol.

**Don't advise already-done:** check last 3-5 messages before suggesting an action that may already be running.

**AI branch rule:** All AI agent commits go to the branch defined in [CLAUDE.local.md](CLAUDE.local.md) → `## Branching` → `agent_branch` (default: `ai-dev`). Never commit to `main`, `master`, `develop`, `staging`, or `integration_branch` without explicit developer approval.
Before first commit in session: read `agent_branch` from `CLAUDE.local.md`, then `git branch --show-current`. Wrong branch → switch BEFORE any changes, not after.

**Methodology sync rule:** When slash commands or hooks seem outdated — run `sync-methodology.sh` (path: see `README.md` → "Обновление методологии"). Script auto-pulls latest from GitHub; CLAUDE.md is auto-overwritten after sync.

**Retroactivity rule:** Methodology updates apply to NEW plans only. Existing plans are revised only if: (a) not yet in `/code` stage, or (b) a critical blocking error found that new rules would catch. Don't revise completed plans for every update — it's an infinite loop.

**Risk scope rule:** Systemic risks (affect multiple tasks, live months/years) → `RISKS.md` only. Task-specific risks → stay in the plan. Don't copy task risks to `RISKS.md` — it pollutes the systemic registry with single-use noise.

**HIGH risks action rule:** If `RISKS.md` exists — `/plan` pre-flight checks for open HIGH severity risks without a scheduled fix. Any HIGH risk older than 14 days without a linked /plan entry → agent surfaces it as a prompt before starting analysis. This prevents the «long path» pattern: bug discovered → written to RISKS.md → stays in backlog for weeks without action. If `RISKS.md` absent → skip silently.

**Frontend DOM verification rule:** Any task touching `.vue` / `.tsx` / `.jsx` / `.svelte` / `.css` / `.html` files — DOM verification required before commit. Three accepted paths: (1) Playwright E2E test run, (2) screenshot via Claude Code + Read tool with explicit DOM description, (3) explicit skip with written reason (e.g. "TypeScript-only change, no render impact"). «Wrote the code → should work» without one of the three = task not complete. Principle: you cannot say "frontend done" without verifying real DOM — same as you cannot say "secret is set" without `check-secret.sh`.

**Onboard update rule:** When adding a new slash command, agent, or rules file → update `/onboard` in the same commit/PR. Onboarding that doesn't reflect the current toolset misleads contributors.

**Skill frontmatter spec compliance rule:** When creating or editing `skills/*/SKILL.md` (Agent Skills) — frontmatter MUST follow [official Anthropic spec](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview). Supported top-level keys: `name`, `description` (+ optional `metadata`). `description` MUST be **single-line string** ≤ 1024 chars (multi-line `description: |` blocks are parsed by linters as separate keys — broken state). `version`/`type` and any custom fields → inside `metadata:` block. `name` — lowercase + digits + hyphens only, ≤ 64 chars, no "anthropic"/"claude". Before commit: verify with IDE linter. In `/plan` Step 1.7 (contract) for new skills: explicitly fetch current Anthropic spec, don't pattern-match against existing files.

**Bootstrap detection rule:** If `.claude/.version` does not exist in the current project — methodology has never been initialized here. In the first response of the session, propose running:
`bash <methodology_path>/scripts/new-project-init.sh .`
where `<methodology_path>` defaults to `../it-dev-methodology` (configurable in [CLAUDE.local.md](CLAUDE.local.md) `## Auto-update`). The `auto-update-watchdog.py` SessionStart hook detects this state and prints a reminder into your context — surface it to the user, don't silently work without methodology bootstrap.

**PRODUCT.md component sync rule:** When planning work that touches code of any component / service / module — `/plan` Step -1.3 (Adjacent Impact) reads PRODUCT.md `## Логика компонентов → ### <component>` section. If missing → block plan until section is created together with user. If exists → cite it in `## Agent's understanding` block of Step 3 template (verbatim quotes, not paraphrase). If your understanding doesn't match PRODUCT.md → STOP until clarification with user. When changing component behavior (Покрывает / НЕ покрывает / Ключевые правила shift) → section MUST be in "Затронутые файлы" of Step 3 and updated in `/code` Step 5. `/review` runs L4 git diff sync check (см. **Sync validators framework rule** ниже): code files changed without corresponding PRODUCT.md section update → 🔵 Recommendation with user disposition (fix now / deferred / backlog). Two-level defense: L3 in `/plan` preventively + L4 in `/review` as final sync check before merge.

**Purpose registry rule:** Каждый нормативный элемент методологии имеет **explicit purpose** во избежание класса ошибок «agent assumes purpose by position in workflow» (G-049):
- **Slash-команды (`commands/*.md`):** inline `> **Цель:** <одна строка>` сразу после H1 заголовка
- **Hooks / scripts / state artifacts / templates:** строка в [CLAUDE_LONG.md § Purpose registry](CLAUDE_LONG.md) реестре

При создании нового элемента — обязательно добавить purpose в соответствующее место. При переименовании / удалении — обновить registry. Это L3 регулятор (rule + procedural) для closes G-049 класс «purpose-by-position assumption».

**Gap classification rule (AGENT vs PRODUCT):** Два namespace для gap'ов:
- **AGENT-GAPS.md** — agent's **reasoning** failures (я как агент пропустил правило / проигнорировал / неверно assumed). Категории: `prompt-gap`, `context-gap`, `logic-gap`, `assumption-gap`, `state-stale`. Сигнал для **методологии** (правило в commands/ закрывает класс).
- **PRODUCT-GAPS.md** — product's **coverage** gaps (продукт не имеет feature / capability / use case). Категории: `feature-gap`, `capability-gap`, `ux-gap`, `integration-gap`, `edge-case-gap`. Сигнал для **product roadmap** (/plan для фичи закрывает gap).

При записи в /plan Шаг -4: classify семантически. «Причина в том что **я не подумал**» → AGENT-GAPS. «Причина в том что **продукт не умеет**» → PRODUCT-GAPS. При сомнении → AGENT-GAPS (можно reclassify в /retro). `agent-gaps-watchdog.py` hook продолжает писать только в AGENT-GAPS (детектирует agent's confessions, не feature requests). Existing AGENT-GAPS records могут быть мигрированы через `scripts/migrate-agent-to-product-gaps.sh` (interactive, manual trigger).

**Methodology adoption audit rule:** `/sync-audit` checks which methodology features (накопленные при обновлениях) **not yet applied** to this project. 5 gap checks: PRODUCT.md ## Логика компонентов, CLAUDE.local.md ## Sync validators, ## Auto-update + hook, Mermaid hybrid language, Skills frontmatter spec. Output: severity report + obligatory user disposition (которые gaps взять в /plan). NOT auto-runs /plan — user chooses. Auto-trigger from `auto-update-watchdog.py` after successful sync if methodology version delta ≥ `audit_threshold` (default 3 minor versions). Fallback trigger from `/plan` Step -3. Cross-reference from `/architecture-audit` Step 0. Different from `/architecture-audit` (architecture drift) and `/retro` (tactical hygiene) — see /sync-audit purpose at top of command.

**Sync validators framework rule:** `/review` reads [CLAUDE.local.md](CLAUDE.local.md) `## Sync validators` section — config-driven L3 framework for checking that doc artifacts are updated alongside code changes. Default validators (in template): PRODUCT-whole, PRODUCT-components, USER-MAP, SYSTEM-MAP, ARTIFACT-MAP, ADR-status. Each validator has `trigger_paths` (code globs) + `required_artifact` (doc path). If trigger paths match `git diff main..HEAD` but required artifact is not in diff → 🔵 **Recommendation** with explicit disposition (fix now / deferred / backlog / irrelevant + reason). Opt-in: section absent → validators skipped (no regression for projects without config). Adding a new sync validator = one YAML block in CLAUDE.local.md, no methodology code changes needed. PRODUCT components check (v4.19.0) refactored into this framework — единый механизм для всех артефактов Категории А.

For rationale and historical examples — [CLAUDE_LONG.md § Workflow rules](CLAUDE_LONG.md#реализация-через-code-расширенно).

---

## Maps Standard Rule

Единый стандарт для трёх основных карт проекта. Основан на **arc42 multi-viewpoint** + Living Documentation + **C4-inspired дисциплина диаграмм** (нотация, не таксономия — три карты это ортогональные viewpoints, не C4 zoom levels).

**Три карты — три разные плоскости (arc42 viewpoints):**
- **SYSTEM-MAP** — как устроена система (компоненты, слои, связи)
- **USER-MAP** — что умеет пользователь (акторы, flows, capabilities)
- **ARTIFACT-MAP** — кто что обновляет и когда (lifecycle артефактов)

Dependency direction: SYSTEM-MAP ← USER-MAP ← ARTIFACT-MAP. Дублирование фактов между картами запрещено — cross-reference вместо копии.

**Обязательная структура каждой карты:**
```
# [ТИП] — {{Project Name}}
**Версия:** vX.Y  |  **Обновлён:** YYYY-MM-DD  |  **Граф проверен:** YYYY-MM-DD
## Agent TL;DR      ← 5-15 строк scan-friendly (подсистемы, источники правды, gaps)
## [Диаграмма]      ← Mermaid с URL выше
## [Таблицы]        ← полный реестр (каждый компонент — отдельная строка)
## Refresh Policy   ← когда обновлять + когда НЕ обновлять
```

**Правила диаграммы:**
- Mermaid-only. ASCII art, PlantUML — запрещены
- Гибридный язык: технические термины/команды/файлы — EN; описания поведения/аннотации — RU. ❌ Транслитерация кириллицы латиницей (`"Stanet"`, `"Zapuskaet"`) — нарушение: только настоящая кириллица.
- Детализация: отдельный нод = уникальные связи; группа-blob = одинаковые связи → один нод, label через `·`
- Диаграмма ~15-20 нодов (структурный обзор). Детали — в таблице
- Группировка по доменам: `subgraph SecretsSkills` + `subgraph MarketingSkills` раздельно, не `subgraph AllSkills`
- Типы стрелок (единообразно): `-->` W · `-.->` R · `===` RW · `--o` git · `--x` C
- Repo/setup контекст обязателен в USER-MAP если используется внешний methodology-repo

**Таблицы — taxonomy:**
- Триггеры: `🔁` каждый цикл · `📊` по счётчику · `🔭` стратегический · `⚡` по событию
- Акторы: Developer · PM/Owner · System · External · AI Agent

**Governance:**
- PR-coupling: обновить карту в том же PR что и изменение которое она отражает
- Рефакторинг без поведенческих изменений, performance-fix, typo — карту не обновлять
- Audit: SYSTEM-MAP `/architecture-audit` ≥5 планов · USER-MAP `/product-check` ≥5 · ARTIFACT-MAP `/retro` ≥15
- `/review` блокирует merge если: Mermaid удалён из SYSTEM/USER-MAP; новая команда/skill/артефакт добавлена без обновления карты

---

## Regulator levels (Level-4 framework)

Strong → weak:
1. Schema / type constraint — guarantee
2. No alternative path — very strong
3. Input data structure — strong
4. Few-shot examples — medium, drifts
5. Tool description — weak
6. Prompt rule — ignored

**Rule:** when adding behavior — start from level 4-6, not 1-3. Prompt-only rule as first solution = 🔵 Recommendation in `/review`. Before accepting any methodology rule — ask "is there a level-4+ structural fix?". If yes — that's primary, rule secondary.

Details: [CLAUDE_LONG.md § Level-4 framework](CLAUDE_LONG.md#сила-регуляторов-поведения-level-4-framework--расширенно).

---

## Model tier rule

Every methodology command MUST have `## Рекомендуемая модель` section (5 fields). Canonical registry: [.claude/model-tiers.md](.claude/model-tiers.md).

When adding new command → also add row to per-command matrix in `model-tiers.md`. Without both, `/review` blocks merge.

When Anthropic renames models → update only the Mapping table in `model-tiers.md`; commands stay stable.

Details: [CLAUDE_LONG.md § Model tier rule](CLAUDE_LONG.md#model-tier-rule-расширенно).

---

## Agent self-reporting rule (AGENT-GAPS.md)

Я **записываю автоматически** (без вопроса к пользователю) в трёх случаях. После записи — одна строка извещения + opt-out "нет" / "n" чтобы отменить.

**Триггер 0 — /plan с коррекцией в задании (первый приоритет):**
Если текст задания /plan семантически указывает на то что прошлая работа агента была неполной, неверной или что-то важное было пропущено — **оцениваю смысл, а не ключевые слова**. → /plan Шаг -4 выполняет дедуп-grep + auto-write + извещение **до** начала pre-flight. Детали: Шаг -4 в commands/plan.md.

**Триггер 1 — Разработчик указывает на ошибку в моей работе:**
Если разработчик указывает на упущение/неточность в том что я сделал ("ты пропустил", "почему ты не...", "это неточно/неправильно", "ты не проверил") И я вношу правку → записываю автоматически — независимо от того, произнёс ли я конкретные признательные слова.

**Триггер 2 — Я сам признаю ошибку:**
Ключевые фразы: "ты прав", "я пропустил", "я не предусмотрел", "я упустил", "я был неточен", "я ошибся", "не учёл", "you're right", "I missed", "I overlooked".

**Обязательное действие — авто-запись:**

1. **Дедуп-grep** (2-3 ключевых слова из сути ошибки):
   ```bash
   grep -i "<слова>" AGENT-GAPS.md
   ```
   Hit → "📝 Похожий gap G-NNN уже зафиксирован." Нет hit → записать.

2. **Запись** в AGENT-GAPS.md сверху в `## Записи`. Поле `Контекст:` = `/plan` / `/code` / `/free-chat`.

3. **Извещение + opt-out:**
   ```
   📝 Записано: G-NNN — [краткое что пропустил]. Отменить: напиши "нет" / "n".
   ```
   При "нет" / "n" → удалить только что добавленную запись.

**Правило НЕ срабатывает на:** уточнения, дополнения, переформулировки, вопросы, новые требования.
**Срабатывает на:** (0) задание /plan семантически указывает на коррекцию — оцениваю смысл, не слова; (1) разработчик корректирует мою работу и я вношу правку; (2) я явно признаю конкретное упущение.

**Пример — Триггер 0 (с явным указанием):**

> Разработчик: "/plan — добавь описания к командам. Ты добавил их к нодам, но не сделал аналогичного для PM-стрелок."
> Claude (первым делом, до pre-flight): [дедуп-grep] → записывает G-NNN.
> "📝 Записано: G-NNN — completeness-gap: не проверял все связанные ноды при частичном изменении ARTIFACT-MAP. Отменить: 'нет'."

**Пример — Триггер 0 (без триггерных слов, по смыслу):**

> Разработчик: "/plan — мне кажется, системное решение не было реализовано. Хочу пересмотреть подход."
> Claude (оценивает смысл: недовольство реализацией → коррекция): [дедуп-grep] → записывает G-NNN.
> "📝 Записано: G-NNN — scope-gap: выбран более простой вариант вместо системного решения. Отменить: 'нет'."

**Пример — Триггер 1 (ситуационный, без фразы):**

> Разработчик: "Ты не проверил все существующие Dev-стрелки — только добавил новые."
> Claude: [дедуп-grep] → записывает G-NNN.
> "📝 Записано: G-NNN — context-gap: не аудировал существующие human-actor стрелки при правке ARTIFACT-MAP. Отменить: 'нет'."

**Пример — Триггер 2 (классический):**

> Разработчик: "Ты не проверил что файл уже существует перед записью."
> Claude: [дедуп-grep] → записывает G-NNN.
> "📝 Записано: G-NNN — completeness-gap: не проверил side-effects записи. Отменить: 'нет'."

Если `AGENT-GAPS.md` не существует в проекте → пропустить тихо (не создавать файл автоматически).

---

## Secrets & Credentials

**Canonical store:** `.env` (per-project, gitignored) + optional `~/.config/it-dev/secrets.env` (shared). Declaration of required keys + per-service metadata: `.claude/secrets-manifest.yaml` (schema v2+ — service_name/service_url/login enable multi-host git credential routing).

**MUST:**
- Setup new secret (one-time, user runs): `bash scripts/set-secret.sh KEY` (interactive: prompts service_name, URL, login, expires_at, value via read -s)
- View metadata (no values): `bash scripts/secrets-show.sh` (table) or `bash scripts/secrets-show.sh KEY` (detail)
- Audit + hygiene warnings (expiry, rotation, missing fields): `/secrets` or `bash scripts/validate-secrets.sh`
- Update value (rotation): `bash scripts/secrets-update.sh KEY` (atomic backup + re-paste confirm)
- Edit metadata only (no value): `bash scripts/secrets-edit.sh KEY`
- Rollback (если ошибся): `bash scripts/secrets-rollback.sh` (latest backup) or `--list`
- Use secret in command (agent-safe): `bash scripts/with-secret.sh KEY -- <command>` (value never enters agent stdout/transcript)
- Boolean check: `bash scripts/check-secret.sh KEY` (exit 0/1, no value)
- Git HTTPS push/pull: configure `scripts/git-credential-from-env.sh` as credential helper

**MUST NOT:**
- ❌ Agent reading `.env` directly — blocked by `settings.json` Read+Bash deny rules for **common-path readers** (cat/grep/awk/sed/xxd/base64/python/node/perl/diff/iconv/tee/dd/etc., 73 patterns in v4.34.1+). Not universal — `bash -c '...'` wrapping or unenumerated commands can bypass. Rotation discipline = final safety net.
- ❌ Agent running `env` / `printenv` / `echo $SECRET` / `source .env` — blocked by `bash_protect.py` hook
- ❌ Writing secret values into chat / DEVLOG / commit messages
- ❌ **Calling `_get-secret-raw.sh`** — outputs value to stdout → transcript → API. Blocked by `bash_protect.py`. Only for user in terminal outside Claude Code.
- ❌ **Constructing `KEY="value" bash script.sh`** — value visible in tool input → transcript. Use `with-secret.sh KEY -- cmd` instead. Blocked by `bash_protect.py`.
- ❌ Committing `.env` (gitignored; `secrets-guard.py` blocks force-add at commit-time)
- ❌ `--no-verify` to bypass pre-commit hook without DEVLOG justification

**On compromise:** rotate at provider IMMEDIATELY → `set-secret.sh KEY <new>` → `bash scripts/secrets-scrub.sh` (cleanup transcripts) → check git history. See `skills/secrets-management/SKILL.md` for full runbook.

**Scope limit:** these defenses are agent-mediated (transcript / git / fs). They do NOT protect against OS-level compromise (process inspection, core dumps, memory scraping) — assume local OS is trusted boundary. **Windows NTFS specifically:** `chmod 600` on `.env` is **best-effort only** — Git Bash does not enforce POSIX permissions through NTFS by default. On shared Windows workstation: run `icacls .env /inheritance:r /grant:r "%USERNAME%:F"` (PowerShell) to restrict access to current user only. `set-secret.sh` warns when chmod mismatch is detected (v4.34.1+).

**External secret managers** (Vault / AWS / Azure): integrate via priority chain step 3 (process env). See skill for patterns.

---

## Hybrid dev

For projects combining AI agent workflow with manual human development:

- **Project root `CLAUDE.md`** — workflow rules (this file): `/plan`, `/code`, AI branch rule, architecture invariants
- **Service / directory `CLAUDE.md`** — technical stack rules (developer's own file: linting, naming conventions, test patterns, framework idioms)
- **`.claude/commands/`** — methodology slash commands

Claude Code loads both levels. Service-level takes priority over root on conflict. Workflow rules and technical rules are orthogonal — they don't conflict.

Escape hatch for solo-dev or single-branch setups: override the AI branch rule explicitly in this file with justification.

---

## Capture product signals (silent)

In any dialog — silently add to `IDEAS.md` when user says "would be nice if...", "didn't know...", "have to do X manually every time...", expresses surprise / confusion / repeats an action ≥3 times.

Don't mention IDEAS to user. Don't interrupt response. Add entry in parallel.

Symptom of violation: IDEAS.md empty after 10+ dialogues.

---

## DEVLOG tags (taxonomy)

Base: `[fix:X]` `[feat:X]` `[process:X]` `[infra:X]` `[security:X]` `[ops:X]` `[milestone]` `[regression:X]` `[missed-signal]` `[methodology]`

Methodology commands: `[architecture-audit]` `[sync-vision]` `[retro]` `[diagnose]` `[product-vision]` `[product-review]` `[product-check]`

**Semantic tagging rule:** Categorize problems semantically, not by surface name. One problem = one semantic indicator:
- `[git-failure]` — not `[git_push-failed]` OR `[github-error]` (same class)
- `[async-failure:X]` — not different names per operation type
- `[state-pollution]` — not `[history-leak]` AND `[cache-contamination]`
Reason: pattern detection in `/retro` breaks when the same problem is named differently.

Strategic axes from VISION.md: `[feat:<axis-tag>]`

Full DEVLOG entry format: [DEVLOG.md](DEVLOG.md).

---

